class CartItem < ApplicationRecord
  belongs_to :cart
  belongs_to :product_variant

  delegate :product, :product_id, to: :product_variant

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
