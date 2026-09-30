import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/domain/models/book.dart';
import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/domain/models/user.dart';
import 'package:comic_laz/features/auth/application/auth_controller.dart';
import 'package:comic_laz/features/auth/domain/auth_state.dart';
import 'package:comic_laz/features/downloads/application/safe_mode_revalidator.dart';
import 'package:comic_laz/features/downloads/data/safe_mode_revalidation_store.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/api_fakes.dart';
import '../../support/auth_fakes.dart';
import '../../support/progress_fakes.dart';
import '../../support/storage_fakes.dart';
import '../../support/test_scope.dart';

final _safeUser = testUser.copyWith(safeMode: true);

/// コントローラが非公開のタイトルに返す 404（JSON の `{"message": "Not Found"}`）。
const _hidden = NotFoundException(serverMessage: hiddenBookMessage);

VolumeDownload _completed(int volumeId, {required int bookId}) =>
    VolumeDownload(
      volumeId: volumeId,
      bookId: bookId,
      filesVersion: 5,
      status: VolumeDownloadStatus.completed,
      pageCount: 10,
      totalBytes: 100,
    );

/// タイトルごとに応答（[BookDetail] か例外）を決められる API。
class _ScriptedBooksApi extends FakeBooksApi {
  // 一覧（books_safe.json）は既定で「台帳に無い安全なタイトルが 1 件ある」状態。
  _ScriptedBooksApi(this.responses) : super(books: const [Book(id: 100)]);

  /// bookId → 応答。載っていないタイトルは 200（巻なしの詳細）。
  final Map<int, Object> responses;

  int _inFlight = 0;

  /// 同時に走った問い合わせの最大数。
  int maxInFlight = 0;

  @override
  Future<BookDetail> fetchBookDetail(int bookId) async {
    fetchBookDetailCalls.add(bookId);
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      await onFetchBookDetail?.call(bookId);
      await Future<void>.delayed(Duration.zero);
      final response = responses[bookId] ?? BookDetail(id: bookId);
      if (response is BookDetail) return response;
      throw response;
    } finally {
      _inFlight--;
    }
  }
}

/// 再検証を動かす一式（台帳・API・控え・前面復帰・回線はすべてフェイク）。
class _Harness {
  _Harness({
    Map<int, VolumeDownload> ledger = const {},
    Map<int, Object> responses = const {},
    bool pending = true,
    User? user,
  }) : queue = RecordingDownloadQueue(initial: ledger),
       api = _ScriptedBooksApi({...responses}),
       store = InMemorySafeModeRevalidationStore(pending: pending),
       authStore = FakeAuthStore(token: 'valid', user: user ?? _safeUser),
       user = user ?? _safeUser;

  final RecordingDownloadQueue queue;
  final _ScriptedBooksApi api;
  final InMemorySafeModeRevalidationStore store;
  final FakeAuthStore authStore;
  final User user;
  final gateway = RecordingOfflineMetadataGateway();
  final lifecycle = FakeAppResumeMonitor();
  final connectivity = FakeConnectivityMonitor();
  final open = <int>{};

  late final ProviderContainer container;

  /// 起動してログイン済みになるまで進め、最初の再検証が落ち着くのを待つ。
  Future<ProviderContainer> start() async {
    final authApi = MockAuthApi()..stubCurrentUser(user);
    when(authApi.deleteToken).thenAnswer((_) async {});
    container = createContainer(
      authStore: authStore,
      authApi: authApi,
      booksApi: api,
      downloadQueue: () => queue,
      offlineMetadata: gateway,
      openVolumeCheck: open.contains,
      appResumeMonitor: lifecycle,
      connectivityMonitor: connectivity,
      safeModeRevalidationStore: store,
    );
    addTearDown(container.dispose);
    // アプリと同じく購読しておく（ComicLazApp が listen している）。
    container.listen(safeModeRevalidatorProvider, (_, _) {});
    await settleAuth(container);
    await settle();
    return container;
  }

  Future<void> settle() => pumpEventQueue(times: 50);
}

