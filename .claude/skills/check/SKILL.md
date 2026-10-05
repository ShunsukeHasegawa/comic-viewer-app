---
name: check
description: コミット前の検査（必要なら build_runner → dart format → flutter analyze → flutter test）を通す。コミットの前、または「チェックして」「テスト通して」と言われたときに使う。
argument-hint: "[テスト対象のパス（省略で全体）]"
---

# コミット前の検査

CLAUDE.md の「環境の注意」に従う。TMP / TEMP はプロジェクトの `.claude/settings.json` で
`C:\Temp\claude-dart` に設定済み（設定が効いていない環境では各コマンドの前に付ける）。

## 1. 生成コード（必要なときだけ）

`git status` / `git diff --name-only` で、次のどれかが変わっていれば build_runner を回す。

- `@riverpod` / `@Riverpod` / `@freezed` / `@JsonSerializable` を含むファイル
- drift のテーブル / `app_database.dart`

```sh
TMP='C:\Temp\claude-dart' TEMP='C:\Temp\claude-dart' dart run build_runner build
```

`--delete-conflicting-outputs` は付けない（build_runner 2.16 で廃止）。生成された
`*.g.dart` / `*.freezed.dart` もコミット対象（CI で再生成して差分が出ると落ちる）。

## 2. 整形 → 解析 → テスト

順に実行し、失敗したらそこで直してからやり直す。

1. `dart format .`
2. `flutter analyze` — 警告ゼロ（info も残さない）。
3. `flutter test $ARGUMENTS` — 引数が無ければ全体（1 分強かかる。バックグラウンドで
   実行して待つ）。作業中に対象だけ流した場合も、コミット前には全体を流す。

## 3. 報告

- 通ったかどうかを件数付きで短く報告する（例: 「analyze 0 件 / test 1024 件パス」）。
- 失敗は、出力の該当箇所を引用して原因と直し方を書く。黙って飛ばさない。
