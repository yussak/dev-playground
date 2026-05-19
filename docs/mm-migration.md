# モジュラーモノリス移行メモ

## 運用方針（現状）

### ブランチ
- `main` = モノリスとして維持。機能開発はここで続ける
- `mm/<試したい切り方>` = main から派生させて MM 移行を試すブランチ
- 同じ作業を複数ブランチで繰り返すのは OK（比較のため）
- マージするかは状況に応じて判断（気に入ったパターンは main にマージしてもよい）

### ツール
- packwerk を採用（Shopify製、Rails MM のデファクト）
- 他の選択肢（Rails Engines / 規約のみ）は事例少なく比較価値薄いため見送り

### Dependabot
- MM 作業とは独立して通常運用（patch/minor は CI green でマージ）
- backend bundler の major のみレビュー
- MM ブランチ作業中も main の Dependabot PR は気にせずマージしてよい

## 境界の切り方パターン（試したら追記）

- [ ] Bounded Context 単位（Catalog / Sales / Promotion / IAM）
- [ ] アクター単位（Seller / Buyer / Identity / Operations）
- [ ] Evolving Boundaries（粗く切って後追い調整）

## 移行を進めて分かったこと

（experiment ごとに追記）
