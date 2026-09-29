# Comic LAZ（Flutter アプリ）作業ガイド

Nuxt PWA 版（`ShunsukeHasegawa/comic-viewer` の `frontend/`）からの移行先。
目的は **画像キャッシュの制御**と **巻 / タイトル単位のオフライン再生**。
Issue は GitHub（`ShunsukeHasegawa/comic-viewer-app`）で管理し、Epic は #1。

## 環境の注意（重要）

- `dart run build_runner build` は **TMP / TEMP を ASCII パスにしないと失敗する**
  （ユーザー名が日本語のため）。必ずこの形で実行する:

  ```sh
  TMP='C:\Temp\claude-dart' TEMP='C:\Temp\claude-dart' dart run build_runner build
  ```

  `--delete-conflicting-outputs` は build_runner 2.16 で廃止済み（付けない）。
- 生成コード（`*.g.dart` / `*.freezed.dart`）はコミットする。CI で再生成して差分が
  出たら失敗する。
- コミット前に必ず: `dart format .` → `flutter analyze`（警告ゼロ）→ `flutter test`（全パス）。
- `flutter test` は全体で 1 分弱かかる。作業中は対象ディレクトリだけ流してよい。

## アーキテクチャ

| 領域 | 採用 |
| --- | --- |
| 状態管理 / DI | `flutter_riverpod` + `riverpod_generator`（`@riverpod` / `@Riverpod(keepAlive: true)`） |
| ルーティング | `go_router`（`lib/core/router/app_routes.dart`） |
| HTTP | `dio`（`ApiClient` 経由） |
| モデル | `freezed` + `json_serializable` |
| ローカル DB | `drift`（`lib/core/storage/app_database.dart`） |
| セキュアストレージ | `flutter_secure_storage` |

```
lib/
  core/       config / network / router / theme / widgets / media / storage / cache / device / session / utils / json
  data/api/   エンドポイント（BooksApi / UserApi / TaxonomyApi / ApiClient）
  domain/models/  freezed モデル
  features/<機能>/{application,data,domain,presentation}
test/         lib と同じ構成。共通フェイクは test/support/
```

## 実装の約束

- **非同期処理の後で `ref` を使う前に `ref.mounted` を確認する**。自前の dispose
  フラグは Notifier が再利用されると壊れるので使わない。
- 画面の `AsyncNotifier` は `@Riverpod(retry: noAutoRetry)`（`library_controller.dart`）。
  自宅サーバー（HDD）を叩き続けないため、再試行はユーザー操作に限る。
- 失敗したときに**黙って古い内容を見せない**。表示が残る場合は SnackBar
  （`showRefreshFailure`）、何も無い場合はエラー表示 + 再試行。
- 通信エラーと 404 は型で区別する（`ApiException` の各サブクラス）。通信エラーで
  手元の進捗やキャッシュを捨てない。
- 画像 URL の組み立ては `MediaUrls` だけ。ページは `?v={files_version}` 必須、
  サムネイルは API が返す `?m=` 付き相対 URL をそのまま解決（`null` は組み立て直さない）。
- 画像の取得経路は `ComicImageLoader` だけ。解決順は「ダウンロード済みローカル（ZIP）
  → 一時キャッシュ → ネットワーク」で、増やすときもここ 1 箇所で決める（#11）。
- オフライン用のメタ情報（一覧 / 詳細 / 巻情報 / カテゴリ）の出し入れは
  `OfflineMetadataGateway`（`features/offline/`）を通す。画面から drift を直接触らない。
- 「オフラインか」は OS の接続状態ではなく**実際の通信結果**で判断する
  （`LibraryData.isStale` など）。`ConnectivityMonitor` は再試行の合図としてだけ使う。
