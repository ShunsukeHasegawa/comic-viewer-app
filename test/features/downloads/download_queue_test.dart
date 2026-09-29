import 'dart:async';
import 'dart:typed_data';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/downloads/application/download_queue.dart';
import 'package:comic_laz/features/downloads/data/archive_verifier.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/download_fakes.dart';

/// テスト対象の巻。
const volumeId = 340;
const bookId = 12;

void main() {
  /// 直近に組み立てたキュー（[settle] が「落ち着いたか」を見るのに使う）。
  ProviderContainer? active;

  /// キューが落ち着くまで待つ。実ファイル I/O と ZIP 検証を通すため、
  /// 固定回数ではなく状態で待つ（[settleDownloads] のコメント参照）。
  Future<void> settle() => settleDownloads(active!);

  /// 3 ページの ZIP を配るキュー一式。
  ({DownloadHarness harness, ProviderContainer container, DownloadQueue queue})
  setUpQueue({
    Uint8List? archiveBytes,
    int pageCount = 3,
    int? archiveBytesOverride,
    int filesVersion = 111,
    int concurrency = 1,
    ArchiveVerifier? verifier,
  }) {
    final bytes = archiveBytes ?? zipWithPages(3);
    final harness = DownloadHarness.create(
      manifest: testManifest(
        id: volumeId,
        bookId: bookId,
        filesVersion: filesVersion,
        archiveBytes: archiveBytesOverride ?? bytes.length,
        pageCount: pageCount,
      ),
      archiveBytes: bytes,
    )..verifier = verifier;
    final container = ProviderContainer(
      overrides: harness.overrides(concurrency: concurrency),
    );
    addTearDown(container.dispose);
    active = container;
    return (
      harness: harness,
      container: container,
      queue: container.read(downloadQueueProvider.notifier),
    );
  }

  VolumeDownload? downloadOf(
    ProviderContainer container, [
    int id = volumeId,
  ]) => container.read(downloadQueueProvider).value?[id];

  group('ダウンロード', () {
    test('検証を通ったら一時ファイルから rename して「ダウンロード済み」になる', () async {
      final scope = setUpQueue();

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(download.receivedBytes, download.totalBytes);
      expect(download.pageCount, 3);
      expect(scope.harness.archiveFile().existsSync(), isTrue);
      expect(
        scope.harness.partFile().existsSync(),
        isFalse,
        reason: '一時ファイルは rename で消える（中途半端なデータを残さない）',
      );
      // アプリを開き直しても「ダウンロード済み」と分かるよう台帳にも残る。
      final saved = await scope.harness.store.find(volumeId);
      expect(saved?.status, VolumeDownloadStatus.completed);
      // #11 がページ番号と拡張子を解決できるようマニフェストも保存する。
      expect(
        await scope.harness.store.readManifest(
          volumeId: volumeId,
          filesVersion: 111,
        ),
        isNotNull,
      );
    });

    // 詳細画面（autoDispose）は「ダウンロードを始めてすぐ一覧へ戻る」だけで
    // 破棄されるので、完了時に詳細を控えられない。圏外で一覧には出るのに詳細が
    // 開けないタイトルになるため、画面に依存しないここから控える（#11 の
    // レビュー指摘）。
    test('完了したらオフライン用の詳細を控えに行く（画面が無くても）', () async {
      final scope = setUpQueue();

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(scope.harness.warmedBooks, [bookId]);
    });

    test('同じ巻を二重に積まない（自宅サーバーへ同じ ZIP を 2 回取りに行かない）', () async {
      final scope = setUpQueue();
      final gate = Completer<void>();
      scope.harness.api.steps = [
        FakeArchiveStep(onDelivered: () => gate.future),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();
      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(scope.harness.api.archiveCalls, 1);
      gate.complete();
      await settle();
    });
  });

  group('検証', () {
    test('サイズが一致しなければ「ダウンロード済み」にせず一時ファイルを捨てる', () async {
      final bytes = zipWithPages(3);
      // サーバーの申告より短いデータしか届かなかった状況。
      final scope = setUpQueue(
        archiveBytes: bytes,
        archiveBytesOverride: bytes.length + 128,
      );

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, contains('サイズが一致しません'));
      expect(scope.harness.archiveFile().existsSync(), isFalse);
      expect(scope.harness.partFile().existsSync(), isFalse);
    });

    test('ページ数がマニフェストと違えば失敗にする', () async {
      final scope = setUpQueue(pageCount: 5);

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, contains('ページ数が一致しません'));
      expect(scope.harness.archiveFile().existsSync(), isFalse);
    });

    test('ZIP として開けなければ失敗にする', () async {
      // ZIP ではないバイト列（転送中に壊れた / プロキシがエラーページを返した）。
      final broken = Uint8List.fromList(List<int>.filled(512, 0x41));
      final scope = setUpQueue(archiveBytes: broken);

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, isNotNull);
      expect(scope.harness.partFile().existsSync(), isFalse);
    });
  });

  group('中断と再開', () {
    test('中断すると一時ファイルを残し、再開は続きから取りに行く', () async {
      final scope = setUpQueue();
      scope.harness.api.steps = [
        // 40 バイトだけ届いたところで中断する。
        FakeArchiveStep(
          bytes: 40,
          onDelivered: () => scope.queue.pause(volumeId),
        ),
        const FakeArchiveStep(),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.paused);
      expect(scope.harness.partFile().lengthSync(), 40);

      await scope.queue.resume(volumeId);
      await settle();

      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.completed,
      );
      expect(scope.harness.api.requestedOffsets, [
        0,
        40,
      ], reason: '2 回目は 40 バイト目から（Range）');
      expect(
        scope.harness.api.ifRangeEtags.last,
        'a1b2-c3d4',
        reason: '別世代の ZIP が継ぎ足されないよう If-Range を送る',
      );
    });

    test('アプリが落ちて残った「取得中」は中断に戻す（起動と同時には再開しない）', () async {
      final scope = setUpQueue();
      // 前回の実行が残した状態を作る。
      await scope.harness.store.save(
        const VolumeDownload(
          volumeId: volumeId,
          bookId: bookId,
          filesVersion: 111,
          status: VolumeDownloadStatus.downloading,
          receivedBytes: 40,
          totalBytes: 999,
        ),
      );
      await scope.harness.store.ensureVolumeDirectory(volumeId);
      scope.harness.partFile().writeAsBytesSync(
        scope.harness.api.archiveBytes.sublist(0, 40),
      );

      await scope.container.read(downloadQueueProvider.future);

      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.paused);
      expect(scope.harness.api.archiveCalls, 0, reason: '勝手に取りに行かない');

      await scope.queue.resume(volumeId);
      await settle();

      expect(scope.harness.api.requestedOffsets, [40]);
      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.completed,
      );
    });

    test('キャンセルすると一時ファイルも台帳も残らない', () async {
      final scope = setUpQueue();
      scope.harness.api.steps = [
        FakeArchiveStep(
          bytes: 40,
          onDelivered: () => scope.queue.remove(volumeId),
        ),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(downloadOf(scope.container), isNull);
      expect(scope.harness.partFile().existsSync(), isFalse);
      expect(await scope.harness.store.find(volumeId), isNull);
    });
  });

  group('リトライ', () {
    test('一時的な通信エラーは指数バックオフで再試行する', () async {
      final scope = setUpQueue();
      scope.harness.api.steps = [
        const FakeArchiveStep(bytes: 0, error: NetworkException()),
        const FakeArchiveStep(bytes: 0, error: NetworkException()),
        const FakeArchiveStep(),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.completed,
      );
      expect(scope.harness.delays, [
        const Duration(seconds: 2),
        const Duration(seconds: 4),
      ]);
    });

    test('429 は Retry-After に従う（自宅サーバーを叩き続けない）', () async {
      final scope = setUpQueue();
      scope.harness.api.steps = [
        const FakeArchiveStep(
          bytes: 0,
          error: TooManyRequestsException(retryAfter: Duration(seconds: 7)),
        ),
        const FakeArchiveStep(),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(scope.harness.delays, [const Duration(seconds: 7)]);
      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.completed,
      );
    });

    test('404 は再試行せずに失敗にする', () async {
      final scope = setUpQueue();
      scope.harness.api.steps = [
        const FakeArchiveStep(bytes: 0, error: NotFoundException()),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(scope.harness.api.archiveCalls, 1);
      expect(scope.harness.delays, isEmpty);
      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.failed);
    });

    test('再試行しても駄目なら失敗として残す（部分データは捨てない）', () async {
      final scope = setUpQueue();
      scope.harness.api.steps = [
        const FakeArchiveStep(bytes: 40, error: NetworkException()),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(scope.harness.api.archiveCalls, maxDownloadAttempts);
      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(
        scope.harness.partFile().existsSync(),
        isTrue,
        reason: '通信エラーで手元の進捗を捨てない（再開の起点になる）',
      );
    });
  });

  group('同時実行数', () {
    test('1 件ずつしか走らせない（HDD サーバーを詰まらせない）', () async {
      final scope = setUpQueue();
      scope.harness.api.manifests[341] = testManifest(
        id: 341,
        bookId: bookId,
        archiveBytes: scope.harness.api.archiveBytes.length,
      );
      final gate = Completer<void>();
      scope.harness.api.steps = [
        FakeArchiveStep(onDelivered: () => gate.future),
        const FakeArchiveStep(),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await scope.queue.enqueue(volumeId: 341, bookId: bookId);
      await settle();

      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.downloading,
      );
      expect(
        downloadOf(scope.container, 341)!.status,
        VolumeDownloadStatus.queued,
      );
      expect(scope.harness.api.archiveCalls, 1);

      gate.complete();
      await settle();

      expect(
        downloadOf(scope.container, 341)!.status,
        VolumeDownloadStatus.completed,
      );
    });

    test('上限を 2 にすれば 2 件まで同時に走る（それ以上は待たせる）', () async {
      final scope = setUpQueue(concurrency: 2);
      for (final id in [341, 342]) {
        scope.harness.api.manifests[id] = testManifest(
          id: id,
          bookId: bookId,
          archiveBytes: scope.harness.api.archiveBytes.length,
        );
      }
      final gate = Completer<void>();
      scope.harness.api.steps = [
        FakeArchiveStep(onDelivered: () => gate.future),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await scope.queue.enqueue(volumeId: 341, bookId: bookId);
      await scope.queue.enqueue(volumeId: 342, bookId: bookId);
      await settle();

      expect(scope.harness.api.archiveCalls, 2, reason: '3 件積んでも上限までしか取りに行かない');
      expect(
        downloadOf(scope.container, 342)!.status,
        VolumeDownloadStatus.queued,
      );

      gate.complete();
      await settle();
      expect(scope.harness.api.archiveCalls, 3, reason: '枠が空いたら次を流す');
    });
  });

  group('空き容量', () {
    test('足りないと分かっている場合は開始しない', () async {
      final scope = setUpQueue();
      scope.harness.freeSpace = 1024;

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, contains('空き容量'));
      expect(scope.harness.api.archiveCalls, 0);
    });

    test('空き容量が取得できない端末では止めない', () async {
      final scope = setUpQueue();
      // 既定（プラグインを入れていない）は「分からない」。
      scope.harness.freeSpace = null;

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.completed,
      );
    });
  });

  group('更新と削除', () {
    test('files_version が変わると「更新あり」になり、落とし直すと古い世代を捨てる', () async {
      final scope = setUpQueue();

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();
      expect(downloadOf(scope.container)!.isOutdated(222), isTrue);
      expect(downloadOf(scope.container)!.isOutdated(111), isFalse);
      expect(
        downloadOf(scope.container)!.isOutdated(null),
        isFalse,
        reason: 'サーバー側が分からないだけで「更新あり」にはしない',
      );

      // ZIP が差し替わった。
      scope.harness.api.manifest = testManifest(
        id: volumeId,
        bookId: bookId,
        filesVersion: 222,
        archiveBytes: scope.harness.api.archiveBytes.length,
      );
      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(download.filesVersion, 222);
      expect(scope.harness.archiveFile(filesVersion: 222).existsSync(), isTrue);
      expect(
        scope.harness.archiveFile(filesVersion: 111).existsSync(),
        isFalse,
        reason: '古い世代を残すと容量を二重に食う',
      );
    });

    test('巻単位で削除できる', () async {
      final scope = setUpQueue();

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();
      expect(scope.harness.archiveFile().existsSync(), isTrue);

      await scope.queue.remove(volumeId);
      await settle();

      expect(downloadOf(scope.container), isNull);
      expect(scope.harness.archiveFile().existsSync(), isFalse);
      expect(await scope.harness.store.find(volumeId), isNull);
    });
  });

  group('一時キャッシュとの独立', () {
    test('キャッシュの全削除でも LRU でもダウンロード済みは消えない', () async {
      final scope = setUpQueue();

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      // ログアウト以外のキャッシュ削除（設定画面 / 上限超過）を全部走らせる。
      await scope.harness.cache.store.clear();
      await scope.harness.cache.store.evictToLimit(CachedImageKind.page, 0);

      expect(scope.harness.archiveFile().existsSync(), isTrue);
      expect(
        (await scope.harness.store.find(volumeId))?.status,
        VolumeDownloadStatus.completed,
      );
    });
  });

  group('ログアウト', () {
    test('破棄するとダウンロード済みの実体も台帳も残らない', () async {
      final scope = setUpQueue();

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      await scope.queue.purgeAll();
      await settle();

      expect(scope.container.read(downloadQueueProvider).value, isEmpty);
      expect(scope.harness.archiveFile().existsSync(), isFalse);
      expect(await scope.harness.store.find(volumeId), isNull);
    });

    test('破棄より前に始まった取得を後から書き戻さない', () async {
      final scope = setUpQueue();
      final gate = Completer<void>();
      scope.harness.api.steps = [
        FakeArchiveStep(onDelivered: () => gate.future),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      await scope.queue.purgeAll();
      gate.complete();
      await settle();

      expect(scope.container.read(downloadQueueProvider).value, isEmpty);
      expect(await scope.harness.store.find(volumeId), isNull);
      expect(scope.harness.archiveFile().existsSync(), isFalse);
    });
  });

  group('検証の差し替え', () {
    test('検証が例外を投げても失敗として扱う（想定外の例外を UI に漏らさない）', () async {
      final scope = setUpQueue(
        verifier: (file) async => throw StateError('壊れた'),
      );

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.failed);
      expect(scope.harness.partFile().existsSync(), isFalse);
    });

    test('ArchiveVerificationException の文言をそのまま見せる', () async {
      final scope = setUpQueue(
        verifier: (file) async =>
            throw const ArchiveVerificationException('ダウンロードしたファイルを開けませんでした。'),
      );

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(
        downloadOf(scope.container)!.failureReason,
        'ダウンロードしたファイルを開けませんでした。',
      );
    });
  });

  group('マニフェスト', () {
    test('取得に失敗したら理由を残して失敗にする', () async {
      final scope = setUpQueue();
      scope.harness.api.manifestError = const NotFoundException();

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, const NotFoundException().message);
      expect(scope.harness.api.archiveCalls, 0);
    });

    test('取得の準備中に中断したら ZIP は落とさない', () async {
      final scope = setUpQueue();
      // マニフェストを待っている間（CancelToken がまだ無い区間）に停止ボタン。
      scope.harness.api.onManifest = () => scope.queue.pause(volumeId);

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(
        scope.harness.api.archiveCalls,
        0,
        reason: '「中断中」と表示したまま数百 MB を落としきってはいけない',
      );
      expect(downloadOf(scope.container)!.status, VolumeDownloadStatus.paused);
    });
  });

  group('再開の取りこぼし', () {
    test('一時ファイルが全長ぶん残っていたら取りに行かずに検証へ進む', () async {
      final scope = setUpQueue();
      // 検証 / rename の直前で OS に殺された状態（.part が全長ぶんある）。
      await scope.harness.store.ensureVolumeDirectory(volumeId);
      scope.harness.partFile().writeAsBytesSync(scope.harness.api.archiveBytes);

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(
        scope.harness.api.archiveCalls,
        0,
        reason: 'Range: bytes={全長}- はサーバーが 416 を返し、再開するたび同じ失敗になる',
      );
      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.completed,
      );
      expect(scope.harness.archiveFile().existsSync(), isTrue);
    });

    test('一時ファイルが長すぎる場合は検証で捨てる（やり直せる状態に戻す）', () async {
      final scope = setUpQueue();
      await scope.harness.store.ensureVolumeDirectory(volumeId);
      scope.harness.partFile().writeAsBytesSync([
        ...scope.harness.api.archiveBytes,
        ...List<int>.filled(64, 0),
      ]);

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.failed);
      expect(download.failureReason, contains('サイズが一致しません'));
      expect(
        scope.harness.partFile().existsSync(),
        isFalse,
        reason: '捨てておかないと次の再開も同じところで詰まる',
      );
    });

    test('rename 済みでマニフェストが無い巻は確定し直すときに書き直す', () async {
      final scope = setUpQueue();
      // rename は済んだが {v}.json を書く前に落ちた状態。
      await scope.harness.store.ensureVolumeDirectory(volumeId);
      scope.harness.archiveFile().writeAsBytesSync(
        scope.harness.api.archiveBytes,
      );

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      expect(scope.harness.api.archiveCalls, 0, reason: '同じ世代が手元にあるので落とし直さない');
      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.completed,
      );
      expect(
        await scope.harness.store.readManifest(
          volumeId: volumeId,
          filesVersion: 111,
        ),
        isNotNull,
        reason: '{v}.json が無いまま確定すると #11 がページを解決できない',
      );
    });
  });

  group('更新の取り直し', () {
    /// 111 を落とし終えたあと、サーバー側が 222 に差し替わった状態にする。
    Future<
      ({
        DownloadHarness harness,
        ProviderContainer container,
        DownloadQueue queue,
      })
    >
    setUpOutdated() async {
      final scope = setUpQueue();
      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();
      expect(
        downloadOf(scope.container)!.status,
        VolumeDownloadStatus.completed,
      );

      scope.harness.api.manifest = testManifest(
        id: volumeId,
        bookId: bookId,
        filesVersion: 222,
        archiveBytes: scope.harness.api.archiveBytes.length,
      );
      return scope;
    }

    test('マニフェストが取れなくても完了済みを失敗にしない', () async {
      final scope = await setUpOutdated();
      // オフラインで「更新あり」を押した状況。
      scope.harness.api.manifestError = const NetworkException();

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(
        download.status,
        VolumeDownloadStatus.completed,
        reason: '通信エラーで手元のキャッシュ（オフラインで読める旧世代）を捨てない',
      );
      expect(download.filesVersion, 111);
      expect(
        download.failureReason,
        const NetworkException().message,
        reason: '失敗を黙って隠さない（UI が理由を出す）',
      );
      expect(scope.harness.archiveFile(filesVersion: 111).existsSync(), isTrue);
      expect(
        (await scope.harness.store.find(volumeId))?.status,
        VolumeDownloadStatus.completed,
      );
    });

    test('取得が失敗したら手元の旧世代を「ダウンロード済み」として残す', () async {
      final scope = await setUpOutdated();
      scope.harness.api.steps = [
        const FakeArchiveStep(bytes: 0, error: NotFoundException()),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(
        download.filesVersion,
        111,
        reason: '失敗した世代（222）を指すと、実体のある 111 を指す行がどこにも無くなる',
      );
      expect(download.failureReason, isNotNull);
      expect(scope.harness.archiveFile(filesVersion: 111).existsSync(), isTrue);
      expect(
        scope.harness.archiveFile(filesVersion: 222).existsSync(),
        isFalse,
      );
    });

    test('検証に失敗しても手元の旧世代を「ダウンロード済み」として残す', () async {
      final scope = await setUpOutdated();
      // 落とせたが ZIP が壊れていた（差し替え途中の ZIP を掴んだ）。
      scope.harness.api.archiveBytes = Uint8List.fromList(
        List<int>.filled(scope.harness.api.archiveBytes.length, 0x41),
      );

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(download.status, VolumeDownloadStatus.completed);
      expect(download.filesVersion, 111);
      expect(scope.harness.archiveFile(filesVersion: 111).existsSync(), isTrue);
    });

    test('取り直しを中断しても手元の旧世代を指したままにする', () async {
      final scope = await setUpOutdated();
      scope.harness.api.steps = [
        FakeArchiveStep(
          bytes: 40,
          onDelivered: () => scope.queue.pause(volumeId),
        ),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      final download = downloadOf(scope.container)!;
      expect(
        download.status,
        VolumeDownloadStatus.completed,
        reason: '「中断中（222）」にすると、読める 111 を指す行が消える',
      );
      expect(download.filesVersion, 111);
      expect(download.failureReason, isNull, reason: '自分で止めたのは失敗ではない');
      expect(
        scope.harness.partFile(filesVersion: 222).existsSync(),
        isTrue,
        reason: 'もう一度「更新あり」を押せば続きから取れる',
      );
    });
  });

  group('後片付けとの競合', () {
    test('破棄の途中で届いた中断を台帳へ書き戻さない', () async {
      final scope = setUpQueue();
      final delivered = Completer<void>();
      scope.harness.api.steps = [
        FakeArchiveStep(bytes: 40, onDelivered: () => delivered.future),
      ];

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      // 行の削除は終わり、実体の削除で待っている「破棄の途中」を作る。
      final gate = Completer<void>();
      scope.harness.store.beforeDeleteAllFiles = gate;
      final purge = scope.queue.purgeAll();
      await pumpEventQueue();

      // ここでキャンセル例外が届く（dio のキャンセルは次のループで届く）。
      delivered.complete();
      await pumpEventQueue();
      gate.complete();
      await purge;
      await settle();

      expect(
        await scope.harness.store.find(volumeId),
        isNull,
        reason: '前のユーザーの巻が「中断中」として端末に残ってはいけない（#15）',
      );
      expect(scope.container.read(downloadQueueProvider).value, isEmpty);
    });

    test('確定の直前に取り消したら「ダウンロード済み」を復活させない', () async {
      final scope = setUpQueue();
      // rename は済み、旧世代の掃除で待っている状態を作る。
      final gate = Completer<void>();
      scope.harness.store.beforeDeleteOtherVersions = gate;

      await scope.queue.enqueue(volumeId: volumeId, bookId: bookId);
      await settle();

      await scope.queue.remove(volumeId);
      gate.complete();
      await settle();

      expect(downloadOf(scope.container), isNull);
      expect(
        await scope.harness.store.find(volumeId),
        isNull,
        reason: '実体を消したあとに completed の行が残ると、読めない「ダウンロード済み」が出る',
      );
      expect(scope.harness.archiveFile().existsSync(), isFalse);
    });
  });
}
