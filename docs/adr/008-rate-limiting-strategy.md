# ADR-008: 認証エンドポイントのレート制限戦略

## ステータス

提案中

## コンテキスト

`POST /api/v1/auth/login` と `POST /api/v1/auth/register` にレート制限が一切なく、
パスワード総当たり（ブルートフォース）や登録の大量試行を防げない（`app/controllers/api/v1/auth_controller.rb`）。
これはデプロイ環境に依存せず存在するアプリ層の穴であり、`docs/todo/security.md` で最優先（★★★★★）に挙げている。

導入にあたり、以下の制約が調査で判明した。

- リクエストはフロント・テストとも JSON ボディ（`Content-Type: application/json`）で送られる。
  Rack::Attack の `req.params` は URL クエリ／フォームボディしか解析せず **JSON ボディを読めない**ため、
  `email` をキーにした絞り込みはボディの手動 `JSON.parse` が必要で、実装が複雑になる。
- テスト環境の `cache_store` は `:null_store`（`config/environments/test.rb`）で、
  このままでは throttle のカウンタが保持されずレート制限をテストできない。
- 本番は `solid_cache`（DB バックエンド）が利用可能で、worker 間でカウンタを共有できる。

## 決定

レート制限ライブラリとして **rack-attack** を導入する。設計は以下とする。

1. **絞りキーは IP 単位のみ**とする。
   - `login/ip`: `POST /api/v1/auth/login` を IP ごとに throttle
   - `register/ip`: `POST /api/v1/auth/register` を IP ごとに throttle
   - `email` 単位の絞り込みは、JSON ボディ解析が必要になるため**今回は採用しない**（将来の拡張余地として残す）。
2. **カウンタは標準の `Rails.cache` を使う**。
   - 本番: `solid_cache`（worker 間共有・永続）
   - 開発: `:memory_store`（既存設定）
   - テスト: `:null_store` → `:memory_store` へ変更し、各テスト前にキャッシュをクリアする。
3. **超過時は 429（Too Many Requests）を JSON で返す**（他 API と整合）。
4. 上限値の初期値は **5 回 / 60 秒**（login・register とも）。学習用の保守的な値とし、運用しながら調整する。

## 理由

- **IP 単位のみ**: JSON ボディに依存せず確実に動き、実装がシンプル。ブルートフォースの大半は
  同一 IP からの連続試行であり、まず最大の効果が得られる。email 単位は「分散 IP からの特定アカウント狙い」に
  有効だが、JSON ボディ解析という複雑さに見合うのは需要が出てからでよい（YAGNI / まず最低限動く実装の方針）。
- **`Rails.cache` 採用**: Rails 標準の経路に乗り、本番では `solid_cache` で worker 間共有という正しい形になる。
  専用 `MemoryStore` を initializer で固定する案は自己完結するが、本番で worker ごとにカウンタが分かれてしまう。
- **テストの `cache_store` 変更**: rack-attack のカウンタを動かすために必要。`null_store` → `memory_store` の影響は
  各テスト前のクリアで隔離する。
- rack-attack は railtie が自動でミドルウェアに挿入するため、手動の `insert_before` は不要（initializer で設定のみ）。

### 検討した代替案

- **案: email 単位も併用** — 分散 IP からの単一アカウント攻撃に強いが、JSON ボディの手動解析が必要で
  壊れやすい。効果と複雑さのバランスから今回は見送り、ADR に追記する形で将来導入する。
- **案: 専用 MemoryStore を initializer で固定** — `test.rb` を触らず自己完結するが、
  本番で worker 間のカウンタ共有ができない。本番の正しさを優先して不採用。
- **案: Rails 8 標準の `rate_limit`（コントローラ DSL）** — gem 追加が不要だが、
  `docs/todo/security.md` で rack-attack を選定済み。ミドルウェア層で一元管理でき拡張余地も広いため rack-attack を採る。

## 影響

- `backend/Gemfile` に `rack-attack` を exact version で追加（`docs/security-policy.md` 準拠）。
- `config/initializers/rack_attack.rb` を新設（throttle 定義・429 レスポンダ）。
- `config/environments/test.rb` の `cache_store` を `:memory_store` に変更。
- `spec/rails_helper.rb` に各テスト前のキャッシュクリアを追加。
- 通常利用で 429 に当たらない上限とするが、UX に影響が出たら上限値を見直す。
- email 単位の絞り込みが必要になった場合は、本 ADR を更新する新しい ADR を作成する。
