class Product < ApplicationRecord
  belongs_to :user
  has_many :product_images, dependent: :destroy
  has_many :cart_items, dependent: :destroy
  has_many :order_items, dependent: :nullify
  has_one :coupon, dependent: :destroy

  enum :status, { active: "active", deleted: "deleted" }

  validates :name, presence: true
  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
