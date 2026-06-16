# dev-playground

モジュラーモノリスアーキテクチャの学習・実験用リポジトリ
ECサイトを作って練習しています

## 概要

マイクロサービスに分割する前段として有力な選択肢である「モジュラーモノリス」の設計パターンを、実際にコードを書きながら探求するプロジェクト。

モジュール間の境界設計、依存の管理、ドメインの分離といった概念を Rails API + Next.js の構成で実装・検証する。

## 技術スタック

| レイヤー | 技術 |
|---|---|
| Backend | Ruby on Rails 8.1.2 (API mode) |
| Frontend | Next.js (TypeScript) |
| DB | PostgreSQL |
| インフラ | Docker / Docker Compose |

## 学習・探求テーマ

- **モジュール境界の設計**: ドメインを独立したモジュールに分割し、明示的なインターフェースでのみ通信させる
- **依存の管理**: モジュール間の暗黙的な結合を排除し、将来のマイクロサービス化を容易にする構造
- **Rails でのモジュール実装**: `rails engine` や名前空間を使った実装パターンの比較
- **モノリスとマイクロサービスのトレードオフ**: 実装を通じて両者の違いを体感する

## セットアップ

### 前提条件

- Docker / Docker Compose がインストール済みであること

### 手順

1. リポジトリをクローン

```bash
git clone <repo-url>
cd dev-playground
```

2. 環境変数ファイルを作成

```bash
cp .env.example .env
# .env を環境に合わせて編集
```

3. コンテナを起動

```bash
docker compose up
```

4. DB をセットアップ

```bash
docker compose exec backend rails db:create db:migrate
```

### アクセス先

| サービス | URL |
|---|---|
| Frontend | http://localhost:3001 |
| Backend API | http://localhost:3000 |
