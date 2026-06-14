require "rails_helper"

RSpec.describe Identity::User, type: :model do
  describe "validations" do
    describe "email" do
      it "空のとき無効" do
        user = Identity::User.new(name: "テスト", email: "", password: "password123")
        expect(user).not_to be_valid
        expect(user.errors[:email]).to be_present
      end

      it "不正なフォーマットのとき無効" do
        user = Identity::User.new(name: "テスト", email: "invalid-email", password: "password123")
        expect(user).not_to be_valid
        expect(user.errors[:email]).to be_present
      end

      it "重複しているとき無効" do
        Identity::User.create!(name: "テスト", email: "test@example.com", password: "password123")
        user = Identity::User.new(name: "テスト2", email: "test@example.com", password: "password123")
        expect(user).not_to be_valid
        expect(user.errors[:email]).to be_present
      end

      it "正しいフォーマットのとき有効" do
        user = Identity::User.new(name: "テスト", email: "test@example.com", password: "password123")
        expect(user).to be_valid
      end
    end

    describe "password" do
      it "空のとき無効" do
        user = Identity::User.new(name: "テスト", email: "test@example.com", password: "")
        expect(user).not_to be_valid
        expect(user.errors[:password]).to be_present
      end
    end
  end

  describe "has_secure_password" do
    it "正しいパスワードで認証できる" do
      user = Identity::User.create!(name: "テスト", email: "test@example.com", password: "password123")
      expect(user.authenticate("password123")).to eq user
    end

    it "誤ったパスワードでは認証できない" do
      user = Identity::User.create!(name: "テスト", email: "test@example.com", password: "password123")
      expect(user.authenticate("wrong")).to be false
    end
  end
end
