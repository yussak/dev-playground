module Ordering
  class OrderItem < ApplicationRecord
    self.table_name = "order_items"

    belongs_to :order
    # product_variant は catalog の所有。規約推論だと存在しない top-level ProductVariant を探すため明示
    belongs_to :product_variant, class_name: "Catalog::ProductVariant", optional: true

    validates :product_name, presence: true
    validates :unit_price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  end
end
