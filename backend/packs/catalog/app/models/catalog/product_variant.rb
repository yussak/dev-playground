module Catalog
  class ProductVariant < ApplicationRecord
    self.table_name = "product_variants"

    belongs_to :product
    # cart_items / order_items は ordering の所有。規約推論だと存在しない top-level を探すため明示
    has_many :cart_items, class_name: "Ordering::CartItem", dependent: :destroy
    has_many :order_items, class_name: "Ordering::OrderItem", dependent: :nullify
    has_one :stock, dependent: :destroy

    after_create :create_stock!

    validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  end
end