- 画像に Bearer を付けるのは **API と同じオリジンのみ**（`AppConfig.isApiOrigin`）。
- 端末内にユーザー固有データを持つ機能は `SessionDataPurger` を
  `sessionDataPurgersProvider` に登録する（ログアウト時に破棄。#15）。
  取り直せないデータ（ダウンロード済み ZIP / 未送信の進捗）を消すものは
  `purgesRefetchableOnly = false` にする。`safe_mode` の変更だけでは走らせない
  （同じユーザーの数 GB と、サーバーにも無い読書位置を黙って消さない）。
- 「オフラインで読めるか」は台帳の `status` ではなく
  `VolumeDownload.hasInstalledArchive` で判断する。「更新あり」の取り直し中も
  旧世代の ZIP は端末に残っていて読める。
- テストはネットワークとプラットフォームチャネルを触らない。`test/support/test_scope.dart`
  の `testOverrides` / `createContainer` を使い、必要なフェイクは `test/support/` に足す。
- テスト名・コメントは日本語で、「なぜ」を書く（「何を」はコードを読めば分かる）。

## サーバー API（comic-viewer）で確認済みの事実

- `/api/books` は **`data` ラップ無しの配列**（静的 JSON 配信・ETag + must-revalidate）。
  著者は**単数形 `author`**、`tags` / `categories` は **ID の配列**。
- `/api/books/user_status` → `{unreads: int[], favorites: int[]}`
- `/api/books/read/volume/{id}` → `{id, volume, current_page, next_volume_id,
  next_volume_thumbnail, files: int[], files_version, book}`（`files_version` は ZIP の mtime）
- `/api/v2/books/{id}` → `{..., volumes: [{id, volume, thumbnail, total_pages,
  archive_bytes, files_version, user_volume_status}], total_archive_bytes, reading_progress}`
- `/api/v2/user/reading` → **`data` ラップあり**
- `/api/user-volume-status/history?page=` → Laravel ページネーション
- `POST /api/user-volume-status/{volumeId}`（`current_page` / `max_page` / 任意の `read_at`）
  → **プレーンテキスト `OK`**。サーバーは `max()` を取らない upsert なので、
  古い進捗を送ると他端末の進捗を巻き戻す。
- 認証は Bearer（`POST /api/auth/token` は 201 で `{token, user, expires_at}`）。
  401 のみセッション失効として扱い、403 はリソース単位の権限エラー。
- `POST /api/v2/user-volume-status/bulk`（進捗の一括同期。1〜100 件）
  → `{items: [{volume_id, current_page, max_page, read_at}]}`（`read_at` は
  **タイムゾーン付き**・秒精度。TZ 無しは `Asia/Tokyo` と解釈される）。応答は
  `{applied: [status], skipped: [{volume_id, reason, current}]}`、`reason` は
  `not_found` / `stale` / `future_read_at`。`status` は
  `{volume_id, current_page, max_page, is_finished, read_at, updated_at}`。
  競合解決は**クライアント申告の `read_at` 同士**の比較（サーバーが新しければ
  `stale` + `current`）。単発 API は無条件 upsert なので、アプリは 1 件でも
  こちらを使う（#12）。
- オフライン向けに `GET /api/v2/volumes/{id}/manifest`、`GET /api/v2/volumes/{id}/archive` が
  **サーバー側に実装済み**。
  実装前に `gh api repos/ShunsukeHasegawa/comic-viewer/contents/<path>` で
  コントローラ / リソースの形を確認すること（推測で書かない）。
- 画像: `/books/view/{volumeId}/{page}`（数値のみ）、`/books/thumbnail/{volumeId}?m=`。
- セーフモードは**サーバー側が正**（`is_unsafe` の巻はそもそも配信されない）。

## Issue の進め方

1. `gh issue view <番号>` で要件を読む。
2. `feature/issue-<番号>-<slug>` ブランチで実装（テストも同時に書く）。
3. `dart format .` / `flutter analyze` / `flutter test` を通す。
4. 日本語のコミットメッセージ（何をしたか + なぜそう決めたか、`Closes #<番号>`）。
5. 依存する未実装機能は「導線だけ用意して無効化」し、担当 Issue 番号をコメントに残す。
