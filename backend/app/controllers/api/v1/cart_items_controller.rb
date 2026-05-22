module Api
  module V1
    class CartItemsController < ApplicationController
      before_action :authenticate_user!

      def create
        cart = @current_user.cart || @current_user.create_cart!
        variant = ProductVariant.joins(:product)
                                .where(products: { status: "active" })
                                .find(params[:product_variant_id])

        cart_item = cart.cart_items.find_by(product_variant: variant)
        if cart_item
          cart_item.increment!(:quantity)
        else
          cart_item = cart.cart_items.create!(product_variant: variant, quantity: 1)
        end

        render json: cart_item, status: :created
      rescue ActiveRecord::RecordNotFound
        render json: { error: "商品が見つかりません" }, status: :not_found
      end

      def update
        cart_item = find_cart_item
        cart_item.update!(quantity: params[:quantity].to_i)
        render json: cart_item
      rescue ActiveRecord::RecordNotFound
        render json: { error: "カートアイテムが見つかりません" }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def destroy
        cart_item = find_cart_item
        cart_item.destroy!
        render json: {}, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "カートアイテムが見つかりません" }, status: :not_found
      end

      private

      def find_cart_item
        @current_user.cart&.cart_items&.find(params[:id]) || raise(ActiveRecord::RecordNotFound)
      end
    end
  end
end
