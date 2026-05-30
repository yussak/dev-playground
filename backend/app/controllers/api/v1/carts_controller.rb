module Api
  module V1
    class CartsController < ApplicationController
      before_action :authenticate_user!

      def show
        cart = @current_user.cart
        if cart
          sync_stock_status(cart)
          render json: cart_json(cart)
        else
          render json: { items: [] }
        end
      end

      private

      def sync_stock_status(cart)
        cart.cart_items.includes(product_variant: :stock).each do |item|
          stock_quantity = item.product_variant.stock&.quantity || Stock::DEFAULT_QUANTITY
          if stock_quantity <= 0
            item.unavailable! unless item.unavailable?
          else
            item.active! if item.unavailable?
          end
        end
      end

      def cart_json(cart)
        items = cart.cart_items.includes(product_variant: [ :product, :stock ]).map do |item|
          variant = item.product_variant
          product = variant.product
          {
            id: item.id,
            product_id: product.id,
            product_variant_id: variant.id,
            product_name: product.name,
            size: variant.size,
            color: variant.color,
            unit_price: variant.price,
            quantity: item.quantity,
            subtotal: variant.price * item.quantity,
            product_deleted: product.deleted?,
            stock: variant.stock&.quantity || Stock::DEFAULT_QUANTITY,
            status: item.status
          }
        end

        {
          items: items,
          total: items.reject { |i| i[:product_deleted] || i[:status] == "unavailable" }.sum { |i| i[:subtotal] }
        }
      end
    end
  end
end
