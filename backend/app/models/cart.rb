class Cart < ApplicationRecord
  # user は identity の所有。規約推論だと存在しない top-level User を探すため明示
  belongs_to :user, class_name: "Identity::User"
  has_many :cart_items, dependent: :destroy
end
