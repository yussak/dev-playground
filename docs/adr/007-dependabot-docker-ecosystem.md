# ADR-007: Dependabot に docker エコシステムを追加する

## ステータス

採用

## コンテキスト

ADR-005（GitHub Actions の SHA Pinning）と同じ趣旨で、PR #68（issue #45）にて Docker イメージを SHA256 digest で固定した。digest 固定はタグ書き換え攻撃を防ぐ反面、手動で更新しない限り永久に古い digest を使い続けることになり、ベースイメージの脆弱性が積み上がるリスクを生む。

現状の digest 固定箇所:

| ファイル | 対象 image |
|---|---|
| `docker-compose.yml` | `postgres:18@sha256:52e6...` |
| `backend/Dockerfile` | `ruby:3.4-slim@sha256:2a5b...` |
| `frontend/Dockerfile` | `node:22-alpine@sha256:8ea2...` |
| `.github/workflows/ci.yml` | `postgres:18@sha256:52e6...`（compose と重複） |

`.github/dependabot.yml` には bundler / npm / github-actions の3エコシステムが定義済みだが、docker エコシステムは未設定で、Dockerfile / compose の digest が更新されない。

加えて、`ci.yml` の `services.postgres.image` は **Dependabot の docker エコシステムでは検出対象外**である（docker エコシステムは Dockerfile と compose ファイルのみを解析する）。同じ postgres digest が `docker-compose.yml` と `ci.yml` で二重管理されており、片方だけ更新されると齟齬が生じる構造的問題がある。

## 検討した案

### 案A: dependabot.yml に docker エコシステムを追加するのみ

`.github/dependabot.yml` に以下を追記する:

```yaml
- package-ecosystem: "docker"
  directories:
    - "/"          # docker-compose.yml
    - "/backend"   # ruby
    - "/frontend"  # node
  schedule:
    interval: "weekly"
```

- メリット: 最小変更で issue #69 のスコープを満たす。Dockerfile / compose の3 image が自動更新される
- デメリット: `ci.yml` の postgres digest は更新対象外のまま。Dependabot が compose を更新したら手動で ci.yml にコピペが必要

### 案B: ci.yml の services を廃止し、CI でも compose を信頼の源にする

案A に加え、`ci.yml` の `services.postgres` ブロックを削除し、step で `docker compose up -d db` する形に書き換える。

- メリット: postgres digest が `docker-compose.yml` 一箇所に集約され、Dependabot の更新が CI にも自動反映される。digest 二重管理が消える
- デメリット: CI の構造変更が必要（services 定義廃止、port 経由のアクセス、ヘルスチェック待ちステップの追加）。issue #69 のスコープを超える

なお、env var 化（例: `POSTGRES_IMAGE=postgres:18@sha256:...` を定義して参照する）は Dependabot が env var を更新できないため**不可**。compose ファイルを実際に CI で利用する形にしないと意味がない。

### 案C: 案A + Dependabot のグルーピング

案A の docker エントリに `groups:` を追加し、3 image の更新を1 PR にまとめる。

- メリット: PR ノイズが減る
- デメリット: 同時更新で CI 失敗時の切り分けが面倒。image は3つしかないので現時点では恩恵が小さい

### 案D: 案A + 案B + 案C を一括で実施

理想形だが issue 1本のスコープとして大きい。

## 決定

**案A を採用する。**

`ci.yml` の二重管理問題（案B 相当）は別 issue として切り出して対応する。グルーピング（案C）は PR ノイズが実問題化してから判断する。

## 採用理由

- issue #69 の文言（「dependabot.yml に docker エコシステムを追加」）に対するスコープを守れる
- Dockerfile / compose の更新自動化という主要価値を即座に得られる
- 案B は CI の構造変更を伴うため、独立した検討・レビューに値する変更（別 ADR / 別 issue が適切）
- グループ化は image が3つしかなく、現状で必要性が低い。後から追加可能で可逆

## 影響

- 週1回、Dockerfile / compose の3 image に対して個別に Dependabot PR が作成される
- `.github/workflows/ci.yml` の `services.postgres.image` は引き続き手動更新対象。Dependabot が compose を更新した際、同じ digest を ci.yml にも反映する運用が必要
- 上記の二重管理を解消するため、issue #79 で案B 相当（ci.yml の services 廃止 + compose 利用）を継続検討する
- ADR-003 の自動マージ運用により、major 以外の docker image 更新は自動マージ対象となる
