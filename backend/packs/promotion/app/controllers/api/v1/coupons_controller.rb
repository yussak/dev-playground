module Api
  module V1
    class CouponsController < ApplicationController
      before_action :authenticate_user!

      def index
        product = Catalog::Product.find(params[:product_id])
        if product.user_id != @current_user.id
          return render json: { error: "権限がありません" }, status: :forbidden
        end

        render json: Array(product.coupon).compact
      rescue ActiveRecord::RecordNotFound
        render json: { error: "商品が見つかりません" }, status: :not_found
      end

      def create
        product = Catalog::Product.find(params[:product_id])
        if product.user_id != @current_user.id
          return render json: { error: "権限がありません" }, status: :forbidden
        end

        if product.coupon.present?
          return render json: { errors: [ "この商品には既にクーポンが存在します" ] }, status: :unprocessable_entity
        end

        coupon = product.build_coupon(coupon_params)
        coupon.code = SecureRandom.alphanumeric(16)

        if coupon.save
          render json: coupon, status: :created
        else
          render json: { errors: coupon.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "商品が見つかりません" }, status: :not_found
      end

      def update
        coupon = Promotion::Coupon.find(params[:id])
        if coupon.product.user_id != @current_user.id
          return render json: { error: "権限がありません" }, status: :forbidden
        end

        if coupon.update(coupon_params)
          render json: coupon
        else
          render json: { errors: coupon.errors.full_messages }, status: :unprocessable_entity
        end
      rescue ActiveRecord::RecordNotFound
        render json: { error: "クーポンが見つかりません" }, status: :not_found
      end

      def destroy
        coupon = Promotion::Coupon.find(params[:id])
        if coupon.product.user_id != @current_user.id
          return render json: { error: "権限がありません" }, status: :forbidden
        end

        coupon.destroy
        render json: {}, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "クーポンが見つかりません" }, status: :not_found
      end

      private

      def coupon_params
        params.permit(:discount_type, :discount_value, :expires_at)
      end
    end
  end
end
