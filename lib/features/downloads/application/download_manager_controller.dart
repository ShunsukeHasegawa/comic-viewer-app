import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/api/books_api.dart';
import '../../../domain/models/book.dart';
import '../../../domain/models/book_detail.dart';
import '../../library/application/library_controller.dart';
import '../../library/data/library_repository.dart';
import '../../offline/application/offline_detail_warmer.dart';
import '../../offline/application/offline_metadata_gateway.dart';
import '../domain/download_manager_view.dart';
import '../domain/volume_download.dart';
import 'download_queue.dart';

part 'download_manager_controller.g.dart';

/// ダウンロード管理画面に重ねるタイトル情報。
///
/// 1 タイトルの控えが読めなくても他のタイトルは出したいので、失敗は
/// 例外ではなくここに持つ（画面は台帳だけで行を描き、失敗を知らせる）。
@immutable
class DownloadTitleCatalog {
  const DownloadTitleCatalog({
    this.titles = const {},
    this.failedBookIds = const {},
    this.error,
  });

  /// book ID → タイトル情報。無いタイトルは画面が ID で表示する。
  final Map<int, DownloadTitleInfo> titles;

  /// 控えの読み込みに失敗したタイトル。
  final Set<int> failedBookIds;

  /// 最初に起きた失敗（画面の文言用）。
  final Object? error;

  bool get hasFailure => failedBookIds.isNotEmpty;
}

/// ダウンロード管理画面のタイトル名・巻数・サーバー側の `files_version`。
///
/// **開いただけではネットワークに出ない**（自宅サーバーの HDD を起こさない・
/// 圏外でも即座に出す）。端末の控え（`OfflineMetadataGateway`）と一覧の控え
/// だけで組み立て、サーバーへの確認はユーザー操作（[refreshFromServer]）に限る。
@Riverpod(retry: noAutoRetry)
class DownloadManagerTitles extends _$DownloadManagerTitles {
  /// 「更新を確認」で取った詳細。
  ///
  /// 控えは「インストール済みの巻を持つタイトル」しか保存されない
  /// （初回の取得中のタイトルは弾かれる）ので、取れた分はここにも残して
  /// 作り直しの後も使う。
  final _fetched = <int, BookDetail>{};

  @override
  Future<DownloadTitleCatalog> build() async {
    // 台帳の**タイトル集合**が変わったときだけ作り直す。進捗が届くたびに
    // 控えを読み直さないよう、`==` で比べられる値（ID を昇順に連結した
    // 文字列）で select する（Set / List は同一性の比較なので毎回作り直しになる）。
    final key = ref.watch(
      downloadQueueProvider.select((ledger) => _bookIdsKey(ledger.value)),
    );
    // 初めて落としたタイトルの詳細の控えは、最初の巻の完了後にできる。
    // タイトル集合は変わらないので、控えが書かれた合図でも読み直す
    // （端末の控えを読むだけで、ネットワークには出ない）。
    ref.watch(offlineDetailRevisionProvider);
    final bookIds = _parseKey(key);
    if (bookIds.isEmpty) return const DownloadTitleCatalog();

    final gateway = ref.read(offlineMetadataGatewayProvider);
    final titles = <int, DownloadTitleInfo>{};
    final failed = <int>{};
    Object? firstError;

    for (final bookId in bookIds) {
      if (_fetched[bookId] case final detail?) {
        titles[bookId] = DownloadTitleInfo.fromDetail(detail);
        continue;
      }
      try {
        final detail = await gateway.readBookDetail(bookId);
        if (detail != null) {
          titles[bookId] = DownloadTitleInfo.fromDetail(detail);
        }
      } on Object catch (error) {
        // 1 タイトルの失敗で他のタイトル名まで消さない。
        failed.add(bookId);
        firstError ??= error;
      }
      if (!ref.mounted) return const DownloadTitleCatalog();
    }

    // 詳細の控えが無いタイトル（初回の取得中など）は一覧の控えで名前を補う。
    final missing = [
      for (final bookId in bookIds)
        if (titles[bookId]?.title == null && !failed.contains(bookId)) bookId,
    ];
    if (missing.isNotEmpty) {
      try {
        final snapshot = await ref.read(libraryCacheStoreProvider).read();
        if (!ref.mounted) return const DownloadTitleCatalog();
        final books = {
          for (final book in snapshot?.books ?? const <Book>[]) book.id: book,
        };
        for (final bookId in missing) {
          if (books[bookId] case final book?) {
            titles[bookId] = DownloadTitleInfo.fromBook(book);
          }
        }
      } on Object catch (error) {
        if (!ref.mounted) return const DownloadTitleCatalog();
        failed.addAll(missing);
        firstError ??= error;
      }
    }

    return DownloadTitleCatalog(
      titles: titles,
      failedBookIds: failed,
      error: firstError,
    );
  }

