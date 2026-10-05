---
name: release
description: Android APK のリリース（pubspec の版上げ → タグ → CI の release-android → 署名の確認）を README の手順どおりに進める。
argument-hint: <版。例 1.2.3>
disable-model-invocation: true
---

# v$ARGUMENTS のリリース（#16）

README の「リリース」と CLAUDE.md の「リリース」の節が正。**push とタグの push は外に出る操作
なので、それぞれ実行の直前にユーザーに確認する。**

## 1. 前提を確かめる

- 版の形が `x.y.z`（または `x.y.z-rc.N`）か。`git tag -l` で同じタグが無いか。
- 直前の版（`git describe --tags --abbrev=0`）からの変更（`git log <前のタグ>..HEAD --oneline`）を見て、
  版の上げ方が README の決まり（互換を切る → x / 機能追加 → y / 修正だけ → z）に合っているか。
  合っていなければユーザーに伝える。
- `master` にいて、作業ツリーが空で、`origin/master` と揃っているか。
- master の最新コミットの CI が通っているか（`gh run list --branch master --limit 3`）。

## 2. 版を上げる

- `pubspec.yaml` の `version:` の `x.y.z` を `$ARGUMENTS`（`-rc.N` は付けない）にする。
  `+build` は手元用なので触らない。
- `/check` を通し、`chore: v$ARGUMENTS` でコミットする。
- **確認してから** `git push origin master`。CI が通るのを待つ（`gh run watch`）。

## 3. タグを打つ

- **確認してから** `git tag v$ARGUMENTS && git push origin v$ARGUMENTS`。
- `gh run list --workflow ci.yml --limit 3` で `release-android` を含む実行を見つけ、
  `gh run watch <id>` で終わるまで待つ。失敗したらログ（`gh run view <id> --log-failed`）を読んで報告する。

## 4. 成果物と署名を確かめる

- GitHub Release `v$ARGUMENTS` が**下書き**で作られ、
  `comic-laz-<版>-build.<run_number>.apk` が添付されているか（`gh release view v$ARGUMENTS`）。
  下書きを公開するのはユーザー（こちらで公開しない）。
- job の Summary の**署名証明書の SHA-256** を前回のリリースと比べる
  （`gh run view <id>` / 前回の実行の Summary）。違えば上書きインストールできないので強く警告する。

## 5. 報告

版・versionCode（run_number）・APK 名・SHA-256 が前回と同じかを報告し、
端末への入れ方（README の「端末へのインストール」）を案内する。

## してはいけないこと

- keystore / パスワードを作る、Secrets を書き換える、`ci.yml` の名前を変える、
  `applicationId` を変える、R8 / リソース縮小を有効にする（CLAUDE.md の「リリース」）。
