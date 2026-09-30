import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/device/app_resume_monitor.dart';
import '../../../core/device/connectivity_monitor.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/api/books_api.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../offline/application/offline_metadata_gateway.dart';
import '../data/safe_mode_revalidation_store.dart';
import '../domain/volume_download.dart';
import 'auto_delete_runner.dart';
import 'download_queue.dart';

part 'safe_mode_revalidator.g.dart';

/// `V2\BookController::show` が非公開 / 存在しないタイトルに返す 404 の本文の
/// `message`（`response()->json(['message' => 'Not Found'], 404)`）。
///
/// Laravel のルート欠けの 404 は「The route ... could not be found.」、プロキシの
/// 404 は HTML なので、これと一致しない 404 は「非公開」の証拠として扱わない。
const hiddenBookMessage = 'Not Found';

/// セーフモードの再検証で消した結果（画面が 1 回だけ知らせる）。
@immutable
class SafeModeRevalidationResult {
  const SafeModeRevalidationResult({required this.volumes});

  /// 消した巻の数。
  final int volumes;
}

/// セーフモードが ON になったあと、ダウンロード済みの巻を確かめ直す（#15）。
///
/// **自動削除（`AutoDeleteRunner`）とは別物**。あちらはユーザーが選んだ規則で
/// 読み終えた巻を消し、こちらは「サーバーがもう配信しない巻」を消す。
///
/// `safe_mode` の変更で一括削除はしない（同じユーザーの数 GB と、サーバーにも
/// 無い読書位置を黙って消さない。#11）。代わりにダウンロード済みの巻を持つ
/// タイトルを 1 件ずつ `GET /api/v2/books/{id}` で問い合わせ、**404 が返った
/// タイトルだけ**消す。サーバーは `is_unsafe` のタイトルをセーフモードの
/// ユーザーに 404 で返す（`V2\BookController::show` の `isHiddenBySafeMode`）。
///
/// 404 は「非公開」以外でも返る（プロキシの誤設定・ルートの欠け・DB の障害）ので、
/// 消すのは次の 3 つが揃ったタイトルだけにする（1 回の障害で数 GB を全部消さない）。
///   1. 404 の本文がコントローラの JSON（`{"message": "Not Found"}`）。
///   2. その回の問い合わせが通信エラー無しで最後まで終わった。
///   3. 一覧（`/api/books`。セーフモードでは `is_unsafe` を除いた版）が空でなく、
///      そのタイトルが載っていない。
///
/// - 通信エラー・タイムアウト・5xx・429・401・想定外の 404 では何も消さず、
///   予約を残して次の機会（前面復帰 / 回線復帰 / 次の起動・ログイン）にやり直す。
///   「オフラインか」は実際の通信結果で判断する（回線の監視は合図だけ）。
/// - 403 はリソース単位の権限エラーで、セーフモードの判定ではないので消さない。
/// - 200 なら、一覧に無い巻があっても消さない（`is_unsafe` はタイトル単位。
///   巻の欠けには処理中・削除など別の理由がありうる）。
/// - 巻単位の manifest ではなくタイトル単位の詳細を使うのは、問い合わせが
///   タイトル数で済み、manifest はサーバーで ZIP を開くことがあるため。
/// - いまビューアで開いている巻は消さずに予約を残す（読んでいる途中の ZIP を
///   消して表示を壊さない）。
///
/// state は直近に消した結果（何も消していなければ `null`）。
@Riverpod(keepAlive: true)
class SafeModeRevalidator extends _$SafeModeRevalidator {
  /// 走っている実行（1 本ずつにする。同じタイトルを重ねて問い合わせない）。
  Future<SafeModeRevalidationResult?>? _running;

  @override
  SafeModeRevalidationResult? build() {
    // 監視は read（watch にすると作り直しで購読が重なる）。
    final resumed = ref
        .read(appResumeMonitorProvider)
        .onResumed
        .listen((_) => _runQuietly('resumed'));
    ref.onDispose(resumed.cancel);
    final restored = ref
        .read(connectivityMonitorProvider)
        .onRestored
        .listen((_) => _runQuietly('restored'));
    ref.onDispose(restored.cancel);
    // 起動時の復元・ログインで予約が立つので、ログイン済みになったら走らせる
    // （起動時にすでにログイン済みなら最初の 1 回もここで拾う）。
    ref.listen(authControllerProvider, (previous, next) {
      if (next is! AuthAuthenticated) return;
      if (previous is AuthAuthenticated && previous.user == next.user) return;
      _runQuietly('signed-in');
    }, fireImmediately: true);
    return null;
  }

  /// 背景の実行。画面が無いので失敗はログに残すだけにする（次の契機でやり直す）。
  void _runQuietly(String trigger) {
    // build の中で state を触らないよう、次のマイクロタスクへ回す。
    scheduleMicrotask(() {
      if (!ref.mounted) return;
      unawaited(
        run().then<void>(
          (_) {},
          onError: (Object error) =>
              debugPrint('[safe-mode] $trigger failed: $error'),
        ),
      );
    });
  }

  /// 再検証を 1 回走らせる。消した結果（何も消さなければ `null`）を返す。
  Future<SafeModeRevalidationResult?> run() {
    if (_running case final running?) return running;
    final execution = _execute();
    _running = execution;
    return execution.whenComplete(() {
      if (identical(_running, execution)) _running = null;
    });
  }

