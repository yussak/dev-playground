# EC サイト 機能 TODO

まずは最低限のECサイトを作る。どうやってモジュラモノリスにするかの検討はそこまでできてからやる

このファイルでは全体像を書きたい

TODO:ここに書いてないけどやったこと、例えばSHA固定などもあるけどどうするか要検討

---

## Phase 1: 機能追加（標準 Rails で実装）

ユーザー周り
- [x] 会員登録・ログイン・ログアウト

商品周り
- [x] 商品CRUD

購入フロー
- [x] カートに追加・削除・数量変更
- [x] 注文確定（住所入力・決済はモック）
- [x] 注文履歴の確認

クーポン・割引 → [#36](https://github.com/yussak/dev-playground/issues/36)

## Phase 2: モジュール分離（モジュラーモノリス練習）

- [ ] 名前空間・ディレクトリでモジュール分割
- [ ] モジュール間インターフェース定義
- [ ] イベント基盤の導入
- [ ] 通知機能（イベント駆動で実装）
  - [ ] 注文確定通知
  - [ ] 在庫切れ通知（出品者向け）

## Phase 3: 追加機能（余力があれば）

- [ ] レビュー・評価
- [ ] 在庫管理

---

## CI整備

GitHub Actions で lint + test の CI を整備する。

### Backend

- [x] rubocop (lint)
- [x] rspec (test) — PostgreSQL service container が必要

コメントアウトで残す候補:
- [x] brakeman (セキュリティ静的解析)
- [x] bundler-audit (gem 脆弱性チェック)
- [x] dependabot

### Frontend

- [x] ESLint 導入 (lint)
- [x] vitest (test)
- [x] npm audit (脆弱性チェック)

コメントアウトで残す候補:
- [ ] tsc --noEmit (型チェック)

### CI改善

- [ ] セキュリティ workflow を別ファイルに分離（security.yml）+ weekly schedule 追加
- [ ] paths フィルタの per-job 化（frontend 変更で backend job が走る無駄を解消）
- [ ] push トリガー削除（デバッグ用の一時設定）
