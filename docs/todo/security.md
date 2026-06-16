# セキュリティ強化 TODO

セキュリティを堅牢にするためのやることリスト。
方針・背景は `CLAUDE.md` と `docs/security-policy.md` を参照。

## 前提

- このリポジトリは学習・練習用であり、現状はローカル（`docker compose`）でのみ動かす
- そのため「本番デプロイ前提のハードニング」は今は効かない。**実害が環境に依存せず存在するもの**を優先する
- 各項目は着手時に必要なら ADR（`docs/adr/`）で設計判断を残す

## 現状の良い点（維持する）

棚卸しの結果、以下は既に健全。崩さないよう注意する。

- サプライチェーン対策: GitHub Actions の SHA 固定、Dockerfile の image digest 固定、Dependabot（weekly / major 無視 / auto-merge）
- セキュリティ CI: `brakeman` / `bundler-audit` / `npm audit` が `security.yml` で動作
- CI 権限: `permissions: {}` + 各 job `contents: read`（最小権限）
- 認可: 各コントローラで `user_id` 突合（他人の product / order / cart を操作できない）
- SQL インジェクション: 文字列 where / `find_by_sql` なし。すべて AR の安全な API
- XSS: `dangerouslySetInnerHTML` 不使用
- パスワード: `has_secure_password`(bcrypt)。ログは `filter_parameter_logging.rb` でマスク
- シークレット: `.env` / `master.key` は `.gitignore` 済み。リポジトリにコミット履歴なし

---

## 優先度 ★★★★★

### 認証エンドポイントのレート制限（rack-attack 導入）

- [ ] `rack-attack` gem を追加（exact version 固定 / `docs/security-policy.md` 準拠）
- [ ] `POST /api/v1/auth/login` を IP + email 単位で throttle
- [ ] `POST /api/v1/auth/register` を IP 単位で throttle
- [ ] 全体の安全弁として IP 単位の上限（例: 300 req / 5 min）
- [ ] request spec で「上限超過時に 429 が返る」を検証
- 背景: 現状 `login` に総当たり防止が一切ない（`auth_controller.rb`）。環境に依存しない実アプリの穴

### Gemfile の exact version 固定（自分のポリシー違反の是正）

`docs/security-policy.md` は「Ruby gem は exact version、`^`/`~` 禁止」と定めているが、`backend/Gemfile` の多くが未固定。

- [ ] `jwt`（バージョン無指定）を exact に固定
- [ ] `rack-cors`（無指定）を exact に固定
- [ ] `bcrypt` の `~> 3.1.7` を exact に
- [ ] `rails` / `pg` / `puma` / `solid_*` / `rspec-rails` / `brakeman` / `bundler-audit` / `rubocop-rails-omakase` の制約を方針に合わせる
- [ ] `Gemfile.lock` と整合しているか確認
- 補足: `packwerk` / `sorbet` / `tapioca` は既に exact。横並びにする

---

## 優先度 ★★★★

### 未使用の危険なデッドコード削除

- [ ] `frontend/lib/auth.ts`（非 HttpOnly・非 Secure クッキーへトークン直書き）を削除
- [ ] 併せて `frontend/lib/__tests__/auth.test.ts` を削除
- 背景: 実フローは NextAuth セッション + SSR `apiFetch` で、この helper はテスト以外から未 import。残すと将来うっかり使われる footgun。Tidy First 的に除去

### JWT の失効設計

- [ ] 有効期限の短縮を検討（現状 24h / `app/lib/jwt_helper.rb`）
- [ ] `logout` でのトークン無効化（jti denylist など）を検討
- [ ] 設計判断は ADR に残す（ADR-006「認証切れ時のハンドリング」と整合させる）
- 背景: `logout` はサーバー側で何もせず、漏洩トークンを取り消せない。refresh token 設計（ADR-006 案C）との接続も視野

---

## 優先度 ★★★

### AuthController の strong parameters / 入力整理

- [ ] `params[:name]` / `params[:email]` / `params[:password]` の直接参照を `permit` 化
- [ ] register / login のバリデーション・エラー応答を整理
- 背景: `has_secure_password` でパスワードは保護されており実害は小さいが、他コントローラとの一貫性・規約として

### セキュリティ系 CI の底上げ

- [ ] `bundler-audit` の ignore リストにプレースホルダ（`CVE-THAT-DOES-NOT-APPLY` 等）が残っていないか確認
- [ ] `eslint-plugin-security` 等のフロント静的解析の追加を検討
- [ ] ログに PII（メール等）が出ていないか `filter_parameter_logging` の網羅性を確認

