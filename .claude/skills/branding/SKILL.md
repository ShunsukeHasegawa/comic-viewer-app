---
name: branding
description: アプリのアイコン / スプラッシュを assets/branding/ の絵から作り直す（ツールが書き換える iOS のファイルと改行の後始末まで含む）。
disable-model-invocation: true
---

# アイコン / スプラッシュの再生成（#16）

CLAUDE.md の「リリース」の節と `pubspec.yaml` 末尾のコメントが正。生成物はコミットする。

## 0. 始める前に

- `git status` が空か確かめる（後始末で「ツールが勝手に変えたもの」だけを戻すため）。
  空でなければ、何が残っているかユーザーに伝えてから進める。
- 絵の元（`assets/branding/icon-512x512.png`）を差し替えるのはユーザー。こちらで描かない。

## 1. 絵を作り直す（元の絵を変えたときだけ）

```sh
python tool/make_branding.py .
```

Pillow が無ければ止めてユーザーに伝える（勝手に入れない）。

## 2. 生成する

```sh
TMP='C:\Temp\claude-dart' TEMP='C:\Temp\claude-dart' dart run flutter_launcher_icons
TMP='C:\Temp\claude-dart' TEMP='C:\Temp\claude-dart' dart run flutter_native_splash:create
```

## 3. ツールの余計な書き換えを戻す

`git diff --stat` を見て、次を戻す（絵の差し替えと無関係な変更）。

- `ios/Runner.xcodeproj/project.pbxproj` の
  `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` の追加 → 戻す
  （他に変更が無ければ `git checkout -- ios/Runner.xcodeproj/project.pbxproj`）。
- `ios/Runner/Info.plist` の全体の字下げの変更と `UIStatusBarHidden` → 戻す。
  スプラッシュに必要な変更が含まれていないか差分を読んでから判断する。
- **改行**: もとが CRLF のファイル（`Info.plist` / `project.pbxproj` など。
  `git diff` が全行変更になっていれば疑う）は CRLF に戻す。
  確認は `file <パス>`、戻すのは差分が改行だけなら `git checkout -- <パス>`。

戻した後の `git diff --stat` に残るのが、アイコン / スプラッシュの画像と、それを参照する
最小限の設定だけになっていること。

## 4. 確かめる

- `flutter test test/features/auth/splash_screen_test.dart`（Flutter 側の SplashScreen が
  ネイティブと同じ色・同じ大きさか）と `flutter test test/platform/platform_config_test.dart`。
- `/check` を通す。
- 実機（またはエミュレーター）でアイコン・起動画面（ライト / ダーク、Android 12 以上 / 未満）を
  確かめてもらうよう、ユーザーに頼む。mobile MCP が使えればスクリーンショットで確認してもよい。

## 5. コミット

日本語で `chore: アイコン / スプラッシュを作り直す` など。何の絵をなぜ変えたかを本文に書く。
