module Api
  module V1
    class CartsController < ApplicationController
      before_action :authenticate_user!

      def show
        cart = @current_user.cart
        if cart
          render json: cart_json(cart)
        else
          render json: { items: [] }
        end
      end

      private

      def cart_json(cart)
        items = cart.cart_items.includes(product_variant: :product).map do |item|
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
            product_deleted: product.deleted?
          }
        end

        {
          items: items,
          total: items.reject { |i| i[:product_deleted] }.sum { |i| i[:subtotal] }
        }
      end
    end
  end
end
