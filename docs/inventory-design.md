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

## スライス 2: 在庫切れ表示

### 責務分離の方針

- API は在庫の実態（数値）を返すだけ。「在庫切れ」「残りわずか」のような表示用ラベルは返さない
- フロントが数値を見て「在庫切れ / 残りわずか / 表示なし」を判定する

### モデル

- `Product#total_stock` メソッドを追加。`product_variants.includes(:stock).sum { |v| v.stock&.quantity.to_i }` を返す

### API: 商品一覧

- `Api::V1::ProductsController#index` のレスポンスの各商品に `total_stock` を追加する

### API: カート

- `Api::V1::CartsController#show` のレスポンスの各 cart_item に該当商品オプションの在庫数 `stock` を追加する

### フロント: 商品一覧

- 各商品で `total_stock === 0` → 「在庫切れ」、`total_stock <= 5` → 「残りわずか」、それ以外は表示なし

### フロント: カート

- 各 cart_item で `cart_item.quantity > stock` → 「在庫切れ」表示

### フロント: 商品詳細

- 既存の商品オプション単位の在庫切れ表示で完結（追加の全体表示はしない）

### スライス 2 で扱わない範囲

- カート追加 API での在庫チェック → スライス 3
- 「現在購入できません」セクションへの自動移動 → スライス 5
- 残り N 点の具体的な在庫数表示（「残り N 点」） → スライス 8

## スライス 3: カート追加時の在庫チェック

### API: カート追加 (`Api::V1::CartItemsController#create`)

- 在庫チェックを追加する
  - 既存の cart_item の数量 + 追加分 1 が `variant.stock.quantity` を超える場合はエラー
  - 在庫切れ (`stock.quantity == 0`) は同じロジックで弾かれる
- エラー時のレスポンス: 422 と `error: "在庫が不足しています"`

### API: カート数量変更 (`Api::V1::CartItemsController#update`)

- 在庫チェックを追加する
  - リクエストで指定された quantity が `variant.stock.quantity` を超える場合はエラー
- エラー時のレスポンス: 422 と `error: "在庫が不足しています"`

### フロント: カート画面

- 各 cart_item 行で、`item.quantity >= item.stock` のとき「＋」ボタンを非活性にする

### スライス 3 で扱わない範囲

- 「現在購入できません」セクションへの自動移動 → スライス 5
- キャンセル時の在庫加算 → スライス 4

## スライス 4: キャンセル時の戻し

### API: 注文キャンセル (`Api::V1::OrdersController#cancel`)

- 既存のトランザクション内で、キャンセル成立と同時に対応する商品オプションの在庫を加算する
- 処理: `order.order_items` を辿り、各 `order_item` の `product_variant.stock` に `increment!(:quantity, item.quantity)` を呼ぶ
- `product_variant` が nil（バリアント削除済み）の場合はスキップする

### スライス 4 で扱わない範囲

- 「現在購入できません」セクションへの自動移動 → スライス 5
- 注文確定時の部分成立とモーダル → スライス 6

## スライス 5: カート保持中の在庫切れ対応

### データモデル

- `cart_items` テーブルに `status` カラム（string, null: false, default: "active"）を追加
- 値は `"active"` / `"unavailable"` の 2 種類
- `CartItem` モデルに enum を追加

### API: カート取得 (`Api::V1::CartsController#show`)

- レスポンスを返す前に、各 cart_item の在庫を確認する
- `stock.quantity < 1` の場合、その cart_item を `unavailable` に更新する
- `stock.quantity >= 1` だった場合、`unavailable` になっていたアイテムを `active` に戻す（在庫が復活したケース）
- レスポンスに `status` を含める

### フロント: カート画面

- `active` なアイテム → 通常のカートテーブルに表示
- `unavailable` なアイテム → 「現在購入できません」セクションに分けて表示
- `unavailable` アイテムは注文対象から除外（「注文を確定する」ボタンの制御はスライス 6）

### スライス 5 で扱わない範囲

- 注文確定時に `unavailable` アイテムを除外して部分成立させる → スライス 6
- 注文確定後に `unavailable` アイテムをカートに残す → スライス 6

## スライス 6: 注文確定時の部分成立

### API: 注文確定 (`Api::V1::OrdersController#create`)

現状の全失敗ロジックを次のように変更する。

- `active` な cart_items のみを注文対象にする（`unavailable` は除外）
- `active` アイテムの中で在庫チェックを行い、不足があれば注文対象からさらに除外して `unavailable` に変更する
- 注文対象が 0 件なら注文不成立（422）
- 注文対象が 1 件以上なら注文成立、対象アイテムのみ order_items を作成して在庫を減算
- 注文成立した cart_items は削除する
- `unavailable` になった cart_items はカートに残す
- レスポンスに `partially_unavailable: true/false` を含めてフロントがモーダルを出し分けられるようにする

### フロント: 注文確定後のモーダル

- 全アイテム成立: 「購入完了しました」のみ
- 一部在庫切れで部分成立: 「購入完了しました」+「以下の商品は在庫切れのため購入できませんでした」（商品リスト）
- 全アイテム在庫切れ: 「購入できる商品がありませんでした」のみ

### スライス 6 で扱わない範囲

- 在庫数の増減操作 → スライス 7
- 残り N 点表示 → スライス 8

## スライス 7: 在庫管理画面の高度化

### API: 在庫増減エンドポイント追加

- 新規: `PATCH /api/v1/product_variants/:variant_id/stock/adjust`
- リクエスト: `{ adjustment: <integer> }` （正の値で増加、負の値で減少）
- 保存値: `[stock.quantity + adjustment, 0].max`（マイナスにならないよう 0 でクランプ）
- 認可: 出品者本人のみ（既存の stock エンドポイントと同じ）

### フロント: 在庫管理画面

- 既存の絶対値入力フォームに加え、増減入力フォームを追加
- 増減フォームは `+N` / `-N` を入力して保存する形

## スライス 8: 残り N 点表示

### フロント: 商品詳細画面

- 各商品オプションで `stock > 0 && stock <= 5` のとき「残り N 点」を表示

### フロント: 商品一覧画面

- 既にスライス 2 で `total_stock <= 5` のとき「残りわずか」を表示済み。変更不要。

### フロント: カート画面

- 各 cart_item で `stock > 0 && stock <= 5` のとき「残り N 点」を表示
