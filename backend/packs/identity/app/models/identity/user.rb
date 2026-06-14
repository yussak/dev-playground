
module Identity
  class User < ApplicationRecord
    self.table_name = "users"

    has_secure_password
    # products は catalog の所有。規約推論だと存在しない top-level Product を探すため明示
    has_many :products, class_name: "Catalog::Product", dependent: :destroy
    # cart / orders は ordering の所有。規約推論だと存在しない top-level Cart/Order を探すため明示
    has_one :cart, class_name: "Ordering::Cart", dependent: :destroy
    has_many :orders, class_name: "Ordering::Order", dependent: :destroy
    validates :name, presence: true
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  end
end
