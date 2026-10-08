# コードレビュー結果（2026-10-07）

## 対象と確認方法

- 対象: `lib/` を中心とした Flutter/Dart 実装、および Android/iOS の設定
- 観点: 正確性、ユーザーデータ分離、省メモリ、高速化、保守性
- `flutter analyze`: 問題なし
- `flutter test --reporter compact`: 1,145 件すべて成功

静的解析とテストは良好で、画像処理の isolate 化、ディスクキャッシュの上限管理、進捗 DB 書き込みの間引きなど、性能を意識した実装も多く確認できた。一方、非同期処理とセッション境界に、実データが次のセッションへ残り得る問題がある。

## 修正を推奨する不具合

### [P1] ログアウト後に進行中の画像取得がメモリキャッシュを再生成する

対象: `lib/core/cache/comic_image_loader.dart:181-194`, `lib/core/cache/comic_image_loader.dart:303-316`

ネットワーク取得開始時の `generation` はディスクへの書き戻しだけを抑止している。ログアウト時に `ImageCachePurger` がディスクと Flutter の `ImageCache` を消した後でも、先に開始していた `_download()` は取得済みバイト列を返し、`ComicImageProvider._decode()` がデコード結果をグローバルな `ImageCache` に登録できる。ローカル ZIP やディスクキャッシュの読み出しも同様である。次のユーザーが同じキャッシュキーを要求すると、前セッションの表紙・ページがメモリから表示される可能性がある。画像取得全体にセッション世代を適用し、世代が変わった結果はデコード前に失敗させる、または進行中処理の完了後にもメモリキャッシュを追い出す必要がある。これは `CLAUDE.md:61-62` の「ユーザー固有データをログアウト時に破棄する」という方針にも反する。

### [P2] 失敗したログインのトークンが永続化されたまま残る

対象: `lib/features/auth/application/auth_controller.dart:205-208`

トークンを保存した後に、レスポンスに `user` が無い場合の `fetchCurrentUser()`、ユーザー切替時の破棄、ユーザー情報の保存が続く。これらが失敗すると `login()` はエラーを返して画面上は未ログインのままだが、新しいトークンはセキュアストレージに残る。そのため、次回起動時に意図せず自動ログインしたり、古いユーザー情報と新しいトークンが一時的に混在したりする。ログイン処理をコミット/ロールバック可能にするか、保存後の失敗時に以前の認証情報へ確実に戻す必要がある。

## 性能・省メモリ上の改善候補

### キャッシュ掃除の DB アクセスを計測し、必要なら索引を追加する

対象: `lib/core/cache/image_cache_store.dart:333-419`, `lib/core/storage/app_database.dart:20-48`

掃除では `kind` ごとの `SUM(bytes)`、`kind` と `lastUsedAt` による LRU 順取得、保持期限による抽出を行うが、`CachedImages` に対応する索引がない。大量のサムネイルを保持する端末では全表走査と一時ソートが発生するため、`EXPLAIN QUERY PLAN` と実機計測の上で `(kind, last_used_at, key)` などの索引を検討する。保持期限の削除も全件を一度に Dart オブジェクト化しているため、件数が多い場合は既存の `_evictPageSize` と同様の分割処理が安全である。

### UI isolate 上の同期ファイル列挙を非同期化する

対象: `lib/features/downloads/data/download_store.dart:174-214`, `lib/features/downloads/data/download_store.dart:291-347`, `lib/features/downloads/data/transfer_temp_files.dart:45-67`

`listSync`、`existsSync`、`lastModifiedSync` がログアウト、起動時照合、一時ファイル掃除で使われている。ダウンロード巻数や孤児ファイル数が多い端末ではフレーム停止要因になるため、`Directory.list()` と非同期 `stat` へ寄せるか、まとまった走査を isolate に移すとよい。

## 保守性上の改善候補

### `DownloadQueue` を責務別に分割する

`lib/features/downloads/application/download_queue.dart` は約 2,040 行あり、転送投入、イベント直列化、起動時照合、再試行、インストール、容量予約、後始末を 1 クラスが担当している。現状はテストとコメントが充実しているものの、状態集合が多く、変更時に不変条件を追う範囲が広い。少なくとも「起動時 reconcile」「転送イベント reducer」「確定/install」「一時ファイル cleanup」を内部サービスへ分け、`DownloadQueue` を調停役にすると回帰リスクを下げられる。

## 総評

テスト数と設計コメントは十分で、一般的な静的品質は高い。ただし、ログアウトとログイン失敗というセッション境界の 2 件は、通常テストが通っていてもユーザー固有データや認証状態を跨いで影響するため、優先して修正し、遅延完了を明示的に再現する回帰テストを追加したい。
