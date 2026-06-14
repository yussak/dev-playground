# ADR-009: enforce_privacy を採用しない

## ステータス

採用

## コンテキスト

`docs/mm-first-try.md` の「Packwerk 強制レベル」決定では、移行完了後に `enforce_dependencies: true` / `enforce_privacy: true` の両方を有効化するとしていた。しかしステップ5の実装時に、Packwerk 3.0 で `enforce_privacy` が core から削除されている事実が判明した（[Packwerk 3.0 リリースノート](https://github.com/Shopify/packwerk/releases/tag/v3.0.0)）。

- `package.yml` に `enforce_privacy: true` を書いても無視される
- Privacy 強制が欲しい場合は別 gem [`packwerk-extensions`](https://github.com/rubyatscale/packwerk-extensions) の導入が必要
- 当初決定（両方 true）は Packwerk 2.x の挙動を前提にしており、その前提が崩れた

このため、本ブランチの「ステップ5: 境界を締める」のスコープにおいて privacy 強制をどう扱うかを判断する必要がある。

`enforce_dependencies` の有効化（pack 間の依存方向の強制）は MM 学習の中心であり、これを採用しない選択肢はない。論点は `enforce_privacy` のみ。

## 検討した案

### 案A: `enforce_privacy` を採用しない（`packwerk-extensions` も導入しない）

- `package.yml` から `enforce_privacy` 行を削除。`packwerk-extensions` も導入しない
- `app/public/<module>/` 配置の慣習はそのまま維持する（将来 extensions を入れる余地を残す）
- メリット: 「最初の一歩」のスコープに収まる。導入コスト・追加 gem ゼロ。dependencies の強制だけで pack 間境界の旨味は実感できる
- デメリット: 「`app/public/` の外を pack 外から触れない」というコードレベルの強制が無く、規律で守る形になる

### 案B: `packwerk-extensions` を導入して privacy 強制を維持

- gem 追加、`packwerk.yml` で privacy checker を有効化、各 pack の `enforce_privacy: true` を実態として有効化する
- メリット: 当初決定（両方 true）を実態として維持できる。`app/public/` の外を pack 外から触ると違反になる
- デメリット: 「最初の一歩」のスコープに extension の学習・運用が乗る。MM 移行そのものから注意がそれる

### 案C: `enforce_privacy: true` を `package.yml` に残す（無視されるのを了承）

- メリット: 当初の意図表明は残せる
- デメリット: 設定が嘘になり、後で読んだ人が「効いている」と誤読する可能性が高い

## 提案

案Aを提案する。

## 提案理由

- 本ブランチの目的は「モジュラモノリス移行の最初の一歩を試す」こと。dependencies の強制で境界の旨味は十分体感できる
- `app/public/<module>/` 配置の慣習は既に各 pack で踏襲済みなので、後日 `packwerk-extensions` を試す選択肢は残せる
- 案B（extensions 導入）は「最初の一歩」の次の段階として別途試す方が、学習対象が明確になる

## 影響（提案採用時）

- 各 pack の `package.yml` から `enforce_privacy: true` を削除する
- `docs/mm-first-try.md` の「Packwerk 強制レベル」の決定を「dependencies のみ強制」に改訂し、Packwerk 3.x で privacy が削除された経緯を追記する
- 公開 API の置き場（`app/public/<module>/`）の慣習はそのまま維持する
- 将来 privacy 強制が必要になったら `packwerk-extensions` の導入を別途検討する
