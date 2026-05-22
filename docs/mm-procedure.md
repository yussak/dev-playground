# モジュラモノリス移行の進め方

mm/xxx ブランチで MM 移行を試す際の作業手順。

ブランチの運用ルールは [mm-branch-workflow.md](./mm-branch-workflow.md) を参照。

## 手順

1. パックを1つ切り出す
   - `packs/<name>/` ディレクトリに対象ファイルを移動
   - `packs/<name>/package.yml` を作成
   - Rails の autoload paths に追加
2. `packwerk check` を実行して違反を確認
3. 違反を解消する
4. テストが緑であることを確認
5. コミット
6. ブランチ内ドキュメントに所感を書く（採用した分け方、判断、迷い）
7. 次のパックへ戻る（1 に戻る）


## メモ　スタンダードな進め方

packwerk を使った MM 移行の一般的な段階導入手順。「荒く MM 化してから徐々に改善する」流れ。

1. パックを作る（対象ファイルを `packs/<name>/` に物理移動）
2. `packs/<name>/package.yml` で `enforce_dependencies: true` / `enforce_privacy: true` を有効にする
3. `packwerk update`（または `packwerk update-deprecations`）を実行し、今ある違反を `package_todo.yml` に既知の違反として書き出す
   - これで現状の違反は許容され、`packwerk check` は緑になる
   - 以降、新規違反だけが検出される（=今後新しい違反は増やせない）
4. テスト緑を確認してコミット → 「荒く MM 化」が完了した状態
5. 以降、`package_todo.yml` に並んだ既知違反を1件ずつコードで解消していく
   - 依存方向を整理する / public API を整える / 依存先を別パックに切り出す など
6. 解消するたびに `packwerk update` で `package_todo.yml` を更新
7. すべて解消し終えると `package_todo.yml` が空になり、純粋に enforce ルールだけで境界が守られる状態になる

ポイント:
- 最初から違反0を狙うとスコープが膨らむので、まず todo に退避するのが標準
- 「新規違反は防ぐ、既存違反は段階的に消す」の二段構え
