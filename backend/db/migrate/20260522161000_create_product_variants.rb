class CreateProductVariants < ActiveRecord::Migration[8.1]
  def up
    # バリアント機能導入に伴い、既存のショッピング系データを全削除
    execute "DELETE FROM coupon_uses"
    execute "DELETE FROM coupons"
    execute "DELETE FROM order_items"
    execute "DELETE FROM orders"
    execute "DELETE FROM cart_items"
    execute "DELETE FROM carts"
    execute "DELETE FROM product_images"
    execute "DELETE FROM products"

    create_table :product_variants do |t|
      t.references :product, null: false, foreign_key: true
      t.string :size
      t.string :color
      t.integer :price, null: false
      t.timestamps
    end

    add_index :product_variants, [ :product_id, :size, :color ],
      unique: true, name: "idx_product_variants_size_and_color",
      where: "size IS NOT NULL AND color IS NOT NULL"
    add_index :product_variants, [ :product_id, :size ],
      unique: true, name: "idx_product_variants_size_only",
      where: "size IS NOT NULL AND color IS NULL"
    add_index :product_variants, [ :product_id, :color ],
      unique: true, name: "idx_product_variants_color_only",
      where: "size IS NULL AND color IS NOT NULL"
    add_index :product_variants, [ :product_id ],
      unique: true, name: "idx_product_variants_no_axis",
      where: "size IS NULL AND color IS NULL"
  end

  def down
    drop_table :product_variants
  end
end
