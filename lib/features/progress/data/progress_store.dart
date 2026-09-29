import 'package:drift/drift.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/storage/app_database.dart';
import '../domain/reading_progress.dart';

part 'progress_store.g.dart';

/// 読書進捗のローカル保存先（#12）。
///
/// テストから差し替えられるように抽象を切る（[LibraryCacheStore] と同じ方針）。
abstract interface class ProgressStore {
  /// ページ送りごとの保存（未送信として上書きする）。
  Future<void> save({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  });

  Future<ReadingProgress?> find(int volumeId);

  /// 全件（巻 ID をキーにした表）。
  Future<Map<int, ReadingProgress>> loadAll();

  /// 未送信の行（古い順）。[limit] は一括同期 API の上限に合わせる。
  Future<List<ReadingProgress>> pending({required int limit});

  /// サーバー側の値でローカルへ書き戻し、送信済みにする。
  ///
  /// 採用された（`applied`）行にも、サーバーの方が新しかった（`stale`）行にも
  /// 使う。サーバーの値を正にすれば、丸めや競合の結果で食い違わない。
  ///
  /// 送ったときの行（[sentReadAt] と [sentCurrentPage]）から変わっていない
  /// ときだけ書く。送信の往復中に読み進めていた場合は**新しい進捗を未送信の
  /// まま残す**（上書きすると最新ページが消え、送信済み扱いで二度と
  /// 送られない）。書いたら `true`。
  ///
  /// `read_at` だけでは守れない。drift も MySQL の TIMESTAMP も秒精度なので、
  /// **同じ秒に入ったページ送り**は送った行と時刻では区別できない。何ページを
  /// 送ったかまで見て初めて「往復中に進んだ」と分かる。
  Future<bool> overwriteFromServer({
    required int volumeId,
    required DateTime sentReadAt,
    required int sentCurrentPage,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  });

  /// 未送信の行の `read_at` だけを付け替える（ページと `synced` は触らない）。
  ///
  /// 秒精度の `read_at` のままでは送れない行を送れるようにするために使う。
  ///
  /// - サーバーが**同じ秒**の記録を持っていると、比較が「より新しいときだけ
  ///   採用」なので何度送っても `stale` になる。1 秒進めて勝たせる。
  /// - 端末時計が進みすぎていると `future_read_at` で棄却されるので、応答の
  ///   `Date` ヘッダで分かったサーバー時刻に合わせ直す（サーバーの
  ///   `UserVolumeStatusService` のコメントが指示している手順）。
  ///
  /// 送ったときの行から変わっていたら（往復中に読み進めた）何もせず `false`。
  Future<bool> rebaseReadAt({
    required int volumeId,
    required DateTime sentReadAt,
    required int sentCurrentPage,
    required DateTime readAt,
  });

  /// 行を捨てる（巻が消えた / セーフモードで見えない）。
  Future<void> delete(int volumeId);

  /// 全部捨てる（ログアウト）。
  Future<void> deleteAll();
}

class DriftProgressStore implements ProgressStore {
  const DriftProgressStore(this._database);

  final AppDatabase _database;

  @override
  Future<void> save({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  }) async {
    // 0 ページの巻（ZIP 無し）は読めないので記録しない。送ると max_page の
    // 検証（min:1）で 422 になるし、他端末の進捗を 0 ページで潰しかねない。
    if (maxPage < 1) return;
    await _database
        .into(_database.readingProgresses)
        .insertOnConflictUpdate(
          ReadingProgressRow(
            volumeId: volumeId,
            currentPage: currentPage.clamp(1, maxPage),
            maxPage: maxPage,
            readAt: readAt,
            synced: false,
          ),
        );
  }

  @override
  Future<ReadingProgress?> find(int volumeId) async {
    final row = await (_database.select(
      _database.readingProgresses,
    )..where((table) => table.volumeId.equals(volumeId))).getSingleOrNull();
    return row == null ? null : ReadingProgress.fromRow(row);
  }

  @override
  Future<Map<int, ReadingProgress>> loadAll() async {
    final rows = await _database.select(_database.readingProgresses).get();
    return {for (final row in rows) row.volumeId: ReadingProgress.fromRow(row)};
  }

  @override
  Future<List<ReadingProgress>> pending({required int limit}) async {
    final rows =
        await (_database.select(_database.readingProgresses)
              ..where((table) => table.synced.equals(false))
              // 古い順に送る（打ち切られても古い巻から片付く）。
              ..orderBy([(table) => OrderingTerm.asc(table.readAt)])
              ..limit(limit))
            .get();
    return [for (final row in rows) ReadingProgress.fromRow(row)];
  }

  @override
  Future<bool> overwriteFromServer({
    required int volumeId,
    required DateTime sentReadAt,
    required int sentCurrentPage,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  }) async {
    final updated = await _updateSentRow(
      volumeId: volumeId,
      sentReadAt: sentReadAt,
      sentCurrentPage: sentCurrentPage,
      values: ReadingProgressesCompanion(
        currentPage: Value(currentPage),
        maxPage: Value(maxPage),
        readAt: Value(readAt),
        synced: const Value(true),
      ),
    );
    return updated > 0;
  }

  @override
  Future<bool> rebaseReadAt({
    required int volumeId,
    required DateTime sentReadAt,
    required int sentCurrentPage,
    required DateTime readAt,
  }) async {
    final updated = await _updateSentRow(
      volumeId: volumeId,
      sentReadAt: sentReadAt,
      sentCurrentPage: sentCurrentPage,
      values: ReadingProgressesCompanion(readAt: Value(readAt)),
    );
    return updated > 0;
  }

  /// 送ったときの内容から変わっていない行だけを書き換える。
  Future<int> _updateSentRow({
    required int volumeId,
    required DateTime sentReadAt,
    required int sentCurrentPage,
    required ReadingProgressesCompanion values,
  }) =>
      (_database.update(_database.readingProgresses)..where(
            (table) =>
                table.volumeId.equals(volumeId) &
                table.readAt.equals(sentReadAt) &
                table.currentPage.equals(sentCurrentPage),
          ))
          .write(values);

  @override
  Future<void> delete(int volumeId) async {
    await (_database.delete(
      _database.readingProgresses,
    )..where((table) => table.volumeId.equals(volumeId))).go();
  }

  @override
  Future<void> deleteAll() async {
    await _database.delete(_database.readingProgresses).go();
  }
}

@Riverpod(keepAlive: true)
ProgressStore progressStore(Ref ref) =>
    DriftProgressStore(ref.watch(appDatabaseProvider));
