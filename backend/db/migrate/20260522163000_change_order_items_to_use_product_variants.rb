class ChangeOrderItemsToUseProductVariants < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM coupon_uses"
    execute "DELETE FROM order_items"
    execute "DELETE FROM orders"

    remove_foreign_key :order_items, :products
    remove_index :order_items, name: "index_order_items_on_product_id"
    remove_column :order_items, :product_id

    add_reference :order_items, :product_variant, null: true, foreign_key: true
    add_column :order_items, :size, :string
    add_column :order_items, :color, :string
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
