class Product < ApplicationRecord
  belongs_to :user
  has_many :product_images, dependent: :destroy
  has_many :product_variants, dependent: :destroy
  has_many :cart_items, through: :product_variants
  has_many :order_items, dependent: :nullify
  has_one :coupon, dependent: :destroy

  enum :status, { active: "active", deleted: "deleted" }

  validates :name, presence: true
  validates :price, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :variants_pattern_consistency

  private

  def variants_pattern_consistency
    variants = product_variants.reject(&:marked_for_destruction?)
    return if variants.empty?

    patterns = variants.map { |v| [ v.size.present?, v.color.present? ] }.uniq
    return if patterns.size == 1

    errors.add(:product_variants, "のサイズ・カラーの有無は全バリアントで揃える必要があります")
  end
end
