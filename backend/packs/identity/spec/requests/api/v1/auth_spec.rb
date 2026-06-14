require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    context "メールアドレスが未登録のとき" do
      it "201 と token を返す" do
        post "/api/v1/auth/register", params: { name: "テスト", email: "test@example.com", password: "password123" }, as: :json
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)).to have_key("token")
      end
    end

    context "メールアドレスが登録済みのとき" do
      before { Identity::User.create!(name: "テスト", email: "test@example.com", password: "password123") }

      it "422 を返す" do
        post "/api/v1/auth/register", params: { name: "テスト2", email: "test@example.com", password: "password123" }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/v1/auth/login" do
    before { Identity::User.create!(name: "テスト", email: "test@example.com", password: "password123") }

    context "正しいパスワードのとき" do
      it "200 と token を返す" do
        post "/api/v1/auth/login", params: { email: "test@example.com", password: "password123" }, as: :json
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to have_key("token")
      end
    end

    context "パスワードが誤っているとき" do
      it "401 を返す" do
        post "/api/v1/auth/login", params: { email: "test@example.com", password: "wrong" }, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    it "200 を返す" do
      delete "/api/v1/auth/logout", as: :json
      expect(response).to have_http_status(:ok)
    end
  end
end
