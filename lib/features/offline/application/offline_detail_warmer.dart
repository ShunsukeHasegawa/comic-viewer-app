import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/api/books_api.dart';
import 'offline_metadata_gateway.dart';

part 'offline_detail_warmer.g.dart';

/// ダウンロードが終わったタイトルの詳細を控える（#11 のレビュー指摘）。
///
/// 詳細は `BookDetailController` からも控えているが、あの画面は autoDispose なので
/// **ダウンロードを始めてすぐ一覧へ戻る**と破棄され、完了時には誰も控えない。
/// 取得時点ではまだ未ダウンロードなので `saveBookDetail` のゲートでも弾かれており、
/// 結果として「圏外で一覧には出るのに詳細が開けない（= 読める巻に到達できない）」
/// タイトルができてしまう。そこで画面に依存しない完了処理
/// （`DownloadQueue._complete`）からも控える。
///
/// 完了した直後なので通信はできている。失敗しても呼び出し側は無視してよい
/// （次にオンラインで詳細を開いたときに控えられる）。
typedef OfflineDetailWarmer = Future<void> Function(int bookId);

@Riverpod(keepAlive: true)
OfflineDetailWarmer offlineDetailWarmer(Ref ref) => (bookId) async {
  // 控えがあっても取り直す。巻が増えていると古い控えには新しい巻が無く、
  // 圏外でその巻へ到達できない（詳細から `ReadVolume` を組み立てるため）。
  final detail = await ref.read(booksApiProvider).fetchBookDetail(bookId);
  await ref.read(offlineMetadataGatewayProvider).saveBookDetail(detail);
  // 初めて落としたタイトルの控えは、最初の巻が完了した後のここで初めて
  // できる。開いたままのダウンロード管理画面は台帳のタイトル集合が
  // 変わらないので作り直されず、巻数の代わりに ID を出し続けてしまう。
  // 読み直すきっかけを渡す（画面の側は端末の控えを読むだけ）。
  if (ref.mounted) ref.read(offlineDetailRevisionProvider.notifier).bump();
};

/// ダウンロード完了で詳細の控えを書いた回数（読み直しの合図）。
@Riverpod(keepAlive: true)
class OfflineDetailRevision extends _$OfflineDetailRevision {
  @override
  int build() => 0;

  void bump() => state++;
}
