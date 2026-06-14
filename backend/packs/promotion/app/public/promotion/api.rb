module Promotion
  # promotion モジュールの公開窓口。外部からはこのクラス経由でのみ呼ぶ。
  class Api
    def self.find_coupon_by_code(code)
      Coupon.find_by(code: code)
    end
  end
end
