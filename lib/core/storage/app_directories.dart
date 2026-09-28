import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_directories.g.dart';

/// アプリ専用のデータ置き場。
///
/// コミック画像は**アプリ専用領域**に置く（共有ストレージやギャラリーに出さない）。
/// 詳細な保護（`.nomedia` / バックアップ除外）は #15 で詰める。
class AppDirectories {
  const AppDirectories({required this.support, required this.cache});

  /// 明示的にダウンロードしたデータ（自動削除しない）。
  ///
  /// Android: `getApplicationSupportDirectory()` / iOS: `Library/Application Support`
  final Directory support;

  /// 一時キャッシュ（OS が必要に応じて消してよい領域）。
  ///
  /// Android: `getApplicationCacheDirectory()` / iOS: `Library/Caches`
  final Directory cache;

  /// ページ / サムネイルの一時キャッシュ置き場。
  Directory get imageCache => Directory(p.join(cache.path, 'images'));

  /// ダウンロード済みの巻の置き場（#9）。
  Directory get downloads => Directory(p.join(support.path, 'downloads'));

  /// 必要なディレクトリを作る。
  Future<void> ensureCreated() async {
    for (final directory in [support, cache, imageCache, downloads]) {
      if (!directory.existsSync()) await directory.create(recursive: true);
    }
  }
}

@Riverpod(keepAlive: true)
Future<AppDirectories> appDirectories(Ref ref) async {
  final directories = AppDirectories(
    support: await getApplicationSupportDirectory(),
    cache: await getApplicationCacheDirectory(),
  );
  await directories.ensureCreated();
  return directories;
}
