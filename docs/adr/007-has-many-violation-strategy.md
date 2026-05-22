# ADR-007: has_many 違反の対処方針

## ステータス

採用

## コンテキスト

`packs/products` パックを切り出した結果、Product モデルが持つ逆参照（has_many / has_one）が packwerk の dependency violation として検出された。

具体的な違反:

- Product → CartItem（`has_many :cart_items, dependent: :destroy`）
- Product → OrderItem（`has_many :order_items, dependent: :nullify`）
- Product → Coupon（`has_one :coupon, dependent: :destroy`）

いずれも `packs/products` から root パックのクラスを参照しており、`enforce_dependencies: true` のもとで違反となる。

これらは性質が同じ（Product 側からの逆参照）なので、共通の方針で対処する。

## 決定

公開API経由でアクセスする形に一度で書き換える。段階を踏まず、最終形を最初から作る。

### 採用理由

- packwerk のベストプラクティスとして「パック間のアクセスは公開API経由」が推奨されている（Shopify の packwerk ドキュメント）
- このリポジトリは規模が小さく、一気に書き換えても破綻しない
- 中間状態を経由すると、後で同じ箇所を再度書き換えるコストが発生する
- 「段階を踏む練習」は別の違反対処で試せる

### 対処手順

1. 参照先モデル（CartItem / OrderItem / Coupon）を専用パックに切り出す
   - `packs/cart/app/models/cart_item.rb`
   - `packs/orders/app/models/order_item.rb`（OrderItem 側）
   - `packs/coupons/app/models/coupon.rb`
2. 各パックの `app/public/` に公開API クラスを置く
   - 例: `packs/cart/app/public/cart_item_finder.rb` に `CartItemFinder.for(product)` を定義する
3. `packs/<pack_name>/package.yml` を作成し、`enforce_dependencies: true` / `enforce_privacy: true` を有効にする
4. `packs/products/package.yml` の dependencies に、参照する先のパックを宣言する
5. Product 側の `has_many` / `has_one` を削除する
6. `Product.cart_items` 等の呼び出し箇所を `CartItemFinder.for(product)` 経由に書き換える

### dependent オプションの扱い

`has_many` を削除すると `dependent: :destroy` / `dependent: :nullify` の効果も消える。Product は `status: deleted` による論理削除を前提としているため、物理削除が起きない限り対処不要。物理削除フローが存在する場合は、サービスクラスや別フックで補完する。

### 適用範囲

Product → CartItem に限らず、Product → OrderItem / Product → Coupon にも同じ方針を適用する。

## 補足

- 公開API化は一気に行うが、対象モデルごとに違反は独立しているため、コミットは違反単位に分けて構わない
- 各コミットの完了条件: `packwerk check` 緑 + テスト緑
- `dependent` の補完が必要な場合は別途検討する
