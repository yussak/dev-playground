## 基本方針

- Kent Beck（Tidy First）・Martin Fowler（Refactoring）の方針に従う
- 複数案を提示する際には推奨度（Max星５つ）とその理由も添える
- 変更前に必ず対象ファイルを読んでから編集すること
- 求められていない機能追加・リファクタリング・コメント追加は行わない
- セキュリティ上の問題（SQLインジェクション、XSSなど）があればすぐに指摘・修正する
- 現在のブランチとは別のブランチで作業するときは `git checkout` で切り替えず `git worktree add` を使う

## コーディング規約

- Ruby: `rubocop-rails-omakase` に従う（`.rubocop.yml` 参照）


## セキュリティ

依存パッケージの追加・更新、GitHub Actions・Dockerfile の変更時に参照する。

@docs/security-policy.md


## テスト

- テストは安全網であり仕様書でもある
- 振る舞いをテストする。実装の詳細はテストしない
- controller・modelのテストは必須
- RSpec: willnet/rspec-style-guide に従う
- Kent Beck（TDD）・t_wada のテスト哲学に従う