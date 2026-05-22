class ChangeCartItemsToUseProductVariants < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM cart_items"

    remove_foreign_key :cart_items, :products
    remove_index :cart_items, name: "index_cart_items_on_cart_id_and_product_id"
    remove_index :cart_items, name: "index_cart_items_on_product_id"
    remove_column :cart_items, :product_id

    add_reference :cart_items, :product_variant, null: false, foreign_key: true
    add_index :cart_items, [ :cart_id, :product_variant_id ], unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
