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

### ブランド

- アクセント: teal `#244C60`
- ダーク基調の背景: `#0a0f1a`
- フォント: Noto Sans JP（端末に無い場合は日本語フォントへフォールバック。`lib/core/theme/app_typography.dart`）

Light / Dark 両対応で、テーマは OS 設定に従う。

## CI

`.github/workflows/ci.yml`

- `analyze-and-test`: 生成コードの差分チェック → `dart format` → `flutter analyze` → `flutter test`
- `build-android`: `flutter build apk --debug`

## 進め方

Epic は [#1](https://github.com/ShunsukeHasegawa/comic-viewer-app/issues/1)。
API → 状態 → UI の縦切りで 1 Issue ずつ動く状態にする。
