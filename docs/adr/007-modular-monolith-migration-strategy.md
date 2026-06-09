# ADR-007: モジュラモノリス移行戦略

## ステータス

提案中

## コンテキスト

現在のコードベースは標準的な Rails モノリスで、12モデル・7コントローラ・1ユーティリティから構成される EC ドメインのアプリケーションである。

機能的には動作しているが、以下の課題が見え始めている:

- `OrdersController` が Cart, Order, Stock, Coupon, CouponUse を横断的に操作しており、ドメイン間の結合が暗黙的
- モデル間の依存方向が明示されておらず、変更時の影響範囲が把握しにくい
- 機能追加に伴い、この傾向は加速する

packwerk は既に Gemfile に含まれているが、未設定の状態。[mm-procedure.md](../mm-procedure.md) でアプローチ B（全パック荒く切り出し → 違反解消）を推奨方針として定めている。

今回は「最初の一歩」として、厳しすぎない設定でパック分けを行い、依存関係を可視化することを目的とする。

## 決定

### 1. パック構成: 6パック

ドメインの自然な境界に沿って以下の6パックに分割する。モデルとコントローラをセットで移動する。

| パック | モデル | コントローラ | その他 |
|--------|--------|-------------|--------|
| `packs/identity` | User, Admin | AuthController | JwtHelper |
| `packs/catalog` | Product, ProductVariant, ProductImage | ProductsController | |
| `packs/inventory` | Stock | StocksController | |
| `packs/cart` | Cart, CartItem | CartsController, CartItemsController | |
| `packs/ordering` | Order, OrderItem | OrdersController | |
| `packs/promotion` | Coupon, CouponUse | CouponsController | |

共有基盤（ApplicationController, ApplicationRecord, HealthController）はルートパッケージに残す。

### 2. 施行レベル: 依存のみ、プライバシーは後

```yaml
# 各パックの package.yml
enforce_dependencies: true
enforce_privacy: false
```

- `enforce_dependencies: true`: パック間の依存方向を明示化・検査する。これが MM の核心的な価値
- `enforce_privacy: false`: 公開 API の設計は後のフェーズで行う。まずは境界を引くことに集中する

### 3. 既存違反の扱い: package_todo.yml で許容

`packwerk update` で既存の違反を `package_todo.yml` に書き出す。新規違反のみ検出される状態にする。rubocop_todo.yml と同じ「既存は許容、新規は防止」の考え方。

### 4. 切り出し順序: 依存が少ないパックから

1. **Identity** — 依存先なし。他の全パックから参照される基盤
2. **Catalog** — Identity のみに依存
3. **Inventory** — Catalog のみに依存
4. **Promotion** — Catalog, Identity に依存
5. **Cart** — Identity, Catalog, Inventory に依存
6. **Ordering** — 全パックに依存（最も結合が多い）

依存が少ないものから切り出すことで、各ステップでの変更量と複雑さを最小化する。

### 5. 依存方向の目標

```
identity ← catalog ← inventory
    ↑          ↑
    |          |
   cart    promotion
    ↑          ↑
    └── ordering ──┘
```

上流（identity, catalog）は下流（ordering, cart）を知らない。下流が上流に依存する一方向の関係を目指す。

## 理由

### 6パックを選んだ理由

| 案 | 構成 | 評価 |
|----|------|------|
| A. 3パック（粗い） | product_management, identity, commerce | ★★ パック内の結合が大きく、分割の意味が薄い |
| **B. 6パック（推奨）** | identity, catalog, inventory, cart, ordering, promotion | **★★★★★** ドメインの自然な境界に一致。EC の標準的なコンテキスト分割 |
| C. さらに細かく | B + notifications, payments 等 | ★★ 現時点では対象機能がない。YAGNI |

B を選択。理由:

- EC ドメインでは Catalog / Inventory / Cart / Order / Promotion は広く認知された境界（Shopify, Spree 等）
- 各パックが 2-3 モデルと 1-2 コントローラで収まり、管理しやすい
- Stock を Catalog から分離することで、在庫管理の独立した進化を可能にする（将来的にイベント駆動での在庫同期など）

### enforce_privacy: false にした理由

- 公開 API を設計するには、まず依存関係の全体像が必要。全パック切り出し後に判断した方が良い
- 最初の一歩で制約を増やしすぎると、移行の摩擦が大きくなる
- privacy は後から true にできる（逆はしない）

### コントローラをパックに含める理由

- パックを自己完結させることで、「このドメインのコードはどこにあるか」が明確になる
- コントローラがルートに残ると、依存関係の追跡が不完全になる
- packwerk はファイルの物理配置でパッケージを判定するため、コントローラも移動しないと検査対象にならない

## 影響

- テストファイルの配置: `spec/` はルートに残し、パック内には移動しない（最初の一歩では変更を最小限に）
- autoload paths の設定が必要（`config/application.rb` に `packs/*/app/**` を追加）
- CI に `packwerk check` を追加することで、新規違反を防止できる（推奨だが必須ではない）
- 全パック切り出し後、`package_todo.yml` の違反件数が改善の進捗指標になる
- `enforce_privacy: true` への移行は、全パック切り出し完了後に別 ADR で判断する
