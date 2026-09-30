import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../device/device_protection.dart';
import 'app_directories.dart';

part 'storage_protection.g.dart';

/// 端末内データの保護（#15）。起動のたびに冪等に掛け直す。
///
/// - Android: `support`（`filesDir`）と `cache`（`cacheDir`）の**直下**に
///   `.nomedia` を置く。内部領域なのでメディアスキャンの対象外だが、念のため。
///   バックアップ / 端末間転送の除外はマニフェスト（`data_extraction_rules.xml`）
///   で行うので、ここでは何もしない。
/// - iOS: ダウンロード・転送の記録・DB・画像キャッシュの置き場に
///   `NSURLIsExcludedFromBackupKey` を付ける（数 GB の ZIP と、Bearer が平文で
///   入った background_downloader の **Dart 側の**タスク記録を iCloud / PC に
///   載せない）。
///
/// 守れないもの: Dart が繋がっていない間に届いた転送の状態 / 再開データは、
///   プラグインのネイティブ側が `UserDefaults`（Library/Preferences。常に
///   バックアップ対象で除外できない）に Task の JSON（Bearer 入りのヘッダを含む）
///   として置き、次の起動で取り出すまで残る（`AppDelegate.swift` の説明を参照）。
class StorageProtector {
  StorageProtector({
    required this.protection,
    required this.isAndroid,
    required this.isIOS,
  });

  static const noMediaFileName = '.nomedia';

  final DeviceProtection protection;
  final bool isAndroid;
  final bool isIOS;

  /// 保護を掛ける。例外は投げない（掛けられなかった分は次の起動でやり直す）。
  ///
  /// 失敗を画面に出さないのは、ユーザーにできる対処が無いため（表示の話では
  /// ないので「黙って古い内容を見せない」の対象外）。
  Future<void> protect(AppDirectories directories) async {
    if (isAndroid) {
      // images/ に置くと `ImageCacheStore.sweepOrphanFiles` が「行の無い実体」
      // として消し、downloads/ に置くとログアウトの全削除（`deleteAllFiles`）が
      // 消す。メディアスキャナは親ディレクトリの .nomedia を尊重するので直下で足りる。
      // cache は OS / 設定アプリの「キャッシュを削除」で消えるので毎回置き直す。
      for (final directory in [directories.support, directories.cache]) {
        await _touchNoMedia(directory);
      }
    }
    if (isIOS) {
      try {
        final failed = await protection.excludeFromBackup([
          // downloads と background_downloader の Dart 側の記録（Bearer 入り）の親。
          // ネイティブ側が UserDefaults に置く未配信の記録はここでは外せない。
          directories.support,
          // support に付け損ねても、いちばん大きいものは確実に外す。
          directories.downloads,
          // drift DB（-wal / -shm も作り直されるのでファイルではなくディレクトリに付ける）。
          // 復元先で「ZIP は無いのに台帳はダウンロード済み」になるのを防ぐ。
          ?directories.documents,
          // Caches は元々バックアップ対象外だが、Issue の要件として明示する。
          directories.imageCache,
        ]);
        if (failed.isNotEmpty) {
          debugPrint('[storage] backup exclusion failed: $failed');
        }
      } on Object catch (error) {
        debugPrint('[storage] backup exclusion failed: $error');
      }
    }
  }

  Future<void> _touchNoMedia(Directory directory) async {
    try {
      if (!directory.existsSync()) return;
      final file = File(p.join(directory.path, noMediaFileName));
      if (!file.existsSync()) await file.create();
    } on FileSystemException catch (error) {
      debugPrint('[storage] .nomedia failed: $error');
    }
  }
}

@Riverpod(keepAlive: true)
StorageProtector storageProtector(Ref ref) => StorageProtector(
  protection: ref.watch(deviceProtectionProvider),
  isAndroid: Platform.isAndroid,
  isIOS: Platform.isIOS,
);

/// 起動時に 1 回、保護を掛ける（`ComicLazApp` が購読する）。
///
/// DB と background_downloader の記録は [appDirectoriesProvider] を経由せずに
/// 作られるので、置き場を使う機能の初期化とは別に、起動時に必ず走らせる。
/// 置き場を用意できなければ何もしない（次の起動でやり直す）。
@Riverpod(keepAlive: true)
Future<void> storageProtection(Ref ref) async {
  final AppDirectories directories;
  try {
    directories = await ref.watch(appDirectoriesProvider.future);
  } on Object catch (error) {
    debugPrint('[storage] directories unavailable: $error');
    return;
  }
  await ref.read(storageProtectorProvider).protect(directories);
}