void main() {
  test('詳細が 404 のタイトルのダウンロードを削除する（セーフモードで隠された巻を手元に残さないため）', () async {
    final harness = _Harness(
      ledger: {
        1: _completed(1, bookId: 7),
        2: _completed(2, bookId: 7),
        3: _completed(3, bookId: 8),
      },
      responses: {7: _hidden},
    );

    final container = await harness.start();

    expect(harness.queue.removed, unorderedEquals([1, 2]));
    expect(harness.store.pending, isFalse, reason: '前面復帰のたびに問い合わせ直さない');
    expect(container.read(safeModeRevalidatorProvider)?.volumes, 2);
  });

  test('消したあとにオフライン用メタ情報を掃除する（隠されたタイトルの詳細・サムネの保護印を残さないため）', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bookId: 7)},
      responses: {7: _hidden},
    );

    await harness.start();

    expect(harness.gateway.pruneCount, 1);
  });

  test('通信エラーでは何も消さず、予約を残す（圏外で数 GB を消さないため）', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bookId: 7)},
      responses: {7: const NetworkException()},
    );

    await harness.start();

    expect(harness.queue.removed, isEmpty);
    expect(harness.store.pending, isTrue);
  });

  for (final error in [
    const ServerException(statusCode: 503),
    const TooManyRequestsException(),
    const ApiTimeoutException(),
  ]) {
    test('${error.runtimeType} でも何も消さず、予約を残す（サーバー障害を「非公開」と取り違えないため）', () async {
      final harness = _Harness(
        ledger: {1: _completed(1, bookId: 7), 2: _completed(2, bookId: 8)},
        responses: {7: error, 8: _hidden},
      );

      await harness.start();

      expect(harness.queue.removed, isEmpty);
      expect(harness.store.pending, isTrue);
      expect(harness.api.fetchBookDetailCalls, [7], reason: '障害中のサーバーを叩き続けない');
    });
  }

  test('401 なら中断して予約を残す（失効処理に任せ、判断を次のセッションに持ち越さないため）', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bookId: 7), 2: _completed(2, bookId: 8)},
      responses: {7: const UnauthorizedException(), 8: _hidden},
    );

    await harness.start();

    expect(harness.queue.removed, isEmpty);
    expect(harness.store.pending, isTrue);
  });

  test('403 のタイトルは消さずに次へ進む（リソース単位の権限エラーはセーフモードの判定ではないため）', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bookId: 7), 2: _completed(2, bookId: 8)},
      responses: {7: const ForbiddenException(), 8: _hidden},
    );

    await harness.start();

    expect(harness.queue.removed, [2]);
  });

  test(
    '詳細が 200 なら、一覧に無い巻があっても消さない（is_unsafe はタイトル単位で、巻の欠けには別の理由がありうるため）',
    () async {
      final harness = _Harness(
        ledger: {1: _completed(1, bookId: 7)},
        // 詳細に巻 1 が載っていない。
        responses: {7: const BookDetail(id: 7)},
      );

      await harness.start();

      expect(harness.queue.removed, isEmpty);
      expect(harness.store.pending, isFalse);
    },
  );

  test('タイトルは 1 件ずつ順に問い合わせる（自宅サーバーの HDD を叩き続けないため）', () async {
    final harness = _Harness(
      ledger: {
        1: _completed(1, bookId: 7),
        2: _completed(2, bookId: 8),
        3: _completed(3, bookId: 9),
      },
    );

    await harness.start();

    expect(harness.api.fetchBookDetailCalls, [7, 8, 9]);
    expect(harness.api.maxInFlight, 1);
  });

  test('いま開いている巻は消さずに予約を残す（読んでいる途中の ZIP を消して表示を壊さないため）', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bookId: 7), 2: _completed(2, bookId: 7)},
      responses: {7: _hidden},
    )..open.add(1);

    await harness.start();

    expect(harness.queue.removed, [2]);
    expect(harness.store.pending, isTrue, reason: '閉じた後の契機で消せるように');
  });

  test('途中でログアウトしたら残りを確かめない（前のユーザーの結果で次のユーザーの巻を消さないため）', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bookId: 7), 2: _completed(2, bookId: 8)},
      responses: {7: _hidden, 8: _hidden},
    );
    harness.api.onFetchBookDetail = (bookId) async {
      if (bookId != 7) return;
      await harness.container.read(authControllerProvider.notifier).logout();
    };

    await harness.start();

    expect(
      harness.container.read(authControllerProvider),
      isA<AuthUnauthenticated>(),
    );
    expect(harness.api.fetchBookDetailCalls, [7]);
    expect(harness.queue.removed, isEmpty);
  });

  test('予約が無ければサーバーに問い合わせない', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bookId: 7)},
      pending: false,
    );

    await harness.start();
    harness.lifecycle.resume();
    await harness.settle();

    expect(harness.api.fetchBookDetailCalls, isEmpty);
  });

  test('予約の後にセーフモードが OFF に戻っていれば、問い合わせずに予約を消す（隠すものが無いため）', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bookId: 7)},
      user: testUser,
    );

    await harness.start();

    expect(harness.api.fetchBookDetailCalls, isEmpty);
    expect(harness.store.pending, isFalse);
  });

  test('通信エラーで止まったら、前面復帰でやり直す', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bookId: 7)},
      responses: {7: const NetworkException()},
    );
    await harness.start();
    expect(harness.store.pending, isTrue);

    harness.api.responses[7] = _hidden;
    harness.lifecycle.resume();
    await harness.settle();

    expect(harness.queue.removed, [1]);
    expect(harness.store.pending, isFalse);
  });

  test('回線が戻ったらやり直す（圏外起動のまま放っておかないため）', () async {
    final harness = _Harness(
      ledger: {1: _completed(1, bookId: 7)},
      responses: {7: const NetworkException()},
    );
    await harness.start();

    harness.api.responses[7] = _hidden;
    harness.connectivity.restore();
    await harness.settle();

    expect(harness.queue.removed, [1]);
  });

  group('404 の出どころの確認（経路の障害で全部消さない）', () {
    test('JSON でない 404（プロキシの HTML など）では何も消さず、予約を残す', () async {
      final harness = _Harness(
        ledger: {1: _completed(1, bookId: 7), 2: _completed(2, bookId: 8)},
        // content-type が JSON でない 404 は serverMessage が null になる。
        responses: {7: const NotFoundException(), 8: const NotFoundException()},
      );

      await harness.start();

      expect(harness.queue.removed, isEmpty, reason: '経路の誤設定 1 つで数 GB を消さない');
      expect(harness.store.pending, isTrue);
      expect(harness.api.fetchBookDetailCalls, [7], reason: '障害中の経路を叩き続けない');
    });

    test('ルートが無いときの 404（Laravel の別の文言）も「非公開」とみなさない', () async {
      final harness = _Harness(
        ledger: {1: _completed(1, bookId: 7)},
        responses: {
          7: const NotFoundException(
            serverMessage: 'The route api/v2/books/7 could not be found.',
          ),
        },
      );

      await harness.start();

      expect(harness.queue.removed, isEmpty);
      expect(harness.store.pending, isTrue);
    });

    test(
      '後のタイトルで通信エラーになったら、先に 404 だったタイトルも消さない（不安定な回の判断を半端に適用しないため）',
      () async {
        final harness = _Harness(
          ledger: {1: _completed(1, bookId: 7), 2: _completed(2, bookId: 8)},
          responses: {7: _hidden, 8: const NetworkException()},
        );

        await harness.start();

        expect(harness.queue.removed, isEmpty);
        expect(harness.store.pending, isTrue);
      },
    );

    test('一覧が空なら消さない（DB の障害で詳細が軒並み 404 になった状況と区別できないため）', () async {
      final harness = _Harness(
        ledger: {1: _completed(1, bookId: 7)},
        responses: {7: _hidden},
      );
      harness.api.books = const [];

      await harness.start();

      expect(harness.queue.removed, isEmpty);
      expect(harness.store.pending, isTrue);
    });

    test('一覧を取れなければ消さない（突き合わせができないまま消さないため）', () async {
      final harness = _Harness(
        ledger: {1: _completed(1, bookId: 7)},
        responses: {7: _hidden},
      );
      harness.api.error = const NetworkException();

      await harness.start();

      expect(harness.queue.removed, isEmpty);
      expect(harness.store.pending, isTrue);
    });

    test('一覧に載っているタイトルは詳細が 404 でも消さず、予約を残す（食い違いは次の契機で確かめ直すため）', () async {
      final harness = _Harness(
        ledger: {1: _completed(1, bookId: 7), 2: _completed(2, bookId: 8)},
        responses: {7: _hidden, 8: _hidden},
      );
      harness.api.books = const [Book(id: 7)];

      await harness.start();

      expect(harness.queue.removed, [2]);
      expect(harness.store.pending, isTrue);
    });

    test('404 が無ければ一覧は取りに行かない（再検証のたびに一覧を落とさないため）', () async {
      final harness = _Harness(ledger: {1: _completed(1, bookId: 7)});

      await harness.start();

      expect(harness.api.fetchBooksCount, 0);
      expect(harness.store.pending, isFalse);
    });
  });

  group('予約の保存', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
    });

    test('予約は DB に残る（途中でアプリが落ちても次の起動でやり直すため）', () async {
      final store = DriftSafeModeRevalidationStore(database);
      expect(await store.isPending(), isFalse);

      await store.schedule();
      expect(
        await DriftSafeModeRevalidationStore(database).isPending(),
        isTrue,
      );

      await store.clear();
      expect(await store.isPending(), isFalse);
    });

    test('ログアウトで予約も消える（次のユーザーに持ち越さないため）', () async {
      final store = InMemorySafeModeRevalidationStore(pending: true);
      final purger = SafeModeRevalidationPurger(() => store);

      await purger.purgeSessionData();

      expect(store.pending, isFalse);
    });

    test('safe_mode の変更（取り直せるものだけの破棄）では予約を消さない', () {
      final purger = SafeModeRevalidationPurger(
        InMemorySafeModeRevalidationStore.new,
      );

      expect(
        purger.purgesRefetchableOnly,
        isFalse,
        reason: '立てたばかりの予約がその場で消えてしまう',
      );
    });
  });
}
