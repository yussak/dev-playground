module Catalog
  # catalog モジュールの公開窓口。外部からはこのクラス経由でのみ呼ぶ。
  class Api
    def self.find_product(id)
      Product.find_by(id: id)
    end

    def self.find_product_variant(id)
      ProductVariant.find_by(id: id)
    end
  end
end
