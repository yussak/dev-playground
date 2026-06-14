# クーポン使用記録
# 1ユーザー1回の利用制限管理と、注文キャンセル時のクーポン復元のために必要。
class CouponUse < ApplicationRecord
  belongs_to :coupon  # どのクーポンが使われたか
  # user は identity の所有。規約推論だと存在しない top-level User を探すため明示
  belongs_to :user, class_name: "Identity::User"  # 誰が使ったか（1ユーザー1回制限の判定に必要）
  belongs_to :order   # どの注文で使われたか（キャンセル時にどの使用記録を削除するか特定するために必要）

  enum :status, { unused: "unused", used: "used" }

  validates :status, presence: true
end
