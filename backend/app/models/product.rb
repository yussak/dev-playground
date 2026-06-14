class Product < ApplicationRecord
  # user は identity の所有。規約推論だと存在しない top-level User を探すため明示
  belongs_to :user, class_name: "Identity::User"
  has_many :product_images, dependent: :destroy
  has_many :product_variants, dependent: :destroy
  has_many :cart_items, through: :product_variants
  has_many :order_items, through: :product_variants
  has_one :coupon, dependent: :destroy

  enum :status, { active: "active", deleted: "deleted" }

  validates :name, presence: true
  validate :variants_pattern_consistency

  def total_stock
    product_variants.includes(:stock).sum { |v| v.stock&.quantity || Stock::DEFAULT_QUANTITY }
  end

  private

  def variants_pattern_consistency
    variants = product_variants.reject(&:marked_for_destruction?)
    return if variants.empty?

    patterns = variants.map { |v| [ v.size.present?, v.color.present? ] }.uniq
    return if patterns.size == 1

    errors.add(:product_variants, "のサイズ・カラーの有無は全バリアントで揃える必要があります")
  end
end
