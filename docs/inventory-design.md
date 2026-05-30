# 在庫管理機能 設計

要件: `docs/inventory-requirements.md`
TODO: `docs/inventory-todo.md`

スライス単位で設計を記録する。

## スライス 1: 在庫の最低限 MVP

### データモデル

- 新規テーブル `stocks` を作成する
  - 列: `id`, `product_variant_id`, `quantity` (integer, null: false, default: 0), `created_at`, `updated_at`
  - `product_variant_id` にユニーク制約と外部キーを張る（1 商品オプション = 1 stock）
- `Stock` モデルを新設、`belongs_to :product_variant`
- `ProductVariant` に `has_one :stock` を追加
- `Stock` のバリデーション: `quantity` は 0 以上 999,999 以下の整数
- `ProductVariant` の作成時に対応する `Stock` を作成する（after_create で `create_stock!`）

### API: 出品者向け在庫編集

- ルート: `PATCH /api/v1/product_variants/:variant_id/stock`
  - routes.rb 上は `resources :product_variants do resource :stock end` でネスト
- コントローラ: `Api::V1::StocksController#update` を新設
- 認可: `Stock` から `ProductVariant → Product → user_id` をたどり、`@current_user.id == product.user_id` のみ許可
- リクエスト: `{ quantity: <integer> }`
- レスポンス: 更新後の在庫情報を返す

### API: 注文確定時の在庫チェックと減算

- 対象: 既存の `Api::V1::OrdersController#create`
- 既存のトランザクション内で次を行う
  - active_items の各 cart_item について、`product_variant.stock.quantity < cart_item.quantity` を検査
  - 1 件でも在庫不足があれば注文全体を失敗にしてエラーを返す（スライス 1 では全失敗。スライス 6 で部分成立に拡張）
  - 在庫が足りる場合、order_items 作成と同時に対応する Stock の `quantity` を `decrement!(:quantity, cart_item.quantity)` で減算

### フロント: 出品者向け在庫管理画面（最低限）

- 商品オプション一覧 + 在庫数の編集フォーム
- 在庫数を送信して PATCH API を呼ぶ
- 商品編集画面とは分離する

### フロント: 在庫切れ時の購入者画面（最低限）

- 在庫切れの商品オプションは、商品詳細画面でその商品オプションの注文（「カートに入れる」）ボタンを非活性にする
- 一覧・カートでの在庫切れ表示はスライス 2 で行う

### スライス 1 で扱わない範囲（後続スライスで対応）

- 商品一覧・カートでの在庫切れ表示
- カート追加 API での在庫チェック
- キャンセル時の在庫加算
- カート保持中の在庫切れ自動移動
- 注文確定時の部分成立とモーダル
- 在庫数の増減操作と差分合算
- 残り N 点表示
