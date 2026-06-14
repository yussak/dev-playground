module Catalog
  class ProductImage < ApplicationRecord
    self.table_name = "product_images"

    belongs_to :product

    validates :url, presence: true
  end
end
