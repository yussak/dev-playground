require "rails_helper"

RSpec.describe "Api::V1::Products", type: :request do
  let!(:user) { User.create!(name: "販売者", email: "seller@example.com", password: "password123") }

  def auth_header(user)
    token = JwtHelper.encode(user_id: user.id)
    { "Authorization" => "Bearer #{token}" }
  end

  describe "GET /api/v1/products" do
    it "各商品に total_stock が含まれる" do
      product = Product.create!(name: "商品A", user: user)
      v1 = product.product_variants.create!(price: 1000)
      v2 = product.product_variants.create!(size: "L", color: "red", price: 1500)
      v1.stock.update!(quantity: 3)
      v2.stock.update!(quantity: 7)

      get "/api/v1/products", as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      entry = body.find { |p| p["id"] == product.id }
      expect(entry["total_stock"]).to eq(10)
    end
  end

  describe "GET /api/v1/products/:id" do
    let!(:product) do
      product = Product.create!(name: "商品A", description: "説明A", user: user)
      product.product_variants.create!(size: "M", color: "red", price: 1000)
      product.product_variants.create!(size: "L", color: "red", price: 1500)
      product
    end

    context "商品が存在する場合" do
      it "200 と商品情報・バリアント一覧を返す" do
        get "/api/v1/products/#{product.id}", as: :json

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body).to include("id" => product.id, "name" => "商品A", "description" => "説明A")
        expect(body["variants"].length).to eq(2)
        expect(body["variants"].first).to include("size" => "M", "color" => "red", "price" => 1000)
      end
    end

    context "存在しない ID の場合" do
      it "404 を返す" do
        get "/api/v1/products/99999", as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /api/v1/products/:id" do
    let!(:owner) { User.create!(name: "出品者", email: "owner@example.com", password: "password123") }
    let!(:other) { User.create!(name: "他ユーザー", email: "other@example.com", password: "password123") }
    let!(:product) { Product.create!(name: "削除対象商品", description: "説明", user: owner) }

    context "出品者本人の場合" do
      it "200 を返し商品が削除される" do
        delete "/api/v1/products/#{product.id}", headers: auth_header(owner), as: :json

        expect(response).to have_http_status(:ok)
        expect(Product.find_by(id: product.id)).to be_nil
      end
    end

    context "他のユーザーの場合" do
      it "403 を返す" do
        delete "/api/v1/products/#{product.id}", headers: auth_header(other), as: :json

        expect(response).to have_http_status(:forbidden)
        expect(Product.find_by(id: product.id)).not_to be_nil
      end
    end

    context "未認証の場合" do
      it "401 を返す" do
        delete "/api/v1/products/#{product.id}", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "存在しない ID の場合" do
      it "404 を返す" do
        delete "/api/v1/products/99999", headers: auth_header(owner), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /api/v1/products" do
    let(:headers) { auth_header(user) }

    context "認証済みの場合" do
      context "正常なパラメータの場合" do
        it "201 とバリアント付きの商品を返す" do
          post "/api/v1/products",
               params: {
                 name: "新商品",
                 variants: [
                   { size: "M", color: "red", price: 1000 },
                   { size: "L", color: "red", price: 1500 }
                 ]
               },
               headers: headers,
               as: :json

          expect(response).to have_http_status(:created)

          body = JSON.parse(response.body)
          expect(body).to include("name" => "新商品", "user_id" => user.id)
          expect(body["variants"].length).to eq(2)
          expect(body["variants"].map { |v| v["price"] }).to contain_exactly(1000, 1500)
        end

        it "バリアントが1つ（軸なし）でも作成できる" do
          post "/api/v1/products",
               params: { name: "単一商品", variants: [ { price: 500 } ] },
               headers: headers,
               as: :json

          expect(response).to have_http_status(:created)
          body = JSON.parse(response.body)
          expect(body["variants"].length).to eq(1)
          expect(body["variants"].first).to include("size" => nil, "color" => nil, "price" => 500)
        end

        it "description なしでも作成できる" do
          post "/api/v1/products",
               params: { name: "説明なし商品", variants: [ { price: 500 } ] },
               headers: headers,
               as: :json

          expect(response).to have_http_status(:created)
          expect(JSON.parse(response.body)["description"]).to be_nil
        end
      end

      context "variants が空の場合" do
        it "422 を返す" do
          post "/api/v1/products",
               params: { name: "新商品", variants: [] },
               headers: headers,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to have_key("errors")
        end
      end

      context "variants パラメータが無い場合" do
        it "422 を返す" do
          post "/api/v1/products",
               params: { name: "新商品" },
               headers: headers,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "name が空の場合" do
        it "422 を返す" do
          post "/api/v1/products",
               params: { name: "", variants: [ { price: 1000 } ] },
               headers: headers,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to have_key("errors")
        end
      end

      context "variants の price が負の値の場合" do
        it "422 を返す" do
          post "/api/v1/products",
               params: { name: "商品", variants: [ { price: -1 } ] },
               headers: headers,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to have_key("errors")
        end
      end

      context "バリアントのパターンが混在している場合" do
        it "422 を返す" do
          post "/api/v1/products",
               params: {
                 name: "混在商品",
                 variants: [
                   { size: "M", price: 1000 },
                   { color: "red", price: 1000 }
                 ]
               },
               headers: headers,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)).to have_key("errors")
        end
      end
    end

    context "未認証の場合" do
      it "401 を返す" do
        post "/api/v1/products",
             params: { name: "新商品", variants: [ { price: 1000 } ] },
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/products/:id" do
    let!(:product) do
      p = Product.create!(name: "商品A", description: "説明A", user: user)
      p.product_variants.create!(size: "M", color: "red", price: 1000)
      p.product_variants.create!(size: "L", color: "red", price: 1500)
      p
    end
    let(:headers) { auth_header(user) }

    it "バリアントを置き換える（含まれないものは削除）" do
      remaining_variant = product.product_variants.find_by(size: "M")

      patch "/api/v1/products/#{product.id}",
            params: {
              variants: [
                { id: remaining_variant.id, size: "M", color: "red", price: 1200 },
                { size: "XL", color: "red", price: 2000 }
              ]
            },
            headers: headers,
            as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["variants"].length).to eq(2)
      expect(body["variants"].map { |v| v["size"] }).to contain_exactly("M", "XL")
      expect(product.reload.product_variants.find(remaining_variant.id).price).to eq(1200)
    end

    it "他人の商品は編集できない" do
      other = User.create!(name: "他", email: "other@example.com", password: "password123")

      patch "/api/v1/products/#{product.id}",
            params: { name: "改ざん" },
            headers: auth_header(other),
            as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/products" do
    context "商品が存在する場合" do
      before do
        a = Product.create!(name: "商品A", description: "説明A", user: user)
        a.product_variants.create!(size: "M", price: 1000)
        a.product_variants.create!(size: "L", price: 1500)

        b = Product.create!(name: "商品B", description: nil, user: user)
        b.product_variants.create!(price: 2000)
      end

      it "200 と価格レンジ付きの商品一覧を返す" do
        get "/api/v1/products", as: :json

        expect(response).to have_http_status(:ok)

        body = JSON.parse(response.body)
        expect(body.length).to eq(2)

        product_a = body.find { |p| p["name"] == "商品A" }
        expect(product_a).to include("min_price" => 1000, "max_price" => 1500)

        product_b = body.find { |p| p["name"] == "商品B" }
        expect(product_b).to include("min_price" => 2000, "max_price" => 2000)
      end
    end

    context "商品が存在しない場合" do
      it "200 と空配列を返す" do
        get "/api/v1/products", as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq([])
      end
    end
  end
end