  Future<SafeModeRevalidationResult?> _execute() async {
    final auth = ref.read(authControllerProvider);
    if (auth is! AuthAuthenticated) return null;
    final user = auth.user;
    final store = ref.read(safeModeRevalidationStoreProvider);
    if (!await store.isPending()) return null;
    if (!ref.mounted || !_isSameSession(user.id)) return null;
    if (!user.safeMode) {
      // 予約の後にまた OFF に戻った。隠すものは無いので問い合わせない。
      await store.clear();
      return null;
    }

    // 台帳の読み込みと起動時の照合を待つ（読み込み中に「台帳が空」と判断しない）。
    await ref.read(downloadQueueProvider.future);
    if (!ref.mounted) return null;
    await ref.read(downloadQueueProvider.notifier).reconciled;
    if (!ref.mounted) return null;
    final ledger = ref.read(downloadQueueProvider).value ?? const {};

    final api = ref.read(booksApiProvider);
    final isOpen = ref.read(openVolumeCheckProvider);
    final queue = ref.read(downloadQueueProvider.notifier);
    var keepPending = false;

    // 1. 問い合わせだけを先に済ませる。途中で通信が崩れた回の結果では
    //    1 件も消さない（不安定な接続での判断を半端に適用しない）。
    final notFound = <int>[];
    // 1 件ずつ順に問い合わせる（自宅サーバーの HDD を叩き続けない）。
    for (final bookId in ledgerBookIds(ledger).toList()..sort()) {
      if (!ref.mounted || !_isSameSession(user.id)) {
        // 途中でログアウト / ユーザー切り替え。前のユーザーの結果で次の
        // ユーザーの巻を消さない（予約はセッションの破棄で消える）。
        return null;
      }
      try {
        await api.fetchBookDetail(bookId);
      } on NotFoundException catch (error) {
        if (error.serverMessage != hiddenBookMessage) {
          // コントローラの応答ではない 404（プロキシの HTML / ルートの欠け）。
          // 「非公開」の証拠にならないので通信障害と同じく止めて予約を残す。
          // これを消す側に倒すと、経路の誤設定 1 つで全タイトルが消える。
          debugPrint(
            '[safe-mode] unexpected 404 at book $bookId '
            '(${error.serverMessage}); keeping reservation',
          );
          return null;
        }
        notFound.add(bookId);
      } on ForbiddenException {
        // リソース単位の権限エラー。セーフモードで隠されたのとは取り違えない。
      } on ApiException catch (error) {
        // 通信 / タイムアウト / 5xx / 429 / 401 など。何も消さず予約を残す
        // （401 は AuthInterceptor の失効処理に任せる）。
        debugPrint('[safe-mode] stopped at book $bookId: $error');
        return null;
      }
    }
    if (!ref.mounted || !_isSameSession(user.id)) return null;

    // 2. 消す前に一覧（セーフモードのユーザーには is_unsafe を除いた
    //    books_safe.json が返る）と突き合わせる。詳細の 404 と「一覧にも無い」
    //    の 2 つが揃ったタイトルだけ消す。サーバーの DB が空に見えるなどの
    //    障害で詳細が軒並み 404 になっても、一覧が空なら消さない。
    final Set<int> hidden;
    if (notFound.isEmpty) {
      hidden = const {};
    } else {
      final Set<int> catalog;
      try {
        catalog = {...?(await api.fetchBooks()).value?.map((book) => book.id)};
      } on ApiException catch (error) {
        debugPrint('[safe-mode] catalog check failed: $error');
        return null;
      }
      if (!ref.mounted || !_isSameSession(user.id)) return null;
      if (catalog.isEmpty) {
        debugPrint('[safe-mode] catalog is empty; keeping reservation');
        return null;
      }
      hidden = {
        for (final bookId in notFound)
          if (!catalog.contains(bookId)) bookId,
      };
      // 一覧に載っているのに詳細は 404（静的 JSON の書き換え待ちなど）。
      // どちらが正しいか分からないので消さず、次の契機で確かめ直す。
      if (hidden.length != notFound.length) keepPending = true;
    }

    // 3. 消す。
    var removed = 0;
    for (final bookId in hidden) {
      // 問い合わせの間に変わっているかもしれないので、今の台帳から選ぶ。
      final current = ref.read(downloadQueueProvider).value ?? const {};
      for (final download in current.values) {
        if (download.bookId != bookId) continue;
        if (isOpen(download.volumeId)) {
          keepPending = true;
          continue;
        }
        try {
          await queue.remove(download.volumeId);
          removed++;
        } on Object catch (error) {
          debugPrint('[safe-mode] remove ${download.volumeId} failed: $error');
          keepPending = true;
        }
        if (!ref.mounted || !_isSameSession(user.id)) return null;
      }
    }

    final result = await _finish(removed);
    if (!keepPending && ref.mounted && _isSameSession(user.id)) {
      await store.clear();
    }
    return result;
  }

  /// 消した分の後始末をして結果を返す（消していなければ `null`）。
  Future<SafeModeRevalidationResult?> _finish(int removed) async {
    if (removed == 0) return null;
    try {
      // 消したタイトルの詳細・巻情報・サムネイルの保護印を残さない。
      await ref.read(offlineMetadataGatewayProvider).prune();
    } on Object catch (error) {
      // 控えの掃除は次の一覧の読み込みでもやり直される。
      debugPrint('[safe-mode] prune failed: $error');
    }
    final result = SafeModeRevalidationResult(volumes: removed);
    // 黙って消さない（`ComicLazApp` が SnackBar で知らせる）。
    if (ref.mounted) state = result;
    return result;
  }

  bool _isSameSession(int userId) {
    final auth = ref.read(authControllerProvider);
    return auth is AuthAuthenticated && auth.user.id == userId;
  }
}
