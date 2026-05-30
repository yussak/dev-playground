module Api
  module V1
    class StocksController < ApplicationController
      before_action :authenticate_user!

      def update
        variant = find_authorized_variant
        return unless variant

        stock = variant.stock || variant.create_stock!(quantity: 0)
        stock.update!(quantity: params[:quantity].to_i)
        render json: { product_variant_id: variant.id, quantity: stock.quantity }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "商品オプションが見つかりません" }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def adjust
        variant = find_authorized_variant
        return unless variant

        stock = variant.stock || variant.create_stock!(quantity: 0)
        new_quantity = [ stock.quantity + params[:adjustment].to_i, 0 ].max
        stock.update!(quantity: new_quantity)
        render json: { product_variant_id: variant.id, quantity: stock.quantity }
      rescue ActiveRecord::RecordNotFound
        render json: { error: "商品オプションが見つかりません" }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      private

      def find_authorized_variant
        variant = ProductVariant.includes(:product, :stock).find(params[:product_variant_id])
        if variant.product.user_id != @current_user.id
          render json: { error: "権限がありません" }, status: :forbidden
          return nil
        end
        variant
      end
    end
  end
end
