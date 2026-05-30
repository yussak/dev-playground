require "rails_helper"

RSpec.describe "Api::V1::Orders", type: :request do
  let!(:user) { User.create!(name: "テストユーザー", email: "user@example.com", password: "password123") }
  let!(:product) { Product.create!(name: "商品A", user: user) }
  let!(:variant) { product.product_variants.create!(price: 1000).tap { |v| v.stock.update!(quantity: 100) } }
  let!(:product2) { Product.create!(name: "商品B", user: user) }
  let!(:variant2) { product2.product_variants.create!(price: 2000).tap { |v| v.stock.update!(quantity: 100) } }
  let(:headers) { { "Authorization" => "Bearer #{JwtHelper.encode(user_id: user.id)}" } }

  def auth_header(u)
    { "Authorization" => "Bearer #{JwtHelper.encode(user_id: u.id)}" }
  end

  describe "POST /api/v1/orders" do
    context "カートにアイテムがある場合" do
      before do
        cart = user.create_cart!
        cart.cart_items.create!(product_variant: variant, quantity: 2)
        cart.cart_items.create!(product_variant: variant2, quantity: 1)
      end

      it "注文が作成され、カートが空になる" do
        post "/api/v1/orders", headers: headers, as: :json

        expect(response).to have_http_status(:created)

        body = JSON.parse(response.body)
        expect(body["order_number"]).to be_present
        expect(body["status"]).to eq("confirmed")
        expect(body["items"].length).to eq(2)
        expect(body["total"]).to eq(4000)

        expect(user.cart.cart_items.count).to eq(0)
      end

      it "注文アイテムにスナップショットが保存される" do
        post "/api/v1/orders", headers: headers, as: :json

        body = JSON.parse(response.body)
        item = body["items"].find { |i| i["product_name"] == "商品A" }
        expect(item["unit_price"]).to eq(1000)
        expect(item["quantity"]).to eq(2)
      end
    end

    context "カートが空の場合" do
      it "422を返す" do
        post "/api/v1/orders", headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "在庫が不足している場合" do
      before do
        variant.stock.update!(quantity: 1)
        cart = user.create_cart!
        cart.cart_items.create!(product_variant: variant, quantity: 2)
      end

      it "422を返し、注文は作成されない" do
        expect {
          post "/api/v1/orders", headers: headers, as: :json
        }.not_to change(Order, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(variant.stock.reload.quantity).to eq(1)
      end
    end

    context "注文が成立した場合" do
      before do
        variant.stock.update!(quantity: 10)
        cart = user.create_cart!
        cart.cart_items.create!(product_variant: variant, quantity: 3)
      end

      it "注文した数だけ在庫が減る" do
        post "/api/v1/orders", headers: headers, as: :json

        expect(response).to have_http_status(:created)
        expect(variant.stock.reload.quantity).to eq(7)
      end

      it "partially_unavailable が false になる" do
        post "/api/v1/orders", headers: headers, as: :json

        body = JSON.parse(response.body)
        expect(body["partially_unavailable"]).to eq(false)
      end
    end

    context "一部のアイテムが在庫切れの場合（部分成立）" do
      before do
        variant.stock.update!(quantity: 10)
        variant2.stock.update!(quantity: 0)
        cart = user.create_cart!
        cart.cart_items.create!(product_variant: variant, quantity: 1)
        cart.cart_items.create!(product_variant: variant2, quantity: 1)
      end

      it "在庫がある分だけ注文が成立する" do
        expect {
          post "/api/v1/orders", headers: headers, as: :json
        }.to change(Order, :count).by(1)

        expect(response).to have_http_status(:created)
        body = JSON.parse(response.body)
        expect(body["items"].length).to eq(1)
        expect(body["items"].first["product_name"]).to eq("商品A")
        expect(body["partially_unavailable"]).to eq(true)
      end

      it "在庫切れのアイテムはカートに unavailable として残る" do
        post "/api/v1/orders", headers: headers, as: :json

        remaining = user.cart.cart_items.reload
        expect(remaining.count).to eq(1)
        expect(remaining.first.product_variant).to eq(variant2)
        expect(remaining.first.status).to eq("unavailable")
      end

      it "在庫がある分の在庫数が減る" do
        post "/api/v1/orders", headers: headers, as: :json

        expect(variant.stock.reload.quantity).to eq(9)
        expect(variant2.stock.reload.quantity).to eq(0)
      end
    end

    context "削除済み商品のみの場合" do
      before do
        product.deleted!
        cart = user.create_cart!
        cart.cart_items.create!(product_variant: variant, quantity: 1)
      end

      it "422を返す" do
        post "/api/v1/orders", headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "未認証の場合" do
      it "401を返す" do
        post "/api/v1/orders", as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "クーポンを適用する場合" do
      let!(:seller) { User.create!(name: "出品者", email: "seller-coupon@example.com", password: "password123") }
      let!(:coupon_product) { Product.create!(name: "対象商品", user: seller) }
      let!(:coupon_variant) { coupon_product.product_variants.create!(price: 1000).tap { |v| v.stock.update!(quantity: 100) } }

      context "固定額クーポン" do
        let!(:coupon) do
          Coupon.create!(product: coupon_product, code: "FIXED300", discount_type: "fixed", discount_value: 300, expires_at: 1.month.from_now)
        end

        before do
          cart = user.create_cart!
          cart.cart_items.create!(product_variant: coupon_variant, quantity: 1)
        end

        it "割引額が適用され coupon_use が記録される" do
          expect {
            post "/api/v1/orders", params: { coupon_code: "FIXED300" }, headers: headers, as: :json
          }.to change(CouponUse, :count).by(1)

          expect(response).to have_http_status(:created)

          order = Order.last
          expect(order.discount_amount).to eq(300)

          coupon_use = CouponUse.last
          expect(coupon_use.user_id).to eq(user.id)
          expect(coupon_use.coupon_id).to eq(coupon.id)
          expect(coupon_use.order_id).to eq(order.id)
          expect(coupon_use.status).to eq("used")
        end

        it "レスポンスに subtotal/discount_amount/total が含まれる" do
          post "/api/v1/orders", params: { coupon_code: "FIXED300" }, headers: headers, as: :json

          body = JSON.parse(response.body)
          expect(body["subtotal"]).to eq(1000)
          expect(body["discount_amount"]).to eq(300)
          expect(body["total"]).to eq(700)
        end

        it "対象商品を複数個カートに入れた場合、合計金額に対して割引" do
          user.cart.cart_items.first.update!(quantity: 3)

          post "/api/v1/orders", params: { coupon_code: "FIXED300" }, headers: headers, as: :json

          expect(Order.last.discount_amount).to eq(300)
        end

        it "割引額が商品価格を超える場合は商品価格までに制限される" do
          coupon.update!(discount_value: 2000)

          post "/api/v1/orders", params: { coupon_code: "FIXED300" }, headers: headers, as: :json

          expect(Order.last.discount_amount).to eq(1000)
        end
      end

      context "割合クーポン" do
        let!(:coupon) do
          Coupon.create!(product: coupon_product, code: "PERCENT10", discount_type: "percentage", discount_value: 10, expires_at: 1.month.from_now)
        end

        before do
          cart = user.create_cart!
          cart.cart_items.create!(product_variant: coupon_variant, quantity: 1)
        end

        it "商品金額に対して割引率が適用される" do
          post "/api/v1/orders", params: { coupon_code: "PERCENT10" }, headers: headers, as: :json

          expect(Order.last.discount_amount).to eq(100)
        end

        it "割引率 100% なら商品価格と同じ割引額" do
          coupon.update!(discount_value: 100)

          post "/api/v1/orders", params: { coupon_code: "PERCENT10" }, headers: headers, as: :json

          expect(Order.last.discount_amount).to eq(1000)
        end
      end

      context "クーポンが無効な場合" do
        before do
          cart = user.create_cart!
          cart.cart_items.create!(product_variant: coupon_variant, quantity: 1)
        end

        it "存在しないコードならエラー" do
          expect {
            post "/api/v1/orders", params: { coupon_code: "NOTEXIST" }, headers: headers, as: :json
          }.not_to change(Order, :count)

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "期限切れクーポンならエラー" do
          Coupon.create!(product: coupon_product, code: "EXPIRED01", discount_type: "fixed", discount_value: 300, expires_at: 1.day.ago)

          expect {
            post "/api/v1/orders", params: { coupon_code: "EXPIRED01" }, headers: headers, as: :json
          }.not_to change(Order, :count)

          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "同ユーザーが2回目使うとエラー" do
          coupon = Coupon.create!(product: coupon_product, code: "ONCE12345", discount_type: "fixed", discount_value: 300, expires_at: 1.month.from_now)
          first_order = user.orders.create!(order_number: SecureRandom.uuid, status: :confirmed)
          CouponUse.create!(coupon: coupon, user: user, order: first_order, status: :used)

          expect {
            post "/api/v1/orders", params: { coupon_code: "ONCE12345" }, headers: headers, as: :json
          }.not_to change(Order, :count)

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "対象商品がカートにない場合" do
        let!(:coupon) do
          Coupon.create!(product: coupon_product, code: "NOTARGET1", discount_type: "fixed", discount_value: 300, expires_at: 1.month.from_now)
        end

        before do
          cart = user.create_cart!
          cart.cart_items.create!(product_variant: variant, quantity: 1)
        end

        it "エラーになる" do
          expect {
            post "/api/v1/orders", params: { coupon_code: "NOTARGET1" }, headers: headers, as: :json
          }.not_to change(Order, :count)

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end

      context "クーポンコードなしの場合" do
        before do
          cart = user.create_cart!
          cart.cart_items.create!(product_variant: coupon_variant, quantity: 1)
        end

        it "通常通り注文できる（discount_amount は 0）" do
          post "/api/v1/orders", headers: headers, as: :json

          expect(response).to have_http_status(:created)
          expect(Order.last.discount_amount).to eq(0)
          expect(CouponUse.count).to eq(0)
        end
      end
    end
  end

  describe "PATCH /api/v1/orders/:id/cancel" do
    let!(:order) do
      order = user.orders.create!(order_number: SecureRandom.uuid, status: :confirmed)
      order.order_items.create!(product_variant: variant, product_name: "商品A", unit_price: 1000, quantity: 1)
      order
    end

    context "認証済みの場合" do
      it "注文をキャンセルできる" do
        patch "/api/v1/orders/#{order.id}/cancel", headers: headers, as: :json

        expect(response).to have_http_status(:ok)
        expect(order.reload.status).to eq("cancelled")
      end

      it "すでにキャンセル済みなら422を返す" do
        order.cancelled!
        patch "/api/v1/orders/#{order.id}/cancel", headers: headers, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "他ユーザーの注文はキャンセルできない" do
        other = User.create!(name: "他ユーザー", email: "other@example.com", password: "password123")
        patch "/api/v1/orders/#{order.id}/cancel", headers: auth_header(other), as: :json

        expect(response).to have_http_status(:not_found)
      end

      it "キャンセルすると注文した数だけ在庫が戻る" do
        variant.stock.update!(quantity: 5)
        order.order_items.first.update!(quantity: 3)

        expect {
          patch "/api/v1/orders/#{order.id}/cancel", headers: headers, as: :json
        }.to change { variant.stock.reload.quantity }.from(5).to(8)
      end
    end

    context "クーポンが適用された注文の場合" do
      let!(:seller) { User.create!(name: "出品者", email: "seller-cancel@example.com", password: "password123") }
      let!(:coupon_product) { Product.create!(name: "対象商品", user: seller) }
      let!(:coupon_variant) { coupon_product.product_variants.create!(price: 1000).tap { |v| v.stock.update!(quantity: 100) } }
      let!(:coupon) do
        Coupon.create!(product: coupon_product, code: "CANCELME12", discount_type: "fixed", discount_value: 300, expires_at: 1.month.from_now)
      end
      let!(:coupon_order) do
        o = user.orders.create!(order_number: SecureRandom.uuid, status: :confirmed, discount_amount: 300)
        o.order_items.create!(product_variant: coupon_variant, product_name: "対象商品", unit_price: 1000, quantity: 1)
        CouponUse.create!(coupon: coupon, user: user, order: o, status: :used)
        o
      end

      it "キャンセル時に coupon_use が削除される" do
        expect {
          patch "/api/v1/orders/#{coupon_order.id}/cancel", headers: headers, as: :json
        }.to change(CouponUse, :count).by(-1)
      end

      it "キャンセル後、同じユーザーが同じクーポンを再度使える" do
        patch "/api/v1/orders/#{coupon_order.id}/cancel", headers: headers, as: :json

        cart = user.cart || user.create_cart!
        cart.cart_items.create!(product_variant: coupon_variant, quantity: 1)

        post "/api/v1/orders", params: { coupon_code: "CANCELME12" }, headers: headers, as: :json
        expect(response).to have_http_status(:created)
      end
    end
  end

  describe "GET /api/v1/orders" do
    before do
      2.times do |i|
        order = user.orders.create!(order_number: SecureRandom.uuid, status: :confirmed)
        order.order_items.create!(product_variant: variant, product_name: "商品A", unit_price: 1000, quantity: i + 1)
      end
    end

    it "注文一覧を返す" do
      get "/api/v1/orders", headers: headers, as: :json

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body.length).to eq(2)
      expect(body.first).to include("order_number", "status", "total", "discount_amount", "created_at")
    end

    it "割引が適用された注文は total が割引後の金額になる" do
      discounted = user.orders.create!(order_number: SecureRandom.uuid, status: :confirmed, discount_amount: 150)
      discounted.order_items.create!(product_variant: variant, product_name: "商品A", unit_price: 1000, quantity: 1)

      get "/api/v1/orders", headers: headers, as: :json

      body = JSON.parse(response.body)
      entry = body.find { |o| o["order_number"] == discounted.order_number }
      expect(entry["discount_amount"]).to eq(150)
      expect(entry["total"]).to eq(850)
    end

    it "未認証なら401を返す" do
      get "/api/v1/orders", as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/orders/:id" do
    let!(:order) do
      order = user.orders.create!(order_number: SecureRandom.uuid, status: :confirmed)
      order.order_items.create!(product_variant: variant, product_name: "商品A", unit_price: 1000, quantity: 2)
      order
    end

    it "注文詳細を返す" do
      get "/api/v1/orders/#{order.id}", headers: headers, as: :json

      expect(response).to have_http_status(:ok)

      body = JSON.parse(response.body)
      expect(body["order_number"]).to eq(order.order_number)
      expect(body["items"].length).to eq(1)
      expect(body["items"].first["product_name"]).to eq("商品A")
      expect(body["total"]).to eq(2000)
    end

    context "割引が適用された注文の場合" do
      let!(:discounted_order) do
        o = user.orders.create!(order_number: SecureRandom.uuid, status: :confirmed, discount_amount: 300)
        o.order_items.create!(product_variant: variant, product_name: "商品A", unit_price: 1000, quantity: 1)
        o
      end

      it "subtotal/discount_amount/total を返す" do
        get "/api/v1/orders/#{discounted_order.id}", headers: headers, as: :json

        body = JSON.parse(response.body)
        expect(body["subtotal"]).to eq(1000)
        expect(body["discount_amount"]).to eq(300)
        expect(body["total"]).to eq(700)
      end
    end

    it "他ユーザーの注文は404を返す" do
      other = User.create!(name: "他ユーザー", email: "other@example.com", password: "password123")
      get "/api/v1/orders/#{order.id}", headers: auth_header(other), as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "未認証なら401を返す" do
      get "/api/v1/orders/#{order.id}", as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
