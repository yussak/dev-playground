class CartItem < ApplicationRecord
  belongs_to :cart
  # product_variant は catalog の所有。規約推論だと存在しない top-level ProductVariant を探すため明示
  belongs_to :product_variant, class_name: "Catalog::ProductVariant"

  delegate :product, :product_id, to: :product_variant

  # active/unavailable の遷移が頻繁かつ双方向のため、別テーブル分割ではなく status カラムで管理する
  enum :status, { active: "active", unavailable: "unavailable" }

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
end
