module Promotion
  # promotion モジュールの公開窓口。外部からはこのクラス経由でのみ呼ぶ。
  class Api
    def self.find_coupon_by_code(code)
      Coupon.find_by(code: code)
    end

    # クーポン有効性チェック。items は在庫を考慮しない注文可能アイテム（対象商品の有無確認のため）
    def self.validate_coupon(code:, user:, items:)
      coupon = Coupon.find_by(code: code)
      return { valid: false, error: :not_found } if coupon.nil?
      return { valid: false, error: :invalid } unless coupon.valid_for_use_by?(user)
      return { valid: false, error: :no_target_in_cart } unless items.any? { |item| item.product_id == coupon.product_id }

      { valid: true, coupon_id: coupon.id }
    end

    # 割引額計算。items は在庫が確保できた購入アイテム（在庫切れで除外された場合、対象商品が含まれず discount は 0 になる）
    def self.calculate_discount(coupon_id:, items:)
      Coupon.find(coupon_id).discount_amount_for(items)
    end

    def self.record_usage(coupon_id:, user:, order:)
      CouponUse.create!(coupon_id: coupon_id, user: user, order: order, status: :used)
    end

    def self.cancel_usage(order_id)
      CouponUse.where(order_id: order_id).destroy_all
    end
  end
end
