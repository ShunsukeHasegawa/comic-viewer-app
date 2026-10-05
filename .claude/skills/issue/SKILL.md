---
name: issue
description: GitHub Issue を 1 件、CLAUDE.md の「Issue の進め方」に沿って実装する（要件確認 → ブランチ → 実装とテスト → 検査 → コミット）。
argument-hint: <Issue 番号>
disable-model-invocation: true
---

# Issue #$ARGUMENTS を実装する

CLAUDE.md の「Issue の進め方」と「実装の約束」に従う。順番を飛ばさない。

## 1. 要件を読む

- `gh issue view $ARGUMENTS --comments` で本文とコメントを読む。
- Epic（#1）との関係、依存する Issue を確認する。依存先が未実装なら
  「導線だけ用意して無効化」し、担当 Issue 番号をコメントに残す方針にする。
- 要件があいまいで、判断がユーザーにしかできない点があれば、実装前に聞く。

## 2. サーバー API を確かめる（API を使う場合だけ）

- CLAUDE.md の「サーバー API（comic-viewer）で確認済みの事実」に無い形は推測で書かない。
- `server-api-checker` エージェントに、使うエンドポイントのコントローラ / リソースの形を
  調べさせる（`gh api repos/ShunsukeHasegawa/comic-viewer/contents/<path>`）。

## 3. ブランチを切る

- `master` が最新か確かめてから `feature/issue-$ARGUMENTS-<英小文字の slug>` を作る。
- 作業ツリーに関係ない変更が残っていれば、混ぜずにユーザーに確認する。

## 4. 実装する（テストも同時に）

- 既存の近いコードの書き方に合わせる。`test/` は `lib/` と同じ構成で、
  フェイクは `test/support/`、コンテナは `testOverrides` / `createContainer`。
- テスト名・コメントは日本語で「なぜ」を書く。
- 端末内にユーザー固有データを持つなら `SessionDataPurger` の登録、新しい置き場なら
  `StorageProtector` への追加など、CLAUDE.md の「実装の約束」を一つずつ当てはめる。
- freezed / riverpod_generator / drift を触ったら `/check` が build_runner を回す。

## 5. 決まりの確認と検査

- `conventions-reviewer` エージェントに差分を見せ、CLAUDE.md の決まりへの違反を確認して直す。
- `/check` を実行し、format / analyze（警告ゼロ）/ test（全パス）を通す。

## 6. コミット

- 日本語のコミットメッセージ。1 行目は `feat:` / `fix:` などの接頭辞 + 何をしたか。
  本文に「なぜそう決めたか」を書き、最後に `Closes #$ARGUMENTS`。
- 実装中に決めた、コードから読み取れない方針は CLAUDE.md の該当の節に追記する。
- push / PR はユーザーに頼まれたときだけ。

最後に、何を実装したか・決めたこと・実機で確かめてほしい点をユーザーに報告する。
