# Comic LAZ (Flutter)

Comic LAZ のネイティブアプリ（Android / iOS）。
Nuxt 4 + PWA 版（[comic-viewer](https://github.com/ShunsukeHasegawa/comic-viewer) の `frontend/`）からの移行先で、
**画像キャッシュの制御**と**巻 / タイトル単位のオフライン再生**を実現することが目的。

API サーバーは comic-viewer 側で管理する。

## セットアップ

```sh
flutter pub get
# 生成コード（Riverpod / freezed / json_serializable）
dart run build_runner build
# 変更しながら開発する場合
dart run build_runner watch
```

### 実行

```sh
# 本番 API（既定）
flutter run

# 開発サーバーに向ける
flutter run \
  --dart-define=API_BASE_URL=http://192.168.0.2:8000 \
  --dart-define=APP_FLAVOR=development
```

| dart-define    | 既定値                         | 内容                                     |
| -------------- | ------------------------------ | ---------------------------------------- |
| `API_BASE_URL` | `https://comic.lazgram.com`    | API / 画像の配信元（http(s) の絶対 URL） |
| `APP_FLAVOR`   | `production`                   | `production` / `development`              |

不正な値を渡した場合は起動時に設定エラー画面を出す（`lib/core/config/app_config.dart`）。

### 検証

```sh
dart format .
flutter analyze
flutter test
```

## アーキテクチャ

| 領域               | 採用                                      |
| ------------------ | ----------------------------------------- |
| 状態管理 / DI      | `flutter_riverpod` + `riverpod_generator` |
| ルーティング       | `go_router`                               |
| HTTP               | `dio`                                     |
| モデル             | `freezed` + `json_serializable`           |
| ローカル DB        | `drift`（#9 以降のオフライン機能で導入）  |
| セキュアストレージ | `flutter_secure_storage`                  |
| 端末情報           | `device_info_plus`（`device_name` 用）    |

```
lib/
  main.dart                  エントリポイント（設定の検証と ProviderScope）
  app.dart                   MaterialApp.router
  core/
    config/                  ビルド時設定（--dart-define）
    network/                 dio の共通設定
    router/                  go_router のルート定義とシェル
    theme/                   カラー / タイポグラフィ / ThemeData
    widgets/                 共通ウィジェット
  features/<機能>/           機能単位（presentation / application / data）
  data/ domain/              機能横断のモデル・リポジトリ（#4 以降）
test/                        lib/ と同じ構成で配置
```

生成コード（`*.g.dart` / `*.freezed.dart`）はリポジトリにコミットする。
CI で再生成して差分が出た場合は失敗させる。

### ルーティング

Web 版の URL 体系に合わせる（`lib/core/router/app_routes.dart`）。

| パス              | 画面             |
| ----------------- | ---------------- |
| `/`               | ライブラリ       |
| `/history`        | 読書履歴         |
| `/mypage`         | マイページ       |
| `/book/{id}`      | タイトル詳細     |
| `/book/view/{id}` | ビューア（RTL）  |
| `/login`          | ログイン         |

`/`, `/history`, `/mypage` はボトムナビのタブ（`StatefulShellRoute` で各タブの状態を保持）。
ID が数値でない場合や未知の URL は 404 画面にフォールバックする。

### 認証

Web 版は Sanctum の SPA Cookie 認証だが、アプリでは **Bearer トークン**を使う
（画像・アーカイブ取得でも Cookie / CSRF を持ち回らずに済むため）。

| 用途 | エンドポイント |
| --- | --- |
| トークン発行 | `POST /api/auth/token`（`email` / `password` / `device_name`） |
| トークン検証（起動時） | `GET /api/user` |
| トークン破棄 | `DELETE /api/auth/token` |

サーバー側は comic-viewer#6。応答は `{"token": "...", "user": {...}}` を想定し、
`user` を返さない実装でも `GET /api/user` で補う。

- トークンは `flutter_secure_storage` に保存（iOS は `first_unlock_this_device` = iCloud キーチェーンへ同期しない）
- `AuthInterceptor` が `Authorization: Bearer` を付ける（画像・アーカイブも同じ経路）。
  付与と 401 の扱いは **API と同じオリジン**に限る（CDN / 署名付き URL へトークンを送らない）
- **401 のみ**セッション失効として扱い、トークンを破棄して端末内データを消す。
  403 は「認証済みだが権限が無い」（セーフモードなど）なのでログアウトはさせない
- ログアウト / 失効時の端末内データ破棄は `SessionDataPurger` として登録する
  （画像キャッシュ #8 / ダウンロード #9 / 進捗 #12 がそれぞれ実装を足す。詳細は #15）
- 圏外起動で検証できないときはトークンを保持し、保存済みユーザーでオフライン継続する（#11）
- `safe_mode` はサーバー側が正。クライアントは表示のヒントとしてしか使わない

認証状態に応じてルータが遷移する: 検証中は `/splash`、未ログインは
`/login?from=<開こうとした URL>`、ログイン後は `from` の画面へ戻る。

### オフライン再生（#11）

機内モードでも「一覧 → 詳細 → ビューア → 読了」まで到達できることを目標にしている。

- **画像の解決順は `ComicImageLoader` 1 箇所で決める**:
  ダウンロード済みローカル（ZIP）→ 一時キャッシュ → ネットワーク。
  ページは ZIP のまま保持し、開くときに該当エントリだけを取り出す
  （セントラルディレクトリ + 1 エントリだけ読むので数ミリ秒。一時キャッシュへは写さない）
- サーバーの `files_version` と手元の世代が食い違うときは**ローカルを使わず**
  「更新あり」として扱う（勝手に消さない。取り直しはユーザー操作）
- メタ情報は drift（`offline_metadata` テーブル）に JSON で持つ。
  出し入れは `OfflineMetadataGateway`（`lib/features/offline/`）だけを通す
  - 一覧（`/api/books`）と ETag・未読 / お気に入り（次回は `If-None-Match` で 304 を狙う）
  - カテゴリ / タグ（絞り込みチップが消えると解除できなくなる）
  - **ダウンロード済みタイトル**の詳細と、**ダウンロード済み巻**の `ReadVolume`
    （ダウンロードしただけで開いていない巻は、マニフェストと詳細から組み立てる）
  - ダウンロード済みタイトルのサムネイルは `pinned_images` で保護し、LRU / 保持期間で消さない
- 詳細の控えは**ダウンロードの完了時にも**書く（詳細画面は autoDispose なので、
  始めてすぐ一覧へ戻ると誰も控えない = 圏外で一覧には出るのに開けないタイトルになる）
- ダウンロードを削除したタイトル / 巻の控えは、一覧の読み込み時に掃除する
  （残す条件は「台帳に行があるか」。取り直し中の控えを消さない）
- 「オフラインで読めるか」は台帳の `status` ではなく
  **台帳が指す世代の実体があるか**（`VolumeDownload.hasInstalledArchive`）で決める。
  「更新あり」の取り直し中・中断中も旧世代の ZIP は端末に残っていて読める
- UI: 一覧のオフラインバナー、「ダウンロード済みのみ表示」トグル（**圏外では既定 ON**）、
  未ダウンロードの巻はエラーダイアログではなく**無効表示**、ネットワーク復帰で一覧を自動更新
- オフライン判定は OS の接続状態ではなく**実際の通信結果**（`isStale`）で行う
  （接続があっても自宅サーバーに届かないことがある）
- セーフモードはサーバー側が正なので `is_unsafe` の巻は端末に無いが、
  前の設定 / 前のユーザーで取った一覧・詳細がキャッシュ経由で見えてしまうため破棄する。
  **破棄の範囲は分ける**（`SessionPurgeScope`）:
  - ユーザーが変わった / ログアウト・失効 → 端末内のユーザー固有データを全部
    （オフライン用メタ情報・画像キャッシュ・**ダウンロード済みの巻**・**読書進捗**）
  - `safe_mode` だけが変わった → **取り直せるものだけ**（オフライン用メタ情報・画像キャッシュ）。
    同じユーザーのダウンロード（数 GB）と、まだ送れていない読書位置
    （サーバーにも無いので消すと永久に失われる）は残す

### ブランド

- アクセント: teal `#244C60`
- ダーク基調の背景: `#0a0f1a`
- フォント: Noto Sans JP（端末に無い場合は日本語フォントへフォールバック。`lib/core/theme/app_typography.dart`）

Light / Dark 両対応で、テーマは OS 設定に従う。

## CI

`.github/workflows/ci.yml`

- `analyze-and-test`: 生成コードの差分チェック → `dart format` → `flutter analyze` → `flutter test`
- `build-android`: `flutter build apk --debug`（push / PR のとき）
- `release-android`: 署名済みのリリース APK（`v*` のタグ push と手動実行のときだけ。
  `analyze-and-test` が通ってから動く）。詳細は次の「リリース」

## リリース（Android APK の直接配布。#16）

配布は **APK の直接配布**だけ（個人用途。Google Play / TestFlight は使わない。iOS は対象外）。

- アプリ ID は `com.lazgram.comic_laz` のまま変えない（変えると別アプリとして入り、
  ダウンロード済みの巻を引き継げない）
- 通信は HTTPS 前提（巻の ZIP のバックグラウンド転送は http では動かない）
- 対応 OS は **Android 7.0（API 24）以上**（`minSdk` は Flutter の既定に従う。
  数値で固定すると Flutter が既定を上げたときにビルドが壊れるため）
- アプリ名は「Comic LAZ」。アイコン / スプラッシュは Web 版の PWA アイコンとブランドカラー
  （teal `#244C60` / ダーク `#0a0f1a`）から生成している（作り直し方は `pubspec.yaml` 末尾のコメント）

### バージョニング

`pubspec.yaml` の `version: x.y.z+build` の形。

| 部分 | 意味 | 決め方 |
| --- | --- | --- |
| `x.y.z`（versionName） | 人が見る版 | 互換を切る変更（端末内データの作り直しなど）で `x`、機能追加で `y`、修正だけなら `z` を上げる |
| `build`（versionCode） | Android が上書きの可否を決める整数 | **CI の `github.run_number`**（`ci.yml` の実行回数。単調増加） |

- リリースの版は**タグが正**（`v1.2.3` → versionName `1.2.3`）。タグを打つ前に `pubspec.yaml` の
  `x.y.z` を同じ値に上げてコミットする（違うと CI が警告を出し、APK にはタグの値を使う）
- `pubspec.yaml` の `+build` は手元のビルド用で、CI では使わない
- Android は versionCode が**下がる**上書きインストールを拒否する。CI の APK を入れた端末に
  手元の release ビルドを上書きしたいときは `--build-number` をそれより大きくする
- `.github/workflows/ci.yml` のファイル名を変えない（`run_number` が 1 からやり直しになり、
  以降の APK が「古い版」として上書きできなくなる）
- `v1.2.0-rc.1` のようなタグは GitHub Release の pre-release になる

### リリース署名（keystore）

署名鍵は**一度作ったら変えない**。鍵が変わると上書きインストールできず、アンインストール
（= ダウンロード済みの巻・まだ送れていない読書位置が消える）が必要になる。

1. keystore を作る（自分で実行する。JDK 17 の `keytool`。Android Studio 同梱なら
   `"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`）。

   ```sh
   # 1 行のまま PowerShell / bash のどちらでも動く。パスワードと名前は対話で入力する
   keytool -genkeypair -v -storetype PKCS12 -keyalg RSA -keysize 4096 -validity 10000 -keystore C:/Keys/comic-laz-release.jks -alias comic-laz
   ```

   `-validity 10000`（約 27 年）は鍵の有効期限。切れると更新版を出せないので長く取る。

   PKCS12 では鍵のパスワードは keystore のパスワードと同じになる
   （`storePassword` と `keyPassword` に同じ値を入れる）。

   パスワードの先頭・末尾には空白を使わない方が安全（key.properties や Secrets に
   貼るときに紛れ込んだ / 落ちた空白に気づけず、署名が「password was incorrect」で
   失敗する）。使った場合の書き方は手順 3。

2. 置き場所と控え
   - keystore は**リポジトリの外**に置く（例: `C:\Keys\`）。`.gitignore` で `*.jks` /
     `*.keystore` / `android/key.properties` は止めているが、そもそも置かない
   - **必ず控えを取る**: keystore ファイルとパスワード・エイリアスを、パスワードマネージャ
     と別の媒体（USB メモリ / クラウドストレージ）の 2 か所以上に。失うと以後のリリースを
     同じアプリとして更新できない（アンインストールしてダウンロードし直すしかない）

3. `android/key.properties.example` を `android/key.properties` にコピーして値を入れる。

   ```properties
   storeFile=C:/Keys/comic-laz-release.jks
   storePassword=（keystore のパスワード）
   keyAlias=comic-laz
   keyPassword=（同じパスワード）
   ```

   - `storeFile` の相対パスは `android/` から。Windows でも区切りは `/`
     （`\` はエスケープ文字として読まれる。使うなら `\\`）。パスワード中の `\` も `\\`
   - パスワードの前後の空白は削らずにそのまま使う（行末に余計な空白を残さない）。
     先頭が空白のパスワードは前に `\` を付ける（例: `storePassword=\ pass`）。
     CI は Secrets の値をこの形に直して書く
   - 文字コードは UTF-8（日本語を含むパス可。BOM 付きでも読める）

`android/key.properties` が**無い**とき、release ビルドは **debug 鍵で署名**される
（Gradle が警告を出す。手元で release の挙動を見るためだけのもの）。この APK は
リリース署名の APK と上書きできないので配らない。CI のリリースビルドは鍵が無ければ失敗する。

R8（コード縮小）は切っている（`android/app/build.gradle.kts` のコメント）。
`background_downloader` が keep ルールを持たず、release だけで転送が壊れうるため。

### 開発版とリリース版

開発版（debug）は**別アプリ**として入る（アプリ ID `com.lazgram.comic_laz.debug`、名前「Comic LAZ Dev」）。
署名の違うリリース版と同じ ID だと、切り替えるたびにアンインストールが要り、普段使いの
ダウンロード済みの巻が消えるため。ログイン・ダウンロードは別々に持つ。

Android Studio では、実行構成 **`main.dart (release)`**（`.run/main_release.run.xml`）を
選んで実行すると、`key.properties` の鍵で署名したリリース版が入る。通常の `main.dart`
は開発版（ホットリロード可）。

### 手元でリリースビルド

Windows でユーザー名に日本語が入っている場合、pub のキャッシュと一時ディレクトリを
ASCII のパスにしないと失敗する（`build_runner` と同じ理由）。TMP / TEMP に指定する
ディレクトリは**先に作っておく**（無いと一時ファイルを作れずビルドが失敗する）。

```powershell
# PowerShell
New-Item -ItemType Directory -Force C:\Temp\dart | Out-Null
$env:PUB_CACHE = 'C:\PubCache'
$env:TMP = 'C:\Temp\dart'; $env:TEMP = 'C:\Temp\dart'
flutter build apk --release
```

```sh
# Git Bash
mkdir -p /c/Temp/dart
PUB_CACHE='C:\PubCache' TMP='C:\Temp\dart' TEMP='C:\Temp\dart' flutter build apk --release
```

成果物は `build/app/outputs/flutter-apk/app-release.apk`。

**手元のリリースビルドは確認用**で、配るのは CI の APK だけにする。CI はビルド番号
（versionCode）に Actions の実行番号を使うので、手元のビルド（`pubspec.yaml` の `+1`）は
CI の APK より番号が小さく、CI の APK を入れた端末には上書きできない
（`INSTALL_FAILED_VERSION_DOWNGRADE`。入れ直すとダウンロード済みの巻が消える）。
どうしても手元の版を同じ端末に入れるときは、直近の CI の実行番号より大きい
`--build-number` を付ける（その後の CI の APK が今度は上書きできなくなる点に注意）。
本番以外の API に向けるときは「実行」と同じ `--dart-define` を付ける。

### GitHub の Secrets

リポジトリの Settings → Secrets and variables → Actions に 4 つ登録する
（リポジトリは public だが、Secrets はフォークの PR からは読めない。リリースの job は
タグ push / 手動実行 = 書き込み権限のある人の操作でしか動かない）。

| 名前 | 値 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | keystore ファイルを base64 にしたもの |
| `ANDROID_KEYSTORE_PASSWORD` | keystore のパスワード |
| `ANDROID_KEY_ALIAS` | エイリアス（例: `comic-laz`） |
| `ANDROID_KEY_PASSWORD` | 鍵のパスワード（PKCS12 なら keystore と同じ） |

パスワードは前後の空白も含めてそのまま使われる（貼り付けで末尾に空白や改行を足さない）。

`gh` で登録する場合（値を画面やファイルに残さない）:

```powershell
# PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\Keys\comic-laz-release.jks')) |
  gh secret set ANDROID_KEYSTORE_BASE64
gh secret set ANDROID_KEYSTORE_PASSWORD   # 対話で入力
gh secret set ANDROID_KEY_ALIAS
gh secret set ANDROID_KEY_PASSWORD
```

```sh
# bash（macOS の base64 は -w が無いので `base64 -i <file>`）
base64 -w 0 C:/Keys/comic-laz-release.jks | gh secret set ANDROID_KEYSTORE_BASE64
```

Web の画面で登録する場合は、上の base64 の出力をクリップボード経由で貼る
（PowerShell なら `| Set-Clipboard`）。

### リリースの手順

1. `pubspec.yaml` の `version` の `x.y.z` を上げて master にコミット・push（CI が通ること）
2. タグを打って push する

   ```sh
   git tag v1.2.3
   git push origin v1.2.3
   ```

3. CI の `release-android` が署名済み APK（`comic-laz-1.2.3-build.<run_number>.apk`）を作り、
   - Actions の成果物（Artifacts）に上げる
   - **GitHub Release `v1.2.3` を下書き（draft）で作って添付する**（リポジトリは public だが、
     下書きは自分にしか見えない。個人用の APK を誰でも落とせる状態にしないため。
     公開したいときだけ GitHub 上で手で公開する）
4. job の Summary に出る**署名証明書の SHA-256** が前回と同じか確かめる
   （違うと上書きインストールできない）

タグを打たずに APK だけ欲しいときは、Actions → CI → Run workflow（手動実行）。
版は `pubspec.yaml` の `x.y.z`、成果物は Artifacts にだけ上がる（Release は作らない）。

### 端末へのインストール

- **端末で直接**: 端末のブラウザで GitHub にログインし、Release（下書き）のページから APK を
  ダウンロードして開く。
  初回は「不明なアプリのインストール」の許可を求められるので、そのブラウザ（または
  ファイルマネージャ）に許可する（設定 → アプリ → 特別なアプリアクセス →
  不明なアプリのインストール）。Play プロテクトの警告が出たら「詳細」→「このままインストール」
- **PC から adb**: 端末の開発者向けオプションで USB デバッグを有効にして

  ```sh
  adb install -r comic-laz-1.2.3-build.42.apk   # -r: データを残したまま上書き
  ```

  `INSTALL_FAILED_UPDATE_INCOMPATIBLE` は署名鍵が違う（次の項）、
  `INSTALL_FAILED_VERSION_DOWNGRADE` は versionCode が下がっている。

### 一度だけ: debug 署名版からの切り替え

これまで入れていた `flutter run` / CI の debug APK は debug 鍵で署名されているので、
リリース署名の APK を**上書きできない**。**最初の 1 回だけアンインストールが必要**で、
端末内のデータ（ダウンロード済みの巻・オフライン用の情報・画像キャッシュ・ログイン）は消える。

1. 切り替える前に、オンラインの状態でアプリを開いて読書位置を送り切っておく
   （まだ送れていない読書位置はサーバーにも無いので、消えると戻らない）
2. アンインストールする（`adb uninstall com.lazgram.comic_laz` か端末の設定から）
3. リリース APK を入れてログインし、読みたい巻をダウンロードし直す

以後は同じ鍵で署名した APK を上書きするだけでデータは残る。なお、リリース版を入れた
端末に `flutter run`（debug 鍵）で入れ直すと同じ理由で失敗する（開発は別の端末か
エミュレータで行う）。

## 進め方

Epic は [#1](https://github.com/ShunsukeHasegawa/comic-viewer-app/issues/1)。
API → 状態 → UI の縦切りで 1 Issue ずつ動く状態にする。
