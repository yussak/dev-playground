module Ordering
  # ordering モジュールの公開窓口。外部からはこのクラス経由でのみ呼ぶ。
  class Api
    def self.find_cart_for(user)
      Cart.find_by(user: user)
    end
  end
end
