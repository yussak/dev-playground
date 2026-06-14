require "rails_helper"

RSpec.describe "Api::V1::Stocks", type: :request do
  let!(:owner) { Identity::User.create!(name: "出品者", email: "owner@example.com", password: "password123") }
  let!(:other) { Identity::User.create!(name: "他人", email: "other@example.com", password: "password123") }
  let!(:product) { Product.create!(name: "商品A", user: owner) }
  let!(:variant) { product.product_variants.create!(price: 1000) }

  def auth_header(u)
    { "Authorization" => "Bearer #{Identity::Api.encode_token(user_id: u.id)}" }
  end

  describe "PATCH /api/v1/product_variants/:product_variant_id/stock" do
    context "出品者本人の場合" do
      it "在庫数を更新できる" do
        patch "/api/v1/product_variants/#{variant.id}/stock",
          params: { quantity: 30 }, headers: auth_header(owner), as: :json

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["quantity"]).to eq(30)
        expect(variant.stock.reload.quantity).to eq(30)
      end

      it "上限を超える値は422を返す" do
        patch "/api/v1/product_variants/#{variant.id}/stock",
          params: { quantity: 1_000_000 }, headers: auth_header(owner), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "負の値は422を返す" do
        patch "/api/v1/product_variants/#{variant.id}/stock",
          params: { quantity: -1 }, headers: auth_header(owner), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "出品者本人でない場合" do
      it "403を返す" do
        patch "/api/v1/product_variants/#{variant.id}/stock",
          params: { quantity: 30 }, headers: auth_header(other), as: :json

        expect(response).to have_http_status(:forbidden)
        expect(variant.stock.reload.quantity).to eq(0)
      end
    end

    context "未認証の場合" do
      it "401を返す" do
        patch "/api/v1/product_variants/#{variant.id}/stock",
          params: { quantity: 30 }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "存在しない商品オプションの場合" do
      it "404を返す" do
        patch "/api/v1/product_variants/0/stock",
          params: { quantity: 30 }, headers: auth_header(owner), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/v1/product_variants/:product_variant_id/stock/adjust" do
    context "出品者本人の場合" do
      it "adjustment が正の値のとき在庫が増える" do
        variant.stock.update!(quantity: 10)
        patch "/api/v1/product_variants/#{variant.id}/stock/adjust",
          params: { adjustment: 5 }, headers: auth_header(owner), as: :json

        expect(response).to have_http_status(:ok)
        expect(variant.stock.reload.quantity).to eq(15)
      end

      it "adjustment が負の値のとき在庫が減る" do
        variant.stock.update!(quantity: 10)
        patch "/api/v1/product_variants/#{variant.id}/stock/adjust",
          params: { adjustment: -3 }, headers: auth_header(owner), as: :json

        expect(response).to have_http_status(:ok)
        expect(variant.stock.reload.quantity).to eq(7)
      end

      it "adjustment がマイナスになっても 0 でクランプされる" do
        variant.stock.update!(quantity: 2)
        patch "/api/v1/product_variants/#{variant.id}/stock/adjust",
          params: { adjustment: -10 }, headers: auth_header(owner), as: :json

        expect(response).to have_http_status(:ok)
        expect(variant.stock.reload.quantity).to eq(0)
      end
    end

    context "出品者本人でない場合" do
      it "403を返す" do
        patch "/api/v1/product_variants/#{variant.id}/stock/adjust",
          params: { adjustment: 5 }, headers: auth_header(other), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
