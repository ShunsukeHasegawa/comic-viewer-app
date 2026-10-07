# サーバー（comic-viewer）への依頼事項

アプリ側だけでは解決できず、サーバー側の変更が要るものをまとめる。
確認日: 2026-10-07（サーバーは `master` の内容で確認）。

## 1. 巻の ZIP ダウンロード用の短命 URL（依頼）

### 困っていること

巻の ZIP（`GET /api/v2/volumes/{id}/archive`）は OS のバックグラウンド転送
（background_downloader）で取得しており、リクエストに `Authorization: Bearer <token>`
を付けている。このヘッダは転送タスクの JSON ごと端末に保存されるため、ログイン用の
トークンが平文で端末に残る。

- **Android:** パッケージの永続領域（タスクの記録）に残る。アプリ側はログアウト時に
  `transport.reset()` で消しているが、ログイン中は残り続ける。
- **iOS:** アプリ終了中に届いた転送の状態 / 再開データが `UserDefaults`
  （`com.bbflight.background_downloader.{statusUpdateMap,progressUpdateMap,resumeDataMap}.v2`）
  に入る。`UserDefaults` は iCloud / iTunes のバックアップから外せないので、次の起動で
  アプリが取り出すまでの間はトークンがバックアップに載りうる（iOS は今は配布対象外）。

漏れたトークンは ZIP だけでなく、API 全体（進捗の書き換え・お気に入りなど）に使えてしまう。

### お願いしたいこと

巻ごと・期限付きで、**その巻の ZIP しか取れない URL** を発行する API を足してほしい。
アプリはその URL を `Authorization` ヘッダ無しで転送に渡す。

例:

```
GET /api/v2/volumes/{volumeId}/archive-url   （Bearer 必須）
→ 200 {
    "url": "https://.../api/v2/volumes/340/archive?expires=...&signature=...",
    "expires_at": "2026-10-07T12:00:00+09:00",
    "files_version": 1727000000
  }
```

Laravel の `URL::temporarySignedRoute` + `signed` ミドルウェアで足りる想定。

### 決めてほしい / 気をつけてほしい点

- **有効期限は長めにする（目安: 24 時間）。** 転送は途中で止まり（OS の 9 分の時間切れ・
  圏外・ユーザーの一時停止）、同じ URL のまま Range で再開する。再開データは URL に
  紐づくので、途中で期限が切れると最初から取り直しになる。
- **ログアウト（トークン失効）で無効にする。** 署名にトークン ID（`personal_access_tokens.id`）
  を含め、配信時にそのトークンがまだ有効かを確かめてほしい。期限だけだと、ログアウト後も
  端末に残った URL で取れてしまう。
- **配信時にもセーフモードと `files_version` を確かめる。** 発行後に `safe_mode` が変わった
  場合や ZIP が差し替わった場合は 404 / 409 などで断ってほしい（いまの `archive` と同じ判定）。
  ZIP が差し替わったときに古い URL で新しい ZIP を返すと、アプリ側の検証（巻情報の
  `files_version` との突き合わせ）とずれる。
- **応答は今の `archive` と同じにする。** Range（206）・ETag・X-Accel 配信・
  `Cache-Control: private`。
- **失効・期限切れは 401 ではなく 403 にする。** アプリは 401 をログインの失効として扱う
  （マニフェストを取り直してからログアウトへ合流させる）。URL だけの失効でログアウト
  させないため、区別できるコードがよい。

### アプリ側でやること（サーバー対応の後）

- 転送の投入前に URL を発行し、`Authorization` ヘッダを付けない。
- 403（期限切れ / 失効）なら URL を発行し直して、最初から取り直す。
- これで CLAUDE.md の「タスクの記録には Bearer が平文で残る」「iOS の残存リスク」を
  解消扱いにできる。

## 2. 通知タップでタイトル詳細を開く（依頼なし・反映の確認だけ）

サーバーの `master`（`43f443e`、2026-10-05）で対応済み。
`PushNotificationService::updateBooksNotification` は、そのユーザー宛ての更新が
1 タイトルだけのときに data `{"book_id": "<id>"}` を添える。アプリ側
（`pushRouteFor`）は対応済みなので、本番へ反映されていればタップでタイトル詳細が開く。

- 複数タイトルのときは data を付けないので、アプリはライブラリを開く（意図どおり）。
- 本番へ反映済みかどうかは未確認。反映後に、お気に入りのタイトルを 1 件だけ更新して
  通知をタップし、詳細が開くことを確かめる。

## 3. Web 版の Issue #2（「続きから読む際、書籍詳細ページの履歴を挟む」）

アプリ側は comic-viewer-app#21 で対応した（「続きを読む」/ 履歴から開いた巻を閉じると
タイトル詳細へ戻る）。Web 版（Nuxt）の対応が要らなければ、サーバー側の Issue は
閉じてよい。
