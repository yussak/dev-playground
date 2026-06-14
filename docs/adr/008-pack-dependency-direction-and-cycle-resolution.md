# ADR-008: pack 間依存方向と promotion ⇄ ordering 循環の解消

## ステータス

採用

## コンテキスト

ステップ5（境界締め）で各 pack の `dependencies` を明示し、`enforce_dependencies: true` / `enforce_privacy: true` に切り替える段階で、依存方向を確定する必要がある。コードから導いた現状の参照関係は次のとおり。

- catalog → identity（`Product belongs_to :user`）
- promotion → catalog, identity（`Coupon belongs_to :product`、`CouponUse belongs_to :user`）
- ordering → catalog, identity, promotion（`Cart/Order belongs_to :user`、`*Item belongs_to :product_variant`、`Order has_one :coupon_use`）
- promotion → ordering（`CouponUse belongs_to :order`）

ここで `Ordering::Order has_one :coupon_use, class_name: "Promotion::CouponUse"` と `Promotion::CouponUse belongs_to :order, class_name: "Ordering::Order"` が双方向参照になり、promotion ⇄ ordering の循環依存が発生する。Packwerk の `dependencies` は循環を許さないため、どちらかの方向に倒す必要がある。

## 検討した案

### 案A: `Order has_one :coupon_use` を撤去し、ordering→promotion 片方向にする

- `Ordering::Order has_one :coupon_use, class_name: "Promotion::CouponUse"` を撤去
- `Promotion::Api.cancel_usage(order_id)` を追加し、`orders_controller#cancel` の `order.coupon_use&.destroy!` を置換
- 注文時点の結果（`discount_amount`）は `Order` に保持し、`CouponUse` は promotion 内部の状態として閉じる
- メリット: ordering→promotion 片方向に閉じる。Order が CouponUse という promotion 内部の概念を直接保持しなくなり、依存が細くなる
- デメリット: 取消時に直接 destroy できず、promotion 側の API 呼び出しが必要になる

### 案B: `CouponUse belongs_to :order` を撤去し、promotion→ordering 片方向にする

- `CouponUse` から `order_id` の関連を切り、promotion 側から ordering 経由で参照する
- メリット: 依存方向の流れ（ordering は上流、promotion は下流）に逆らわない
- デメリット: `CouponUse` が「どの注文で使われたか」を持たないと、使用記録としての意味が壊れる（キャンセル時に該当の使用記録を特定できない）。データモデルとして不自然

### 案C: 循環依存を許容する

- `dependencies` を双方向に書く、または書かず `enforce_dependencies` を false に留める
- メリット: 自然な関連がそのまま残る
- デメリット: 「移行完了後に両方 true」（`docs/mm-first-try.md` のステップ強制レベル決定）と矛盾。学習目的にも反する

## 決定

案Aを採用。

## 採用理由

- 案B はデータモデルが不自然、案C は本ブランチの方針と矛盾するため、消去法でも案Aが残る
- 現状スキーマと整合する。`orders` テーブルは元から `coupon_use_id` を持たず `discount_amount` を持っているため、マイグレーション不要でモデル関連とコントローラの呼び出し置換だけで完結する
- Order は「注文時点の結果（割引額）」だけ保持し、`CouponUse` という promotion 内部の概念に依存しない形になる。境界が明確になり、ordering→promotion のやりとりが `Promotion::Api` の呼び出しに集約される

## 影響

- `Ordering::Order has_one :coupon_use, class_name: "Promotion::CouponUse"` を撤去する
- `Promotion::Api` に以下を追加する（ordering→promotion のやりとりを Api に集約）:
  - `validate_coupon(code:, user:, items:)` — 有効性チェックと対象商品有無確認。成功時 `{ valid: true, coupon_id: <id> }` / 失敗時 `{ valid: false, error: :not_found | :invalid | :no_target_in_cart }`
  - `calculate_discount(coupon_id:, items:)` — 割引額計算（戻り値 Integer）
  - `record_usage(coupon_id:, user:, order:)` — `CouponUse` 作成
  - `cancel_usage(order_id)` — 該当の `CouponUse` を破棄
- 上記を `apply_coupon` 単一メソッドにまとめない理由: 現状の `orders_controller#create` はクーポン有効性チェックを `orderable_items`（在庫無視）に対して行い、割引額計算を `purchasable_items`（在庫が足りる分のみ）に対して行っている（在庫切れで対象商品が除外されたとき、チェックは通るが割引額は 0 になる挙動）。振る舞いを変えない移設方針のため、Api 側もこの二段階に分ける
- `orders_controller` から `Promotion::Coupon` / `Promotion::CouponUse` の直接参照を撤去し、`Promotion::Api` 経由のみにする
- 各 pack の `package.yml` の `dependencies` は以下の一方向に確定する:
  - identity: 依存なし
  - catalog: identity
  - promotion: catalog, identity
  - ordering: catalog, identity, promotion
