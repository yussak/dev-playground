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

        active_items = cart.cart_items.includes(product_variant: :product).select { |item| item.product.active? }
        if active_items.empty?
          return render json: { error: "注文可能な商品がありません" }, status: :unprocessable_entity
        end

        coupon = nil
        if params[:coupon_code].present?
          coupon = Coupon.find_by(code: params[:coupon_code])
          if coupon.nil? || !coupon.valid_for_use_by?(@current_user)
            return render json: { error: "クーポンが無効です" }, status: :unprocessable_entity
          end
          unless active_items.any? { |item| item.product_id == coupon.product_id }
            return render json: { error: "対象商品がカートにありません" }, status: :unprocessable_entity
          end
        end

        order = nil
        ActiveRecord::Base.transaction do
          discount_amount = coupon ? coupon.discount_amount_for(active_items) : 0

          order = @current_user.orders.create!(
            order_number: SecureRandom.uuid,
            status: :confirmed,
            discount_amount: discount_amount
          )

          active_items.each do |cart_item|
            order.order_items.create!(
              product: cart_item.product,
              product_name: cart_item.product.name,
              unit_price: cart_item.product.price,
              quantity: cart_item.quantity
            )
          end

          if coupon
            CouponUse.create!(coupon: coupon, user: @current_user, order: order, status: :used)
          end

          cart.cart_items.destroy_all
        end

        render json: order_detail_json(order), status: :created
      end

      def cancel
        order = @current_user.orders.find(params[:id])

        if order.cancelled?
          return render json: { error: "すでにキャンセル済みです" }, status: :unprocessable_entity
        end

        ActiveRecord::Base.transaction do
          order.coupon_use&.destroy!
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
        items = order.order_items.includes(:product).map do |item|
          {
            id: item.id,
            product_id: item.product_id,
            product_name: item.product_name,
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