  /// ユーザー操作の「更新を確認」。
  ///
  /// 台帳にあるタイトルの詳細をサーバーから取り直し、端末の控えを更新する
  /// （「更新あり」はサーバー側の `files_version` との比較なので、控えが古いと
  /// 気づけない）。自宅サーバーへ並列に投げないよう 1 タイトルずつ取る。
  ///
  /// 失敗があれば最初のエラーを返す（画面が SnackBar で知らせる）。一部が
  /// 失敗しても、取れた分は反映する。表示中の内容は消さない。
  ///
  /// 連打やプル中の再操作でも、自宅サーバーへの取り直しは 1 回だけにする
  /// （走っている確認の結果を一緒に待つ）。
  Future<Object?> refreshFromServer() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  /// 走っている「更新を確認」。
  Future<Object?>? _refreshing;

  Future<Object?> _refresh() async {
    // 最初の build が控えを読んでいる最中に反映すると、build の完了で
    // 上書きされて「更新あり」が消える。先に build の完了を待つ。
    try {
      await future;
    } on Object {
      // 控えの読み込みの失敗は、取り直した分で上書きする。
    }
    if (!ref.mounted) return null;
    final ledger = ref.read(downloadQueueProvider).value;
    if (ledger == null || ledger.isEmpty) return null;
    final bookIds = ledgerBookIds(ledger).toList()..sort();

    final api = ref.read(booksApiProvider);
    final gateway = ref.read(offlineMetadataGatewayProvider);
    final fetched = <int, BookDetail>{};
    Object? firstError;

    for (final bookId in bookIds) {
      final BookDetail detail;
      try {
        detail = await api.fetchBookDetail(bookId);
      } on Object catch (error) {
        firstError ??= error;
        if (!ref.mounted) return firstError;
        continue;
      }
      if (!ref.mounted) return firstError;
      fetched[bookId] = detail;
      // 取れた時点で残す。確認の途中に作り直し（台帳のタイトル集合の変化 /
      // 控えの書き込み）が走っても、その build が取れた分を使えるように。
      _fetched[bookId] = detail;
      try {
        await gateway.saveBookDetail(detail);
      } on Object catch (error) {
        // 控えに書けなくても、この画面の表示はメモリの分で正しく出せる。
        // 圏外で開いたときの控えは次の完了 / 詳細画面で取り直される。
        debugPrint('[downloads] save book detail failed: $error');
      }
      if (!ref.mounted) return firstError;
    }

    if (fetched.isEmpty) return firstError;

    final current = state.value ?? const DownloadTitleCatalog();
    // 取り直せたタイトルは、控えの読み込み失敗からも外す。
    final stillFailed = current.failedBookIds.difference(fetched.keys.toSet());
    state = AsyncData(
      DownloadTitleCatalog(
        titles: {
          ...current.titles,
          for (final MapEntry(key: bookId, value: detail) in fetched.entries)
            bookId: DownloadTitleInfo.fromDetail(detail),
        },
        failedBookIds: stillFailed,
        error: stillFailed.isEmpty ? null : current.error,
      ),
    );
    return firstError;
  }
}

String _bookIdsKey(Map<int, VolumeDownload>? ledger) {
  if (ledger == null) return '';
  return (ledgerBookIds(ledger).toList()..sort()).join(',');
}

List<int> _parseKey(String key) =>
    key.isEmpty ? const [] : [for (final id in key.split(',')) int.parse(id)];
