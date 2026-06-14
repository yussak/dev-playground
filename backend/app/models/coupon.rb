# typed: true

class Coupon < ApplicationRecord
  extend T::Sig

  belongs_to :product
  has_many :coupon_uses, dependent: :destroy

  enum :discount_type, { fixed: "fixed", percentage: "percentage" }

  validates :code, presence: true, uniqueness: true
  validates :discount_type, presence: true
  validates :discount_value, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :discount_value, numericality: { less_than_or_equal_to: 100 }, if: :percentage?
  validates :expires_at, presence: true
  validates :product_id, uniqueness: true

  sig { params(user: User).returns(T::Boolean) }
  def valid_for_use_by?(user)
    return false if expires_at < Time.current
    !coupon_uses.exists?(user: user, status: :used)
  end

  sig { params(cart_items: T::Array[CartItem]).returns(Integer) }
  def discount_amount_for(cart_items)
    target_item = cart_items.find { |ci| ci.product_id == product_id }
    return 0 unless target_item

    # sorbet が product_variant を nil の可能性あり（T.nilable）と判定し型エラーになったため対応。
    # 実際は cart_items.product_variant_id が DB で NOT NULL のため nil にはならない。
    # nil ハンドリング（return 0 等）にしないのは、到達しないデッドコードになるため。
    # そのため T.must で nil でないことを宣言している。
    subtotal = T.must(target_item.product_variant).price * target_item.quantity
    raw = case discount_type
    when "fixed"      then discount_value
    when "percentage" then subtotal * discount_value / 100
    else raise "unexpected discount_type: #{discount_type}"
    end
    [ raw, subtotal ].min
  end
end
