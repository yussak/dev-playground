require "rails_helper"

RSpec.describe "Api::V1::Coupons", type: :request do
  let!(:seller) { Identity::User.create!(name: "出品者", email: "seller@example.com", password: "password123") }
  let!(:other_user) { Identity::User.create!(name: "他ユーザー", email: "other@example.com", password: "password123") }
  let!(:product) { Product.create!(name: "商品A", user: seller) }

  def auth_header(user)
    { "Authorization" => "Bearer #{Identity::Api.encode_token(user_id: user.id)}" }
  end

  describe "POST /api/v1/products/:product_id/coupons" do
    let(:valid_params) do
      { discount_type: "fixed", discount_value: 500, expires_at: 1.month.from_now.iso8601 }
    end

    context "出品者本人の場合" do
      it "クーポンが作成される" do
        expect {
          post "/api/v1/products/#{product.id}/coupons", params: valid_params, headers: auth_header(seller), as: :json
        }.to change(Coupon, :count).by(1)

        expect(response).to have_http_status(:created)

        body = JSON.parse(response.body)
        expect(body).to include("discount_type" => "fixed", "discount_value" => 500)
        expect(body["product_id"]).to eq(product.id)
      end

      it "クーポンコードがシステムによって自動生成される" do
        post "/api/v1/products/#{product.id}/coupons", params: valid_params, headers: auth_header(seller), as: :json

        body = JSON.parse(response.body)
        expect(body["code"]).to be_present
        expect(body["code"].length).to be >= 8
      end
    end

    context "未認証の場合" do
      it "認証エラーになる" do
        post "/api/v1/products/#{product.id}/coupons", params: valid_params, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "出品者本人でない場合" do
      it "権限エラーになる" do
        post "/api/v1/products/#{product.id}/coupons", params: valid_params, headers: auth_header(other_user), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "存在しない商品の場合" do
      it "商品が見つからない" do
        post "/api/v1/products/99999/coupons", params: valid_params, headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "既にクーポンが存在する商品の場合" do
      before do
        Coupon.create!(product: product, code: "EXISTING1", discount_type: "fixed", discount_value: 300, expires_at: 1.month.from_now)
      end

      it "クーポンを作成できない" do
        expect {
          post "/api/v1/products/#{product.id}/coupons", params: valid_params, headers: auth_header(seller), as: :json
        }.not_to change(Coupon, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "必須パラメータが不足している場合" do
      it "discount_type が空なら作成できない" do
        post "/api/v1/products/#{product.id}/coupons", params: valid_params.except(:discount_type), headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "discount_value が空なら作成できない" do
        post "/api/v1/products/#{product.id}/coupons", params: valid_params.except(:discount_value), headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "expires_at が空なら作成できない" do
        post "/api/v1/products/#{product.id}/coupons", params: valid_params.except(:expires_at), headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "discount_value が不正な場合" do
      it "0 以下なら作成できない" do
        post "/api/v1/products/#{product.id}/coupons", params: valid_params.merge(discount_value: 0), headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "percentage で 100 を超える場合は作成できない" do
        post "/api/v1/products/#{product.id}/coupons", params: { discount_type: "percentage", discount_value: 101, expires_at: 1.month.from_now.iso8601 }, headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /api/v1/products/:product_id/coupons" do
    context "出品者本人の場合" do
      context "クーポンが存在する場合" do
        let!(:coupon) do
          Coupon.create!(product: product, code: "SUMMER2026", discount_type: "fixed", discount_value: 500, expires_at: 1.month.from_now)
        end

        it "クーポン情報が取得できる" do
          get "/api/v1/products/#{product.id}/coupons", headers: auth_header(seller), as: :json

          expect(response).to have_http_status(:ok)

          body = JSON.parse(response.body)
          expect(body).to be_an(Array)
          expect(body.length).to eq(1)
          expect(body.first).to include(
            "code" => "SUMMER2026",
            "discount_type" => "fixed",
            "discount_value" => 500,
            "product_id" => product.id
          )
        end
      end

      context "クーポンが存在しない場合" do
        it "空の結果が返る" do
          get "/api/v1/products/#{product.id}/coupons", headers: auth_header(seller), as: :json

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq([])
        end
      end
    end

    context "未認証の場合" do
      it "認証エラーになる" do
        get "/api/v1/products/#{product.id}/coupons", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "出品者本人でない場合" do
      it "権限エラーになる" do
        get "/api/v1/products/#{product.id}/coupons", headers: auth_header(other_user), as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "存在しない商品の場合" do
      it "商品が見つからない" do
        get "/api/v1/products/99999/coupons", headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/v1/products/:product_id/coupons/:id" do
    let!(:coupon) do
      Coupon.create!(product: product, code: "ORIGINAL1", discount_type: "fixed", discount_value: 500, expires_at: 1.month.from_now)
    end

    context "出品者本人の場合" do
      it "discount_value が更新できる" do
        patch "/api/v1/products/#{product.id}/coupons/#{coupon.id}", params: { discount_value: 800 }, headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:ok)
        expect(coupon.reload.discount_value).to eq(800)
      end

      it "expires_at が更新できる" do
        new_expires_at = 2.months.from_now
        patch "/api/v1/products/#{product.id}/coupons/#{coupon.id}", params: { expires_at: new_expires_at.iso8601 }, headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:ok)
        expect(coupon.reload.expires_at).to be_within(1.second).of(new_expires_at)
      end

      it "discount_type が更新できる" do
        patch "/api/v1/products/#{product.id}/coupons/#{coupon.id}", params: { discount_type: "percentage", discount_value: 10 }, headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:ok)
        expect(coupon.reload.discount_type).to eq("percentage")
      end

      it "code は更新できない" do
        patch "/api/v1/products/#{product.id}/coupons/#{coupon.id}", params: { code: "NEWCODE12" }, headers: auth_header(seller), as: :json

        expect(coupon.reload.code).to eq("ORIGINAL1")
      end
    end

    context "未認証の場合" do
      it "認証エラーになる" do
        patch "/api/v1/products/#{product.id}/coupons/#{coupon.id}", params: { discount_value: 800 }, as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "出品者本人でない場合" do
      it "権限エラーになる" do
        patch "/api/v1/products/#{product.id}/coupons/#{coupon.id}", params: { discount_value: 800 }, headers: auth_header(other_user), as: :json

        expect(response).to have_http_status(:forbidden)
        expect(coupon.reload.discount_value).to eq(500)
      end
    end

    context "存在しないクーポンの場合" do
      it "クーポンが見つからない" do
        patch "/api/v1/products/#{product.id}/coupons/99999", params: { discount_value: 800 }, headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "不正なパラメータの場合" do
      it "discount_value が 0 以下なら更新できない" do
        patch "/api/v1/products/#{product.id}/coupons/#{coupon.id}", params: { discount_value: 0 }, headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(coupon.reload.discount_value).to eq(500)
      end

      it "percentage で 100 を超える場合は更新できない" do
        patch "/api/v1/products/#{product.id}/coupons/#{coupon.id}", params: { discount_type: "percentage", discount_value: 101 }, headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /api/v1/products/:product_id/coupons/:id" do
    let!(:coupon) do
      Coupon.create!(product: product, code: "TODELETE1", discount_type: "fixed", discount_value: 500, expires_at: 1.month.from_now)
    end

    context "出品者本人の場合" do
      it "クーポンが削除される" do
        expect {
          delete "/api/v1/products/#{product.id}/coupons/#{coupon.id}", headers: auth_header(seller), as: :json
        }.to change(Coupon, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end

    context "未認証の場合" do
      it "認証エラーになる" do
        delete "/api/v1/products/#{product.id}/coupons/#{coupon.id}", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "出品者本人でない場合" do
      it "権限エラーになる" do
        expect {
          delete "/api/v1/products/#{product.id}/coupons/#{coupon.id}", headers: auth_header(other_user), as: :json
        }.not_to change(Coupon, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "存在しないクーポンの場合" do
      it "クーポンが見つからない" do
        delete "/api/v1/products/#{product.id}/coupons/99999", headers: auth_header(seller), as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
