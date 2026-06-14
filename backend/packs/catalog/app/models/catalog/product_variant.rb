module Catalog
  class ProductVariant < ApplicationRecord
    self.table_name = "product_variants"

    belongs_to :product
    has_many :cart_items, dependent: :destroy
    has_many :order_items, dependent: :nullify
    has_one :stock, dependent: :destroy

    after_create :create_stock!

    validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
