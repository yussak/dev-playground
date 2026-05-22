class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :product_variant, optional: true

  validates :product_name, presence: true
  validates :unit_price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
