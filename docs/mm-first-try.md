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

---

## 未決（決める順）

依存の浅いものから1つずつ。

1. 公開インターフェースの置き場・命名規約
2. ルーティングの分割方式 / コントローラの名前空間ルール
3. 共通コード（concerns, ApplicationRecord 等）の置き場
4. Packwerk の `enforce_dependencies` / `enforce_privacy` をいつ true にするか
5. モジュール間通信方式（同期メソッド呼び出し / イベント駆動 / 併用）
6. DB 分離方針（単一 DB / schema 分離 / JOIN 可否 / 外部キー可否）
7. テスト方針（モジュール単体 / 統合の切り分け、mock 方針）
