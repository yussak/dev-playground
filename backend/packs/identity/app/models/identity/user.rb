module Identity
  class User < ApplicationRecord
    self.table_name = "users"

    has_secure_password
    has_many :products, dependent: :destroy
    has_one :cart, dependent: :destroy
    has_many :orders, dependent: :destroy
    validates :name, presence: true
    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  end
end
