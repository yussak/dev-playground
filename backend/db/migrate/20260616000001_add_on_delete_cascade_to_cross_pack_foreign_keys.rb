class AddOnDeleteCascadeToCrossPackForeignKeys < ActiveRecord::Migration[8.1]
  def change
    # cross-pack の連鎖削除を DB レベルで表現する（ADR-010）
    # AR の has_many / has_one の dependent: は逆方向参照の撤去とともに撤去するため、
    # 連鎖削除の責務を DB の ON DELETE に移す
    [
      [ :coupons,         :products,         :cascade ],
      [ :coupon_uses,     :coupons,          :cascade ],
      [ :product_variants, :products,        :cascade ],
      [ :cart_items,      :product_variants, :cascade ],
      [ :order_items,     :product_variants, :nullify ],
      [ :product_images,  :products,         :cascade ],
      [ :stocks,          :product_variants, :cascade ]
    ].each do |from, to, action|
      remove_foreign_key from, to
      add_foreign_key from, to, on_delete: action
    end
  end
end
