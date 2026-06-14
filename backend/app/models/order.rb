class Order < ApplicationRecord
  # user は identity の所有。規約推論だと存在しない top-level User を探すため明示
  belongs_to :user, class_name: "Identity::User"
  has_many :order_items, dependent: :destroy
  has_one :coupon_use, dependent: :destroy

  enum :status, { confirmed: "confirmed", cancelled: "cancelled" }

  validates :order_number, presence: true, uniqueness: true
end
