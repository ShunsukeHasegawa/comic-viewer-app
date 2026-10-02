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
- 破棄は `SessionPurgeJournal`（drift の Settings）の印を**先に**書き、全 purger が
  成功したときだけ消す。ログアウトでは印 → トークン削除 → 破棄の順。印が残っていれば
  起動時（`restoreSession` の先頭）とログイン時にやり直す（#15）。purger は失敗を
  握らずに投げる（握ると印が消えて二度とやり直されない）。
- 破棄のやり直し / ユーザー切り替えの破棄が失敗しても**ログイン / 復元は止めない**
  （個人用アプリとして、厳密なユーザー間の分離より締め出さないことを優先した判断。
  止めると毎回失敗する purger 1 つで二度とログインできなくなる）。代わりに印を捨て
  （残すと次の起動のやり直しが新しいセッションのデータを消す）、ログイン時は
  `SessionCleanupNotice` → `ComicLazApp` の SnackBar で知らせる（起動時はログのみ）。
  `SessionCleanupException` で止めるのは入れ直し直後の目印を片付けられないときだけ。
- `AuthStore.readUser` は「未保存」なら `null`、「保存はあるが読み解けない」なら
  `StoredUserUnreadableException`。ログイン時は持ち主不明として全部破棄し、起動時は
  トークンの持ち主と同じなので上書きする。ログイン時に前のトークンだけ残りユーザーが
  無いときも持ち主不明として扱う。
- iOS の Keychain はアプリの削除で消えない。drift の `onCreate` が書く目印
  （`InstallMarker`）があれば、起動 / ログインの前に `AuthStore.clear()` する
  （入れ直した端末が前の持ち主で自動ログインしないため。既存の端末は `onUpgrade` を
  通るので目印は無い）。テストでは `FakeInstallMarker`（既定は目印なし）。
- セーフモードの OFF → ON では一括削除せず、`SafeModeRevalidator` がダウンロード済みの
  タイトルを 1 件ずつ `GET /api/v2/books/{id}` で確かめ、**404 のタイトルだけ**消す。
  通信エラー・5xx・429・401 では消さずに予約（`SafeModeRevalidationStore`）を残し、
  403 は飛ばす。開いている巻は消さない。404 は「本文がコントローラの JSON
  `{"message": "Not Found"}`（`NotFoundException.serverMessage`）」「その回が通信エラー
  無しで終わった」「`/api/books`（セーフモード版）が空でなく、そのタイトルが載って
  いない」の 3 つが揃ったときだけ消す（プロキシの誤設定などで全部消さないため）。
  前面復帰 / 回線復帰でのやり直しは 1 時間に 1 回まで（ログイン直後は間引かない。
  圏外で止まった回は数えない）。
- 端末内のファイルは `AppDirectories`（support / cache）配下に置く。新しい置き場を
  作ったら `StorageProtector` の iOS バックアップ除外に足す。`.nomedia` は support /
  cache の**直下**（images / downloads に置くと孤児の掃除とログアウトの全削除で消える）。
- Android はバックアップ / 端末間転送を**全部**除外している（`data_extraction_rules.xml`
  / `backup_rules.xml` / `allowBackup="false"`）。戻すときは「DB だけ復元されて台帳と
  ZIP が食い違う」「Bearer 入りの転送記録が持ち出される」を先に検討する。
  `test/platform/platform_config_test.dart` が退行を止める。
- OS の保護機能はチャネル `com.lazgram.comic_laz/device_protection`（`DeviceProtection`。
  iOS は `AppDelegate.swift`、Android は `MainActivity.kt`）だけ。プラグインは足さない。
  チャネルが無い環境でも落とさない。テストでは `FakeDeviceProtection`。
- 「オフラインで読めるか」は台帳の `status` ではなく
  `VolumeDownload.hasInstalledArchive` で判断する。「更新あり」の取り直し中も
  旧世代の ZIP は端末に残っていて読める。
- 巻の ZIP の転送は `ArchiveTransport`（`archiveTransportProvider`）だけ（#10）。
  OS のバックグラウンド転送なのでアプリを閉じても続く。検証・rename・台帳の確定は
  `DownloadQueue` に残す。`FileDownloader()` を他の場所で作らない（最初に作った側の
  永続化ストアが使われ、再開データを引けなくなる）。テストでは `FakeArchiveTransport`
  （`testOverrides` の既定）を使う。
- 転送の taskId は `v{volumeId}.f{filesVersion}.s{sessionTag}.n{nonce}`（`ArchiveTaskId`）。
  タグはログアウトで作り直し、違うタグの完了は取り込まない（#15）。ノンスは投入ごとに
  作り直す（Android の一時停止の印が ID ごとに残るため。再開は同じ ID）。起動時は
  `_reconcile` で OS 側の転送と台帳を突き合わせる（プラグインの自動再投入は使わない）。
