module Api
  module V1
    class StocksController < ApplicationController
      before_action :authenticate_user!

      def update
        variant = ProductVariant.includes(:product, :stock).find(params[:product_variant_id])

        if variant.product.user_id != @current_user.id
          return render json: { error: "権限がありません" }, status: :forbidden
        end

        stock = variant.stock || variant.create_stock!(quantity: 0)
        stock.update!(quantity: params[:quantity].to_i)

        render json: { product_variant_id: variant.id, quantity: stock.quantity }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "商品オプションが見つかりません" }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
