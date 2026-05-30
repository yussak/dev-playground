require "rails_helper"

RSpec.describe "Api::V1::Cart", type: :request do
  let!(:user) { User.create!(name: "テストユーザー", email: "user@example.com", password: "password123") }
  let!(:product) { Product.create!(name: "商品A", user: user) }
  let!(:variant) { product.product_variants.create!(size: "M", color: "red", price: 1000).tap { |v| v.stock.update!(quantity: 100) } }
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

      it "在庫が0の場合は422を返す" do
        variant.stock.update!(quantity: 0)
        post "/api/v1/cart/items", params: { product_variant_id: variant.id }, headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(user.cart&.cart_items&.count.to_i).to eq(0)
      end

      it "既存のカート数量+1が在庫を超える場合は422を返す" do
        variant.stock.update!(quantity: 2)
        cart = user.create_cart!
        cart.cart_items.create!(product_variant: variant, quantity: 2)

        post "/api/v1/cart/items", params: { product_variant_id: variant.id }, headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(cart.cart_items.first.quantity).to eq(2)
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

      it "各 cart_item に該当商品オプションの在庫数 stock が含まれる" do
        variant.stock.update!(quantity: 5)

        get "/api/v1/cart", headers: headers, as: :json

        body = JSON.parse(response.body)
        expect(body["items"].first["stock"]).to eq(5)
      end

      it "在庫がある場合 status が active になる" do
        variant.stock.update!(quantity: 5)

        get "/api/v1/cart", headers: headers, as: :json

        body = JSON.parse(response.body)
        expect(body["items"].first["status"]).to eq("active")
      end

      it "在庫が 0 になると status が unavailable になる" do
        variant.stock.update!(quantity: 0)

        get "/api/v1/cart", headers: headers, as: :json

        body = JSON.parse(response.body)
        expect(body["items"].first["status"]).to eq("unavailable")
      end

      it "unavailable だったアイテムは在庫が戻ると active に戻る" do
        variant.stock.update!(quantity: 0)
        get "/api/v1/cart", headers: headers, as: :json
        expect(JSON.parse(response.body)["items"].first["status"]).to eq("unavailable")

        variant.stock.update!(quantity: 5)
        get "/api/v1/cart", headers: headers, as: :json
        expect(JSON.parse(response.body)["items"].first["status"]).to eq("active")
      end

      it "unavailable なアイテムは合計に含まれない" do
        variant.stock.update!(quantity: 0)

        get "/api/v1/cart", headers: headers, as: :json

        body = JSON.parse(response.body)
        expect(body["total"]).to eq(0)
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

      it "在庫を超える数量は422を返す" do
        variant.stock.update!(quantity: 3)
        patch "/api/v1/cart/items/#{cart_item.id}", params: { quantity: 4 }, headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(cart_item.reload.quantity).to eq(2)
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
