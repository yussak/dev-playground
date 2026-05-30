class AddStatusToCartItems < ActiveRecord::Migration[8.1]
  def change
    add_column :cart_items, :status, :string, null: false, default: "active"
  end
end
