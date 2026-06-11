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

---

## 未決（決める順）

依存の浅いものから1つずつ。

1. モジュール間通信方式（同期メソッド呼び出し / イベント駆動 / 併用）
2. DB 分離方針（単一 DB / schema 分離 / JOIN 可否 / 外部キー可否）
3. テスト方針（モジュール単体 / 統合の切り分け、mock 方針）
