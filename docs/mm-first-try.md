# モジュラモノリス 最初の一歩 メモ

issue: [#123](https://github.com/yussak/modular-monolith-practice/issues/123)

「とりあえず作る」フェーズの判断メモ。壁打ちしながら1つずつ決めて、ここに決定を残す。

## 方針

- 判断は壁打ちして1つずつ決め、決定をこのファイルに書く
- ADR は必須にしない。後から「記録として残したい」と思ったものだけ ADR に昇格する
- 覆すときは書き換えてよい（このファイルは記録性を重視しない）

---

## 決定済み

### 移行戦略 → 一括

このブランチは既存コードを一気に MM に作り変えて試すためのもの。
Strangler Fig（新機能から段階的に移行）は将来、別途自分で試す予定。

### モジュールの実装方式 → Packwerk packs

`packs/<module>/app/...` にモジュールごとに app を持ち、`bin/packwerk check` で境界違反を静的検査する。
- 理由: 既に Packwerk 導入済み（`packwerk.yml` / `package.yml`）で追加コストがほぼゼロ。境界違反を検知できるのが MM 学習の肝。
- 不採用: 名前空間のみ（境界強制なし）、Rails Engine（第一歩には過剰）。

### モジュールの切り方 → 4モジュール

| モジュール | モデル |
|-----------|--------|
| identity | User, Admin |
| catalog | Product, ProductImage, ProductVariant, Stock |
| ordering | Cart, CartItem, Order, OrderItem |
| promotion | Coupon, CouponUse |

- 理由: 「とりあえず試す」に合うサイズ感。依存方向（catalog→ordering、promotion→catalog 等）の検討素材が一通り出て学びになる。
- 不採用: Stock を inventory に分離（今は 1:1 で分離コストに見合わず）、3モジュール（境界が少なく練習にならない）。

### ディレクトリレイアウト → pack 内で app/ 構造を踏襲

```
packs/<module>/
  package.yml
  app/
    models/<module>/xxx.rb        → Module::Xxx
    controllers/<module>/xxx_controller.rb
  spec/
```

- 理由: Packwerk 公式 / `packs-rails` の標準。Zeitwerk のオートロード規約とそのまま噛み合い、名前空間つきパスで定数名と一致する。既存 `app/` を `packs/<module>/app/` へ移すだけで移行も素直。
- 不採用: 名前空間ディレクトリ省略（Zeitwerk 規約から外れ設定増）、独自構造（Rails の恩恵を捨てる）。

### `packs-rails` gem → 入れる（`0.1.0` exact 固定）

`packs/*/app/*` を Rails の autoload/eager_load パスに自動登録する gem。pack を追加するだけで読まれる状態になる。
- 配置: autoload に関わるため dev/test グループではなく Gemfile 本体に置く。
- 理由: 手動 paths 登録が不要になり pack 追加の手数が減る。Packwerk と同じ Shopify 系で事実上の標準。
- 不採用: `config/application.rb` で手動登録（pack 追加のたびに paths を意識）。

### 公開インターフェースの置き場・命名規約 → `app/public/<module>/` に集約

```
packs/catalog/app/public/catalog/api.rb       → Catalog::Api（外部公開）
packs/catalog/app/models/catalog/product.rb   → 非公開（外から触らせない）
```

- 外部からは公開 API クラス（例 `Catalog::Api.find_product(id)`）経由でのみ呼ぶ。
- 理由: Packwerk の `enforce_privacy` が `app/public/` をデフォルトの公開境界として認識する。慣習に乗るだけで「public 配下＝外部OK / それ以外＝内部」が自動で効く。
- 不採用: AR モデルを直接公開（内部実装が漏れる）、名前空間のみで表現（結局 `app/public/` パスに揃える）。
- 保留: 返り値を AR にするか DTO にするかは「通信方式」の回で決める。

### ルーティング / コントローラの名前空間 → コントローラは pack へ、URL・名前空間は現状維持

```
packs/catalog/app/controllers/api/v1/products_controller.rb  → Api::V1::ProductsController（定数・URL 変更なし）
```

- コントローラのファイルは各 pack に移す（HTTP の入口もそのドメインの持ち物）。
- `Api::V1::X` 定数も `/api/v1/...` URL も維持（v1 残す）。フロントは壊さない。
- routes.rb はアプリ本体に集約（中央維持）。pack ごとの `draw` 分割は pack が増えてから検討。
- 理由: 「一般的な MM」の通例 = コントローラは pack へ / 公開 URL にモジュール構造を出さない / routes は中央。これに沿う。v1（API バージョニング）は MM とは無関係の別問題で、今回は残す判断。
- 不採用: URL・定数にモジュール名を出す（公開 API に内部分割を露出させる、フロントも壊れる）。

### 共通コードの置き場 → ベースクラスはルート pack、認証系は identity へ寄せる

- `ApplicationRecord` / `ApplicationController` → ルート pack（`app/` 直下のまま）。framework のベースクラスはどの pack にも属さない土台なので root に残す（packs の通例）。
- `JwtHelper`（`app/lib/`）→ 認証は identity の関心事。将来 `packs/identity` の public へ寄せる候補。移動の判断は「通信方式」の回で扱う。
- 理由: 一般的な MM でも framework 基底クラスは root package が標準。ドメイン色のあるものだけドメインへ寄せる。
- 不採用: 専用 `packs/shared` に全部入れる（基底クラスまで入れると全 pack が依存する太い結節点になり過剰）。
- メモ: `ApplicationController#authenticate_user!` が `User` / `JwtHelper` を直接参照しており、identity の関心事が共通層に染み出している。通信方式の回で扱う。

### Packwerk 強制レベル → 移行完了後に両方 true

手順:
1. pack 構造へコードを全部移す（このフェーズは違反だらけになるが触らない）。
2. 移し終えてから `enforce_dependencies: true` / `enforce_privacy: true` を入れ、`bin/packwerk check` で出た違反を潰す。

- 理由: 一括移行ブランチなので「全部移す → 強制 ON → 違反潰し」が素直。最終的に両方 true が MM の到達点。
- 不採用: 最初から true（一括移行では `package_todo.yml` 管理の旨味が薄い）、依存だけ先に true（2段階管理の手間に見合わない）。

### モジュール間通信方式 → 公開 API クラス経由（同期メソッド呼び出し）

他モジュールへの直接の AR 関連（`Product belongs_to :user` 等）をやめ、公開 API クラスのメソッド呼び出し（例 `Catalog::Api.find_product_variant(id)`）に置き換える。

- 対象の cross-module 参照: catalog→identity（Product→User）、promotion→catalog（Coupon→Product）、ordering→identity（Cart/Order→User）、ordering→catalog（CartItem/OrderItem→ProductVariant）。
- 理由: 境界がはっきり立つ。直接 AR 関連だとモジュールが密結合のままで MM の意味が薄れる。
- 不採用: AR 関連のまま残す（すぐ動くが境界が緩い）。
- 保留: 返り値を AR にするか DTO にするかは別途決める。イベント駆動は今回の対象外（非同期要件が無いため）。

### 公開 API の返り値 → DTO（PORO/Struct）

- AR をそのまま返さず、呼び出し側が必要な分だけの最小 DTO を返す。
- 理由: AR を返すと内部実装が漏れ public の意味が消える。最小 DTO が境界の意味を最も保つ。
- 不採用: AR をそのまま返す、全フィールドの汎用 DTO。

### モデル名前空間化に伴うテーブル名 → 既存テーブル名を維持

- `Catalog::Product` 等にしても `self.table_name = "products"` で既存テーブル名を維持する。
- 理由: テーブル改名（`catalog_products` 等）はマイグレーションが必要でリスク・作業量が大きく、MM の本筋と無関係。
- 不採用: テーブル名も改名。

### cross-module 関連の書き換え方 → 関連を消し id カラムは残す

- `belongs_to :user` 等の他モジュールへの直接関連を消し、`user_id` カラムは残す。
- `order.user.email` のような chain は `Identity::Api.find_user(order.user_id).email` に置き換える。
- 理由: 境界が明確になり Packwerk privacy 強制と整合する。
- 不採用: `belongs_to` を残す（境界が緩い）。

### 公開 API クラスの粒度 → モジュールごとに 1 つの `Xxx::Api`

- `Catalog::Api`, `Identity::Api` のようにモジュールごとに窓口を1つに集約する。
- 理由: 第一歩は窓口を1つにする方が呼び出し側もシンプル。肥大化したら分割する。
- 不採用: 用途別クラスに分割（今は過剰）。

### `JwtHelper` / 認証の移設 → identity の public へ

- `JwtHelper` を `packs/identity/app/public/identity/` へ移設し、`ApplicationController` は identity の公開 API を呼ぶだけにする。
- 理由: 認証は identity の関心事。共通層に残すと「共通層→User 直接参照」が消えない。
- 不採用: 共通層に残す。

### DB 分離方針 → 単一 DB、cross-module の JOIN・外部キーは当面許容

- DB は単一のまま（schema 分離はしない）。
- cross-module の JOIN・外部キーは当面許容。物理境界ではなく、Packwerk の `enforce_privacy` によるコードレベルの論理境界で守る。
- 理由: 一括移行＋学習目的では物理分離は過剰。第一歩としては論理境界を Packwerk で固めるだけで十分。
- 不採用: schema 分離（今は重い）、JOIN/外部キー全面禁止（第一歩には厳しい）。

### テスト方針 → 既存 spec を移動に追従、他モジュールの公開 API は実物を使う

- 既存の controller / model spec はそのまま維持し、コード移動に合わせて追従させる。
- pack 間をまたぐテストでは他モジュールの公開 API は実物を使う（mock しない）。単一 DB で実物が動くため。
- 理由: 振る舞いを変えない移行なので既存テストが安全網になる。実物で通る方が境界の妥当性を検証できる。
- 不採用: 他モジュールを常に mock。

### Packwerk 違反の潰し方 → 箇所ごとに公開 API を足して経由させる

- `enforce_dependencies` / `enforce_privacy` を true にした後に出る違反は、箇所ごとに公開 API を足して経由させ依存を消す方向で潰す。
- 理由: 一括移行ブランチなので `package_todo.yml` に逃がす意味が薄い。違反は正面から潰す。
- 不採用: `package_todo.yml` に大量に載せて先送り。

### フロントエンドの追従 → なし（URL を変えない）

- URL を変えない方針なのでフロント変更は不要。実装中に routes.rb の URL を変えていないことを確認するだけ。
- 理由: 案の前提「URL 維持」を実装中に破らないため。

---

## 実装手順（pack 移行）

各ステップでテストを緑に保ち、緑になったらコミット。1ステップでも壊れたら止めて報告する。
必ず1ステップずつ進める（明示の指示がある場合を除く）。

- [ ] **ステップ0: pack の枠だけ作る** — `packs/{identity,catalog,ordering,promotion}/package.yml` を作成（`enforce_dependencies: false`）。アプリ起動とテスト緑を確認。
- [x] **ステップ1: identity 移行** — `User`/`Admin` を `Identity::User`/`Identity::Admin` へ移動（`self.table_name` で既存テーブル名維持）、`JwtHelper` を `Identity::JwtHelper`（identity の public）へ、`Identity::Api`（`encode_token`/`authenticate`）新設、auth_controller を identity pack へ移動。
  - 振る舞いを変えない最小移設に留めた。他モデルの `belongs_to :user` は撤去せず `class_name: "Identity::User"` を付けて残す。`@current_user` の DTO 化 / `User.has_many` 撤去 / `belongs_to` の完全撤去はステップ5（境界締め）に回す。
  - 公開 API の返り値 DTO 化も同じくステップ5。`Identity::Api.authenticate` は当面 AR（`Identity::User`）を返す。
  - pack の spec は `packs/<module>/spec/` に置く。`.rspec` に `--pattern` を足すと個別ファイル指定が壊れる既知挙動（rspec-core #2897）のため設定はせず、フルスイートは `bundle exec rspec spec packs` で回す。
- [x] **ステップ2: catalog 移行** — `Product`/`ProductImage`/`ProductVariant`/`Stock` を `Catalog::` へ移動（`self.table_name` で既存テーブル名維持）、`Catalog::Api`（`find_product`/`find_product_variant`）新設、products/stocks コントローラを catalog pack へ移動。
  - ステップ1と同様、振る舞いを変えない最小移設。pack 外の `belongs_to :product` / `:product_variant` は撤去せず `class_name: "Catalog::*"` を付けて残す（撤去・API 経由化はステップ5）。`Identity::User has_many :products` も `class_name: "Catalog::Product"` で残す。
  - pack 外のコントローラ（cart_items / coupons / carts）は catalog の AR を直接参照しているが、ステップ2では `Catalog::` への参照置換に留め、API 経由化はステップ5に回す。
- [ ] **ステップ3: promotion 移行** — `Coupon`/`CouponUse` 移動・名前空間化、`Promotion::Api`、coupons コントローラ移動、`Coupon belongs_to :product` を外し `Catalog::Api` 経由に。
- [ ] **ステップ4: ordering 移行** — `Cart`/`CartItem`/`Order`/`OrderItem` 移動・名前空間化、`Ordering::Api`、carts/cart_items/orders コントローラ移動、`Cart/Order belongs_to :user` と `*Item → ProductVariant` を外して API 経由に。
- [ ] **ステップ5: 境界を締める** — 各 `package.yml` に `dependencies` を書き `enforce_dependencies: true` / `enforce_privacy: true`、`bin/packwerk check` で出た違反を公開 API を足して潰す。
- [ ] **ステップ6: 仕上げ** — 全 rspec + rubocop + packwerk を通す、routes の URL が変わっていない（フロント無影響）ことを確認。

## すべて決定済み。次は実装（pack 移行）。
