class CreateStocks < ActiveRecord::Migration[8.1]
  def change
    create_table :stocks do |t|
      t.references :product_variant, null: false, foreign_key: true, index: { unique: true }
      t.integer :quantity, null: false, default: 0
      t.timestamps
    end
  end
end