---

## 優先度 ★★（本番デプロイを始める段階でまとめて）

ローカル運用では効かないが、デプロイ時に必須になるハードニング。

- [ ] `config.force_ssl = true`（`config/environments/production.rb` でコメントアウト中）
- [ ] `config.hosts` 許可リスト設定（DNS rebinding 対策、production.rb でコメントアウト中）
- [ ] CORS オリジンの env 化（`cors.rb` が `http://localhost:3001` 固定）
- [ ] Docker 非 root 実行（backend / frontend どちらも現状 root）
- [ ] frontend の本番起動（`npm run dev` → `build` + `start`）
- [ ] `compose.yaml` の `ports` 公開を本番では絞る（特に DB 5432）
- [ ] セキュリティヘッダ（CSP / X-Frame-Options / X-Content-Type-Options）
- [ ] `.env.example` の弱いデフォルト（`password` 等）に本番要注意の注記

---

## 権限管理（Authorization）— 設計から検討したいテーマ

### 現状

- 認可は各コントローラに散在した所有者チェック（例: `product.user_id == @current_user.id` で 403）
- ロールの概念がない。`User` は出品者と購入者を兼ねている（`has_many :products` と `has_one :cart` を両方持つ）
- `app/models/admin.rb` が `has_secure_password` 付きで存在するが、**ルート・コントローラ・認証フローが無く未使用**（中途半端な状態）
- Pundit / CanCanCan などの認可 gem は未導入

### 課題

- 認可ロジックが散らばっており、抜け漏れ（認可漏れ）に気づきにくい
- 「出品者 / 購入者 / 管理者」の役割が型として表現されていない
- モジュラーモノリス化（Phase 2）の際、認可はモジュール境界をまたぐ横断的関心事になる

### 検討する案（推奨度付き）

#### 案A: Pundit で Policy オブジェクトに集約 ★★★★★

リソースごとに `XxxPolicy` を作り、`authorize @product` で判定。散在した所有者チェックを policy に寄せる。

- メリット: 認可ロジックが 1 か所に集まり、テストしやすい（policy spec）。Rails で実績豊富。モジュール分割時も policy をモジュール側に持てる
- デメリット: gem 追加と既存コントローラのリファクタが要る
- 推奨理由: 学習題材として「認可の集約」を体験でき、現状の散在を解消する本命

#### 案B: ロール列の導入（`users.role` enum）★★★★

`User` に `role`（`buyer` / `seller` / `admin`）を持たせ、`Admin` モデルを統合 or 役割で分岐。

- メリット: 役割が型として明示される。RBAC の基礎を学べる
- デメリット: 単独だと「誰が何をできるか」の判定は別途必要（案A と併用が自然）
- 推奨理由: 案A と組み合わせる前提なら強い。先に役割モデルを決めると policy が書きやすい

#### 案C: CanCanCan で能力を一元定義 ★★★

`Ability` クラスに `can :update, Product, user_id: user.id` のように集約。

- メリット: 能力定義が 1 ファイル。宣言的
- デメリット: 大きくなると `Ability` が肥大化。モジュール分割と相性がやや悪い
- 推奨理由: 小規模なら手軽だが、モジュラーモノリス志向なら案A の方が境界を保ちやすい

#### 案D: 現状維持＋共通ヘルパー抽出 ★★

`authorize_owner!(record)` のような共通メソッドを `ApplicationController` に置くだけ。

- メリット: 最小変更
- デメリット: 役割や複雑な認可には拡張しづらい
- 推奨理由: つなぎとしては可。ただし「権限管理をやってみたい」目的には物足りない

### 進め方（推奨ルート）

1. [ ] 役割の整理（案B）: `buyer` / `seller` / `admin` をどう表現するか決め、ADR に残す
2. [ ] `Admin` モデルの扱いを決定（`User.role` に統合するか、管理境界として残すか）
3. [ ] Pundit 導入（案A）し、まず `Product` の所有者チェックを policy に移設
4. [ ] policy spec で振る舞いをテスト（CLAUDE.md: 認可は controller テスト必須）
5. [ ] 残りのリソース（coupon / stock / order / cart）へ横展開
6. [ ] 管理者向け操作が必要になったら admin 認証フローを設計

---

## やらないこと（現時点のスコープ外）

- 多要素認証（MFA）
- 監査ログ / SIEM 連携
- WAF・外部 IDS
- 本番インフラ前提のシークレット管理（Vault / Docker secrets 本格運用）
