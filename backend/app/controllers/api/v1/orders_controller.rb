module Api
  module V1
    class OrdersController < ApplicationController
      before_action :authenticate_user!

      def index
        orders = @current_user.orders.order(created_at: :desc)
        render json: orders.map { |order| order_summary_json(order) }
      end

      def show
        order = @current_user.orders.find(params[:id])
        render json: order_detail_json(order)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "注文が見つかりません" }, status: :not_found
      end

      def create
        cart = @current_user.cart
        if cart.nil? || cart.cart_items.empty?
          return render json: { error: "カートが空です" }, status: :unprocessable_entity
        end

        orderable_items = cart.cart_items.includes(product_variant: [ :product, :stock ])
                             .select { |item| item.active? && item.product.active? }

        if orderable_items.empty?
          return render json: { error: "注文可能な商品がありません" }, status: :unprocessable_entity
        end

        coupon = nil
        if params[:coupon_code].present?
          coupon = Promotion::Coupon.find_by(code: params[:coupon_code])
          if coupon.nil? || !coupon.valid_for_use_by?(@current_user)
            return render json: { error: "クーポンが無効です" }, status: :unprocessable_entity
          end
          unless orderable_items.any? { |item| item.product_id == coupon.product_id }
            return render json: { error: "対象商品がカートにありません" }, status: :unprocessable_entity
          end
        end

        order = nil
        newly_unavailable = []

        ActiveRecord::Base.transaction do
          purchasable_items, insufficient_items = orderable_items.partition do |item|
            stock = item.product_variant.stock
            stock.present? && stock.quantity >= item.quantity
          end

          insufficient_items.each do |item|
            item.unavailable!
            newly_unavailable << item
          end

          if purchasable_items.empty?
            raise ActiveRecord::Rollback
          end

          discount_amount = coupon ? coupon.discount_amount_for(purchasable_items) : 0

          order = @current_user.orders.create!(
            order_number: SecureRandom.uuid,
            status: :confirmed,
            discount_amount: discount_amount
          )

          purchasable_items.each do |cart_item|
            variant = cart_item.product_variant
            order.order_items.create!(
              product_variant: variant,
              product_name: variant.product.name,
              size: variant.size,
              color: variant.color,
              unit_price: variant.price,
              quantity: cart_item.quantity
            )
            variant.stock.decrement!(:quantity, cart_item.quantity)
          end

          if coupon
            Promotion::CouponUse.create!(coupon: coupon, user: @current_user, order: order, status: :used)
          end

          cart.cart_items.where(id: purchasable_items.map(&:id)).destroy_all
        end

        if order.nil?
          return render json: {
            error: "在庫が不足しているため注文できませんでした",
            unavailable_items: newly_unavailable.map { |i| { product_name: i.product_variant.product.name, size: i.product_variant.size, color: i.product_variant.color } }
          }, status: :unprocessable_entity
        end

        has_unavailable = newly_unavailable.any? || cart.cart_items.reload.any?(&:unavailable?)
        render json: order_detail_json(order).merge(partially_unavailable: has_unavailable), status: :created
      end

      def cancel
        order = @current_user.orders.find(params[:id])

        if order.cancelled?
          return render json: { error: "すでにキャンセル済みです" }, status: :unprocessable_entity
        end

        ActiveRecord::Base.transaction do
          order.coupon_use&.destroy!
          order.order_items.includes(product_variant: :stock).each do |item|
            stock = item.product_variant&.stock
            stock&.increment!(:quantity, item.quantity)
          end
          order.cancelled!
        end

        render json: order_detail_json(order)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "注文が見つかりません" }, status: :not_found
      end

      private

      def order_summary_json(order)
        subtotal = order.order_items.sum { |item| item.unit_price * item.quantity }
        {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          subtotal: subtotal,
          discount_amount: order.discount_amount,
          total: subtotal - order.discount_amount,
          created_at: order.created_at
        }
      end

      def order_detail_json(order)
        items = order.order_items.includes(product_variant: :product).map do |item|
          {
            id: item.id,
            product_variant_id: item.product_variant_id,
            product_id: item.product_variant&.product_id,
            product_name: item.product_name,
            size: item.size,
            color: item.color,
            unit_price: item.unit_price,
            quantity: item.quantity,
            subtotal: item.unit_price * item.quantity
          }
        end

        subtotal = items.sum { |i| i[:subtotal] }
        {
          id: order.id,
          order_number: order.order_number,
          status: order.status,
          items: items,
          subtotal: subtotal,
          discount_amount: order.discount_amount,
          total: subtotal - order.discount_amount,
          created_at: order.created_at
        }
      end
    end
  end
end
