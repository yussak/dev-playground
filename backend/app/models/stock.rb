class Stock < ApplicationRecord
  belongs_to :product_variant

  validates :quantity, presence: true, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 999_999
  }
end
