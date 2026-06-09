# ADR-007: モジュールの切り方（初期境界）

## ステータス

提案中

## コンテキスト

issue [#123](https://github.com/yussak/modular-monolith-practice/issues/123) でモジュラモノリス化を開始する。
現在の `app/models/` は以下のモデルがフラットに並んでいる:

- User, Admin
- Product, ProductImage, ProductVariant
- Stock
- Cart, CartItem
- Order, OrderItem
- Coupon, CouponUse

モジュール分割を進める前に、初期境界を仮置きする必要がある。
（後で変更してよいが、最初の仮置きがないと以降の判断が全部ブレる）

主要な参照関係:

- `User → Product (seller), Cart, Order`
- `Product → ProductVariant → Stock`
- `Coupon → Product, CouponUse → User`
- `Cart/Order → ProductVariant`
- `Admin` は独立

## 検討した案

### 案A: 4モジュール

- **Identity**: User, Admin
- **Catalog**: Product, ProductImage, ProductVariant, Stock
- **Ordering**: Cart, CartItem, Order, OrderItem
- **Promotion**: Coupon, CouponUse

メリット:
- DDD/EC の典型的な切り方で学習素材として素直
- 各モジュールに最低2モデル以上あり「モジュールらしい」サイズ感
- 通信パターン（Catalog → Ordering、Promotion → Catalog/Ordering）が観察しやすい

デメリット:
- Stock を Catalog に同居させると、将来 Inventory として独立させたくなる可能性あり
- Coupon が Product を強参照しているので Promotion → Catalog の依存が初日から発生

### 案B: 5モジュール（Inventory 分離）

案A から `Stock` を **Inventory** として独立。

メリット:
- 在庫は本来別文脈（販売とは別の関心事）。将来の発展性を意識した切り方

デメリット:
- 現状 Stock は ProductVariant に 1:1 で belongs_to しているだけで、分離コストが効果に見合わない
- 学習の第一歩としては境界が細かすぎる

### 案C: 3モジュール（粗い）

- Identity / Catalog / Sales（Cart + Order + Coupon を統合）

メリット:
- 最も単純。境界トラブルが少ない

デメリット:
- 「モジュラモノリスの練習」として境界が少なすぎる
- Promotion 文脈が Order に埋もれて学びが薄い

### 案D: User の出品者/購入者分離まで含む

User を Seller と Buyer に分け、出品文脈と購買文脈で別モジュールに。

メリット:
- 本格的な DDD 練習になる

デメリット:
- 第一歩としては複雑すぎる。既存コードの書き換え量が膨大

## 推奨

| 案 | 推奨度 |
|----|--------|
| A: 4モジュール | ★★★★★ |
| B: 5モジュール（Inventory分離） | ★★★☆☆ |
| C: 3モジュール | ★★☆☆☆ |
| D: User分離まで含む | ★★☆☆☆ |

**案A を推奨。**

理由:
- 「とりあえず作る」(issue #123) の方針に最も合うサイズ感
- 境界トラブル・モジュール間通信・依存方向の検討素材が一通り発生する（学習目的に合致）
- Inventory 分離（案B）や User 分離（案D）は、必要を感じた時点で後から切り出せる

## 決定

未決（採用後にここを更新）

## 影響

採用された場合:
- `docs/mm-first-try.md` の「ADRにするもの」から外す
- 次の判断ポイントは「モジュールの実装方式（名前空間 / Packwerk packs / Rails Engine）」
- 既存の cross-module 参照（Product→User、Coupon→Product など）の扱いは、実装方式決定後に都度検討
