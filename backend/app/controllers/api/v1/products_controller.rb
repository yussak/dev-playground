module Api
  module V1
    class ProductsController < ApplicationController
      before_action :authenticate_user!, only: [ :create, :update ]

      def index
        products = Product.includes(product_variants: :stock).all
        render json: products.map { |product| product_summary_json(product) }
      end

      def show
        product = Product.includes(product_variants: :stock).find(params[:id])
        render json: product_detail_json(product)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "商品が見つかりません" }, status: :not_found
      end

      def destroy
        authenticate_user!
        return if performed?

        product = Product.find(params[:id])
        if product.user_id != @current_user.id
          return render json: { error: "権限がありません" }, status: :forbidden
        end

        product.destroy
        render json: {}, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { error: "商品が見つかりません" }, status: :not_found
      end

      def update
        product = Product.find(params[:id])
        if product.user_id != @current_user.id
          return render json: { error: "権限がありません" }, status: :forbidden
        end

        variants = variants_param
        ActiveRecord::Base.transaction do
          replace_variants(product, variants) if variants
          product.assign_attributes(product_attributes)
          product.save!
        end

        render json: product_detail_json(product.reload)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "商品が見つかりません" }, status: :not_found
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      end

      def create
        variants = variants_param || []
        if variants.empty?
          return render json: { errors: [ "バリアントは1つ以上必要です" ] }, status: :unprocessable_entity
        end

        product = @current_user.products.new(product_attributes)
        variants.each do |attrs|
          product.product_variants.build(attrs.slice(:size, :color, :price))
        end

        if product.save
          render json: product_detail_json(product), status: :created
        else
          render json: { errors: product.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def product_attributes
        params.permit(:name, :description).to_h.symbolize_keys.compact
      end

      def variants_param
        return nil if params[:variants].nil?
        Array(params[:variants]).map do |v|
          permitted = v.respond_to?(:permit) ? v.permit(:id, :size, :color, :price) : v
          permitted.to_h.symbolize_keys
        end
      end

      def replace_variants(product, variants)
        kept_ids = variants.filter_map { |v| v[:id]&.to_i }
        product.product_variants.where.not(id: kept_ids).destroy_all

        variants.each do |attrs|
          if attrs[:id]
            variant = product.product_variants.find(attrs[:id])
            variant.update!(attrs.slice(:size, :color, :price))
          else
            product.product_variants.create!(attrs.slice(:size, :color, :price))
          end
        end
      end

      def product_summary_json(product)
        prices = product.product_variants.map(&:price)
        {
          id: product.id,
          name: product.name,
          description: product.description,
          min_price: prices.min,
          max_price: prices.max,
          user_id: product.user_id,
          total_stock: product.total_stock
        }
      end

      def product_detail_json(product)
        {
          id: product.id,
          name: product.name,
          description: product.description,
          user_id: product.user_id,
          variants: product.product_variants.order(:id).map do |v|
            { id: v.id, size: v.size, color: v.color, price: v.price, stock: v.stock&.quantity || Stock::DEFAULT_QUANTITY }
          end
        }
      end
    end
  end
end
