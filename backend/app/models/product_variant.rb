class ProductVariant < ApplicationRecord
  belongs_to :product

  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
