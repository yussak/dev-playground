# ADR-010: pack 間の連鎖削除を DB レベル cascade で表現する

## ステータス

採用

## コンテキスト

ステップ5（境界締め）で逆方向の `has_many` / `has_one` を撤去する必要がある（ADR-008 に基づく依存方向の片方向化）。具体的には、上流 pack（catalog）から下流 pack（promotion / ordering）への参照を消す。

しかし関連を撤去すると `dependent: :destroy` / `dependent: :nullify` も同時に消える。これまで `product.destroy` 時に連鎖していた削除（以下）が動かなくなる:

- `Catalog::Product` → `Promotion::Coupon`（destroy）
- `Catalog::Product` → `Catalog::ProductVariant` → `Ordering::CartItem`（destroy）
- `Catalog::Product` → `Catalog::ProductVariant` → `Ordering::OrderItem`（nullify）
- `Catalog::Product` → `Catalog::ProductImage`（destroy）
- `Catalog::ProductVariant` → `Catalog::Stock`（destroy、pack 内）
- `Promotion::Coupon` → `Promotion::CouponUse`（destroy、pack 内）

ADR-008 で確定した依存方向は ordering→promotion→catalog→identity の一方向のみで、catalog から promotion / ordering を呼ぶのは禁止されている。したがって catalog 内部から `Promotion::Api` / `Ordering::Api` を呼んでクリーンアップする選択肢は採れない。

`product.destroy` 時の連鎖削除の責務をどこに置くかを決める必要がある。

現状の schema は全 FK に `on_delete` オプションが付いておらず、Rails のデフォルト（RESTRICT 動作）になっている。これまで AR の `dependent:` が削除を駆動していたため気付きにくかった。

## 検討した案

### 案A: DB レベル cascade に任せる

- migration を追加し、関連する FK に `on_delete: :cascade` / `:nullify` を設定する
- AR 側の `dependent:` は撤去されるが、DB レベルで連鎖削除/nullify される
- メリット:
  - 参照整合性・削除整合性は元々 DB の責務。言語非依存で堅牢
  - 修正は migration 1個。pack 間 API のオーケストレーション設計を増やさない
  - 「product を消したら関連も消える」というドメイン要求を DB に表現するだけ
- デメリット:
  - 振る舞いがコード（モデル）から読み取りにくく、schema を見ないと分からない
  - 既存 FK 全件に `on_delete` を追加する必要がある

### 案B: ルート pack に削除のオーケストレーションサービスを置く

- `app/services/product_destruction.rb` のようなクラスをルート pack に追加
- このサービスが `Promotion::Api.purge_for_product(id)` / `Ordering::Api.purge_for_product(id)` / `Catalog::Product#destroy` をトランザクション内で順番に呼ぶ
- 各 Api に `purge_for_product` 系メソッドを追加する
- メリット:
  - 連鎖削除の意図がコードに明示的に残る
  - 各 pack の責務（自分の AR は自分で消す）が API として明確になる
- デメリット:
  - 新しい抽象レイヤ（サービス）と複数の Api メソッド追加が必要で、修正規模が大きい
  - 削除のたびに「サービス経由」を強制する規律が要る

### 案C: 論理削除に切り替える

- physical delete をやめ、`Catalog::Product` に `status: :deleted` を立てる運用に変える
- cart_json は既に `product_deleted` フラグを参照しているため、表示側の追従は最小
- メリット:
  - cascade の議論自体が不要になる
- デメリット:
  - 振る舞いの変化（DB レコードは残る）
  - 「最初の一歩」のスコープから外れる。データ保持方針の見直しが他の機能にも波及する可能性

## 提案

案Aを提案する。

## 提案理由

- 参照整合性・削除整合性は DB の責務として表現するのが筋。`dependent:` は AR 流のショートカットで、本来は DB の cascade と等価の意図
- ステップ5の本筋（pack 間境界の強制）に対して、削除のオーケストレーションという別軸の設計を増やさずに済む（案B）
- 振る舞いを変えずに済む（案C は論理削除化で振る舞いが変わる）

## 影響（提案採用時）

- migration を1個追加し、以下の FK に `on_delete` を設定する:
  - `coupons → products` を `:cascade`
  - `coupon_uses → coupons` を `:cascade`
  - `product_variants → products` を `:cascade`
  - `cart_items → product_variants` を `:cascade`
  - `order_items → product_variants` を `:nullify`
  - `product_images → products` を `:cascade`
  - `stocks → product_variants` を `:cascade`
- 既存の `has_many` / `has_one` 関連から `dependent:` を撤去する。pack 内の関連についても整合性を持って撤去（DB 側で表現するため）
- 振る舞いは現状と同等を維持する