- 止める意図（中断）は**先に台帳へ書く**。OS から届く `paused` は台帳が中断なら
  ユーザー操作、待機中 / 取得中のままなら 9 分の時間切れなどの一時的なものとして扱う。
- ネイティブの 401 ですぐにログアウトさせない。マニフェストを Dio で取り直し、
  失効していれば `AuthInterceptor` → `handleSessionExpired` の 1 経路に合流させる。
- タスクの記録には Bearer が平文で残る（パッケージの永続領域）。ログアウトでは
  `transport.reset()` をファイル削除より先に呼ぶ。
- ネイティブの転送は https 前提。開発用の http サーバーでは ZIP のダウンロードは
  失敗する（debug 用の cleartext 許可 / `NSAllowsLocalNetworking` は入れていない）。
- テストはネットワークとプラットフォームチャネルを触らない。`test/support/test_scope.dart`
  の `testOverrides` / `createContainer` を使い、必要なフェイクは `test/support/` に足す。
- テスト名・コメントは日本語で、「なぜ」を書く（「何を」はコードを読めば分かる）。

## 端末内データの保護で決めたこと（#15）

- **ファイル単位の暗号化・起動時の生体認証ロック・画面の保護（スクリーンショット禁止 /
  `FLAG_SECURE`）は作らない**（個人用アプリのため意図して見送り。再提案・再実装しない）。
  保存時の暗号化は OS（Android の FBE / iOS の Data Protection）に任せ、端末のロック画面を
  一次防御とする。アプリ側の暗号化はページ送りのたびの復号で ZIP のランダムアクセス（#11）も壊す。
  Android の `MainActivity` はチャネルを持たない（プレーンな `FlutterActivity`）。
- **バックアップ / 端末間転送からは全部外す**（iOS: support / downloads / Documents（DB）/
  画像キャッシュに `isExcludedFromBackup`。Android: 上記の XML）。
- 残存リスク: iOS の `UserDefaults`（background_downloader のネイティブ状態）はバックアップ
  から外せない。Dart が繋がっていない間（アプリ終了中）に届いた転送の状態 / 再開データは
  `com.bbflight.background_downloader.{statusUpdateMap,progressUpdateMap,resumeDataMap}.v2`
  に Task の JSON ごと入り、**Bearer 入りのヘッダを含む**。次の起動の
  `ArchiveTransport.start` で取り出されるまでの間はバックアップに載りうる（取り出す前に
  消すと完了を失うので消さない。根本対策は巻単位の短命トークンで、サーバー側の変更が要る）。
  nsurlsessiond の一時ファイルは OS 管理。SQLite の削除済みページは VACUUM
  まで残りうる。圏外起動中の `safe_mode` 変更は次にサーバーへ届くまで気づけない。

## リリース（#16。手順の詳細は README の「リリース」）

- 配布は Android の **APK 直接配布だけ**（Play / TestFlight / iOS は対象外）。
  `applicationId` は `com.lazgram.comic_laz` から変えない。
- 署名は `android/key.properties`（git 管理外。書式は `android/key.properties.example`）。
  無ければ release は debug 鍵で署名し警告する（手元確認用）。CI は
  `COMIC_LAZ_REQUIRE_RELEASE_SIGNING=true` で鍵が無ければ失敗させ、`apksigner` で
  debug 署名でないことも確かめる。**keystore やパスワードを作らない / コミットしない**
  （作るのはユーザー。鍵が変わると上書きできず、入れ直しでダウンロードが消える）。
- R8 / リソース縮小は**切ったまま**にする（`background_downloader` が keep ルールを
  持たず、release だけで転送が壊れうる。有効にするなら実機で転送を確かめてから）。
- バージョン: versionName はタグ（`v1.2.3`）、versionCode は `ci.yml` の
  `github.run_number`。`ci.yml` のファイル名を変えない（versionCode が巻き戻る）。
- リリースの job は `ci.yml` の `release-android`（`v*` タグ / 手動実行。Secrets は
  `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` /
  `ANDROID_KEY_PASSWORD`）。
- `minSdk` は `flutter.minSdkVersion`（現在 24）のまま数値で固定しない。
- アイコン / スプラッシュは `assets/branding/` の絵から生成する（設定は `pubspec.yaml` 末尾）。
  絵を変えたら `python tool/make_branding.py .` → TMP / TEMP を ASCII にして
  `dart run flutter_launcher_icons` と `dart run flutter_native_splash:create`。
  ツールは `ios/Runner.xcodeproj/project.pbxproj`（`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`）
  と `Info.plist`（全体の字下げ・`UIStatusBarHidden`）を書き換えるので戻し、CRLF だった
  ファイルの改行も戻す。Flutter の `SplashScreen` はネイティブと同じ色・同じ大きさの
  ロゴにしてある（`test/features/auth/splash_screen_test.dart` が食い違いを止める）。

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
