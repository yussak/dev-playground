class ProductVariant < ApplicationRecord
  belongs_to :product
  has_many :cart_items, dependent: :destroy
  has_many :order_items, dependent: :nullify

  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
