# BFF 導入 TODO

決定: `docs/adr/007-bff-introduction.md`（案①: Next.js 内 BFF）
PR: #134

方針: 別プロセスは建てず Next.js 内に BFF を置く。
`lib/bff/*` を本体（サーバー専用関数）、`app/api/*` はブラウザ窓口だけにする。
段階移行で、単純な画面で規約を固めてから横断集約に進む。

## スライス 0: 置き場所と規約

- [ ] `frontend/lib/bff/` ディレクトリを作る
- [ ] BFF 関数の戻り値型・`cache` 指定・エラーの返し方の雛形を決める
- [ ] page に手書きしている型（`Product` など）を `lib/bff` 側へ移して共有する方針を決める

## スライス 1: products でパイロット（規約確立）

横断集約のない単純取得で、移行の作法を低リスクで固める。

- [ ] `lib/bff/products.ts` に `getProducts()` を作る（中身は `apiFetch` 温存）
- [ ] `products/page.tsx` の `apiFetch` 直叩きを `getProducts()` 呼び出しに置換
- [ ] 振る舞いテストを追加（Rails をモックし結果の形を検証）

## スライス 2: カート画面で横断集約（本命）

cart + product + stock + coupon の集約。BFF の旨味を確認する。

- [ ] `lib/bff/cart.ts` に集約関数を作る
- [ ] カート画面を BFF 経由に置換
- [ ] 集約を BFF / Rails Query どちらに寄せるか実地で判断（ADR 未決事項）
- [ ] 振る舞いテストを追加

## スライス 3: 残りの移行と窓口の薄殻化

- [ ] 他の取得系（orders など）を `lib/bff` 化
- [ ] `app/api/orders/route.ts` の集約を `lib/bff/orders` へ移し、Handler は「受けて委譲して revalidatePath」だけにする
- [ ] `lib/api.ts` の `apiFetch` を画面から直接呼ばない状態にする

## やらないこと

- 別プロセス化（Hono / Express）— ローカル専用のため見送り（ADR-007）
- ドメインロジックの BFF 移設 — 割引計算・在庫引当などは Rails に残す
