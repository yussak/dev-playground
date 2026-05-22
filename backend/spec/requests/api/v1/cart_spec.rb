require "rails_helper"

RSpec.describe "Api::V1::Cart", type: :request do
  let!(:user) { User.create!(name: "テストユーザー", email: "user@example.com", password: "password123") }
  let!(:product) { Product.create!(name: "商品A", price: 1000, user: user) }
  let!(:variant) { product.product_variants.create!(size: "M", color: "red", price: 1000) }
  let(:headers) { { "Authorization" => "Bearer #{JwtHelper.encode(user_id: user.id)}" } }

  def auth_header(u)
    { "Authorization" => "Bearer #{JwtHelper.encode(user_id: u.id)}" }
  end

  describe "POST /api/v1/cart/items" do
    context "認証済みの場合" do
      it "カートにバリアントを追加できる" do
        post "/api/v1/cart/items", params: { product_variant_id: variant.id }, headers: headers, as: :json

        expect(response).to have_http_status(:created)
        expect(user.cart.cart_items.count).to eq(1)
        expect(user.cart.cart_items.first.quantity).to eq(1)
      end

      it "同じバリアントを再度追加すると数量が+1される" do
        post "/api/v1/cart/items", params: { product_variant_id: variant.id }, headers: headers, as: :json
        post "/api/v1/cart/items", params: { product_variant_id: variant.id }, headers: headers, as: :json

        expect(user.cart.cart_items.count).to eq(1)
        expect(user.cart.cart_items.first.quantity).to eq(2)
      end

      it "削除済み商品のバリアントは追加できない" do
        product.deleted!
        post "/api/v1/cart/items", params: { product_variant_id: variant.id }, headers: headers, as: :json

        expect(response).to have_http_status(:not_found)
      end

      it "存在しないバリアントIDの場合404を返す" do
        post "/api/v1/cart/items", params: { product_variant_id: 99999 }, headers: headers, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "未認証の場合" do
      it "401を返す" do
        post "/api/v1/cart/items", params: { product_variant_id: variant.id }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/cart" do
    context "カートにアイテムがある場合" do
      before do
        cart = user.create_cart!
        cart.cart_items.create!(product_variant: variant, quantity: 2)
      end

      it "カート内容（バリアント情報含む）を返す" do
        get "/api/v1/cart", headers: headers, as: :json

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body["items"].length).to eq(1)
        expect(body["items"].first).to include(
          "product_name" => "商品A",
          "size" => "M",
          "color" => "red",
          "unit_price" => 1000,
          "quantity" => 2,
          "subtotal" => 2000
        )
        expect(body["total"]).to eq(2000)
      end
    end

    context "カートが空の場合" do
      it "空の配列を返す" do
        get "/api/v1/cart", headers: headers, as: :json

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body["items"]).to eq([])
      end
    end

    context "未認証の場合" do
      it "401を返す" do
        get "/api/v1/cart", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/cart/items/:id" do
    let!(:cart) { user.create_cart! }
    let!(:cart_item) { cart.cart_items.create!(product_variant: variant, quantity: 2) }

    context "認証済みの場合" do
      it "数量を変更できる" do
        patch "/api/v1/cart/items/#{cart_item.id}", params: { quantity: 5 }, headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(cart_item.reload.quantity).to eq(5)
      end

      it "数量0以下は422を返す" do
        patch "/api/v1/cart/items/#{cart_item.id}", params: { quantity: 0 }, headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "他ユーザーのカートアイテムは変更できない" do
        other = User.create!(name: "他ユーザー", email: "other@example.com", password: "password123")
        patch "/api/v1/cart/items/#{cart_item.id}", headers: auth_header(other), params: { quantity: 5 }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/cart/items/:id" do
    let!(:cart) { user.create_cart! }
    let!(:cart_item) { cart.cart_items.create!(product_variant: variant, quantity: 1) }

    context "認証済みの場合" do
      it "カートからアイテムを削除できる" do
        delete "/api/v1/cart/items/#{cart_item.id}", headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(cart.cart_items.count).to eq(0)
      end

      it "他ユーザーのカートアイテムは削除できない" do
        other = User.create!(name: "他ユーザー", email: "other@example.com", password: "password123")
        delete "/api/v1/cart/items/#{cart_item.id}", headers: auth_header(other), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "未認証の場合" do
      it "401を返す" do
        delete "/api/v1/cart/items/#{cart_item.id}", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
