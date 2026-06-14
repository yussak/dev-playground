require "rails_helper"

RSpec.describe Identity::JwtHelper do
  describe ".encode / .decode" do
    it "encode したトークンを decode できる" do
      payload = { user_id: 1 }
      token = Identity::JwtHelper.encode(payload)
      decoded = Identity::JwtHelper.decode(token)
      expect(decoded[:user_id]).to eq 1
    end

    it "不正なトークンは nil を返す" do
      expect(Identity::JwtHelper.decode("invalid.token")).to be_nil
    end

    it "改ざんされたトークンは nil を返す" do
      token = Identity::JwtHelper.encode({ user_id: 1 })
      tampered = token + "tampered"
      expect(Identity::JwtHelper.decode(tampered)).to be_nil
    end
  end
end
