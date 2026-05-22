class RemovePriceFromProducts < ActiveRecord::Migration[8.1]
  def change
    remove_column :products, :price, :integer, null: false
  end
end
