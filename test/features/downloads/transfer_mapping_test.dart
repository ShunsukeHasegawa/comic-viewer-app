import 'package:background_downloader/background_downloader.dart';
import 'package:comic_laz/features/downloads/data/archive_transport.dart';
import 'package:comic_laz/features/downloads/data/transfer_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveTransferRequest request({
  String taskId = 'v12.f1700000000.sabc123',
  DateTime? creationTime,
}) => ArchiveTransferRequest(
  taskId: taskId,
  uri: Uri.parse('https://comic.example/api/v2/volumes/12/archive'),
  headers: const {'Authorization': 'Bearer token'},
  directory: 'downloads/12',
  filename: '1700000000.zip.download',
  creationTime: creationTime ?? DateTime.utc(2026, 9, 29, 12),
  displayName: '3 巻',
);

DownloadTask task() => buildDownloadTask(request());

TransferFailure failureOf(TaskStatusUpdate update) {
  final event = mapStatus(update);
  expect(event.state, TransferState.failed);
  return event.failure!;
}

TransferFailure httpFailure(int code) => failureOf(
  TaskStatusUpdate(
    task(),
    TaskStatus.failed,
    TaskHttpException('HTTP $code', code),
  ),
);

void main() {
  group('buildDownloadTask', () {
    test('HDD を順に読ませるため creationTime を渡したとおりに使う', () {
      // holding queue は priority → creationTime（ミリ秒）で取り出すので、
      // 「今」で上書きされると積んだ順（巻の順）が崩れる。
      final at = DateTime.utc(2026, 1, 2, 3, 4, 5, 678);
      expect(buildDownloadTask(request(creationTime: at)).creationTime, at);
    });

    test(
      '9 分の時間切れで失敗しないよう allowPause を付け、expedited の 2 分制限を避けるため priority 5 にする',
      () {
        final built = task();
        expect(built.allowPause, isTrue);
        expect(built.priority, 5);
      },
    );

    test('コンテナのパスが変わっても完了先がずれないよう applicationSupport 基準の相対パスにする', () {
      final built = task();
      expect(built.baseDirectory, BaseDirectory.applicationSupport);
      expect(built.directory, 'downloads/12');
      expect(built.filename, '1700000000.zip.download');
    });

    test('二重に数えないよう retries は 0', () {
      // 再試行の回数はキューが数える（401 や Wi-Fi 待ちを数え分けるため）。
      expect(task().retries, 0);
    });

    test('グループ通知と一括消去の対象にするため volumes グループに入れる', () {
      expect(task().group, archiveTransferGroup);
    });

    test('進捗を表示するため状態と進捗の両方を受け取る', () {
      expect(task().updates, Updates.statusAndProgress);
    });

    test('Wi-Fi 限定は global の設定に任せるため、タスクには焼き込まない', () {
      // タスクに焼き込むと、設定を切り替えても走行中の転送に反映されない。
      expect(task().requiresWiFi, isFalse);
    });

    test('ID・URL・ヘッダー・表示名は依頼のまま渡す', () {
      final built = task();
      expect(built.taskId, 'v12.f1700000000.sabc123');
      expect(built.url, 'https://comic.example/api/v2/volumes/12/archive');
      expect(built.headers, {'Authorization': 'Bearer token'});
      expect(built.displayName, '3 巻');
    });
  });

  group('mapStatus', () {
    test('HTTP の 401 は再試行ではなくトークン確認に回すため unauthorized に写す', () {
      final failure = httpFailure(401);
      expect(failure.kind, TransferFailureKind.unauthorized);
      expect(failure.httpCode, 401);
    });

    test('403 は署名付き URL の失効なので forbidden に写す（キューが発行し直す。#22）', () {
      expect(httpFailure(403).kind, TransferFailureKind.forbidden);
    });

    test('409 は発行後に ZIP が差し替わったので archiveReplaced に写す（#22）', () {
      expect(httpFailure(409).kind, TransferFailureKind.archiveReplaced);
    });

    test('404 は巻が消えたので再試行しない notFound に写す', () {
      expect(httpFailure(404).kind, TransferFailureKind.notFound);
    });

    test('429 は待てば通るので tooManyRequests に写す', () {
      expect(httpFailure(429).kind, TransferFailureKind.tooManyRequests);
    });

    test('503 などの 5xx は一時的な不調として server に写す', () {
      expect(httpFailure(503).kind, TransferFailureKind.server);
      expect(httpFailure(500).kind, TransferFailureKind.server);
    });

    test('分類できない HTTP エラーは other にして、勝手に再試行させない', () {
      expect(httpFailure(416).kind, TransferFailureKind.other);
    });

    test('パッケージの notFound 状態は 404 で終わったことなので、失敗として 404 を渡す', () {
      // TransferState.notFound は「パッケージが把握していない」の意味で別物。
      final failure = failureOf(TaskStatusUpdate(task(), TaskStatus.notFound));
      expect(failure.kind, TransferFailureKind.notFound);
      expect(failure.httpCode, 404);
    });

    test('ETag が変わった再開は別世代が混ざるので resumeMismatch として扱う', () {
      final failure = failureOf(
        TaskStatusUpdate(
          task(),
          TaskStatus.failed,
          TaskResumeException(
            'Cannot resume: ETag is not identical, or is weak',
          ),
        ),
      );
      expect(failure.kind, TransferFailureKind.resumeMismatch);
    });

    test('容量不足などの書き込み失敗は再試行しても直らないので fileSystem に写す', () {
      final failure = failureOf(
        TaskStatusUpdate(
          task(),
          TaskStatus.failed,
          TaskFileSystemException('No space left on device'),
        ),
      );
      expect(failure.kind, TransferFailureKind.fileSystem);
      expect(failure.message, 'No space left on device');
    });

    test('Android が fileSystem で送ってくる回線の瞬断は、恒久的な失敗にせず connection に写す', () {
      // TaskRunner.setTaskException は SocketException 以外の IOException を
      // すべて fileSystem にする。これを容量不足と同じに扱うと、サーバーの
      // 再起動や TLS の切断 1 回で数百 MB の転送が失敗のまま止まる（F8）。
      for (final description in [
        'java.net.ProtocolException: unexpected end of stream',
        'javax.net.ssl.SSLException: Read error: ssl=0x7b: I/O error during '
            'system call, Connection reset by peer',
        'java.net.UnknownHostException: Unable to resolve host '
            '"comic.lazgram.com": No address associated with hostname',
        'java.io.EOFException',
      ]) {
        final failure = failureOf(
          TaskStatusUpdate(
            task(),
            TaskStatus.failed,
            TaskFileSystemException(description),
          ),
        );
        expect(
          failure.kind,
          TransferFailureKind.connection,
          reason: description,
        );
      }
    });

    test('端末側の問題と文言で分かる fileSystem は、再試行しない fileSystem のまま', () {
      for (final description in [
        'Insufficient space to store the file to be downloaded',
        'java.io.IOException: write failed: ENOSPC (No space left on device)',
        'java.io.FileNotFoundException: /data/x: open failed: EACCES '
            '(Permission denied)',
        'File operation failed: The file couldn’t be saved.',
      ]) {
        final failure = failureOf(
          TaskStatusUpdate(
            task(),
            TaskStatus.failed,
            TaskFileSystemException(description),
          ),
        );
        expect(
          failure.kind,
          TransferFailureKind.fileSystem,
          reason: description,
        );
      }
    });

    test('回線の切断は待てば直るので connection に写す', () {
      final failure = failureOf(
        TaskStatusUpdate(
          task(),
          TaskStatus.failed,
          TaskConnectionException('Connection reset'),
        ),
      );
      expect(failure.kind, TransferFailureKind.connection);
    });

    test('例外が無く応答コードだけある失敗も、コードで分類する', () {
      final failure = failureOf(
        TaskStatusUpdate(task(), TaskStatus.failed, null, null, null, 401),
      );
      expect(failure.kind, TransferFailureKind.unauthorized);
    });

    test('理由の分からない失敗は other にする', () {
      expect(
        failureOf(TaskStatusUpdate(task(), TaskStatus.failed)).kind,
        TransferFailureKind.other,
      );
    });

    test('失敗以外の状態は理由を付けずにそのまま写す', () {
      const expected = {
        TaskStatus.enqueued: TransferState.enqueued,
        TaskStatus.running: TransferState.running,
        TaskStatus.waitingToRetry: TransferState.waitingToRetry,
        TaskStatus.paused: TransferState.paused,
        TaskStatus.complete: TransferState.completed,
        TaskStatus.canceled: TransferState.canceled,
      };
      for (final MapEntry(key: status, value: state) in expected.entries) {
        final event = mapStatus(TaskStatusUpdate(task(), status));
        expect(event.taskId, 'v12.f1700000000.sabc123');
        expect(event.state, state, reason: '$status');
        expect(event.failure, isNull, reason: '$status');
      }
    });
  });

  group('mapProgress', () {
    test('割合と全体サイズから受信バイト数を求める', () {
      final event = mapProgress(TaskProgressUpdate(task(), 0.25, 4000));
      expect(event, isNotNull);
      expect(event!.taskId, 'v12.f1700000000.sabc123');
      expect(event.received, 1000);
      expect(event.total, 4000);
    });

    test('失敗や取り消しを表す負の番兵は進捗として流さない', () {
      // 流すと表示が負になる。状態は TaskStatusUpdate の方で届く。
      for (final sentinel in [
        progressFailed,
        progressCanceled,
        progressNotFound,
        progressWaitingToRetry,
        progressPaused,
      ]) {
        expect(
          mapProgress(TaskProgressUpdate(task(), sentinel, 4000)),
          isNull,
          reason: '$sentinel',
        );
      }
    });

    test('0 と 1 は全体サイズが当てにならないので流さない', () {
      // 0 を流すと、再開直後に表示が 0 に戻ってしまう。1 の直後には完了が届く。
      expect(mapProgress(TaskProgressUpdate(task(), 0, 4000)), isNull);
      expect(mapProgress(TaskProgressUpdate(task(), 1, 4000)), isNull);
    });

    test('全体サイズが分からなければバイト数に直せないので流さない', () {
      expect(mapProgress(TaskProgressUpdate(task(), 0.5)), isNull);
    });
  });

  group('mergeTransferSnapshots', () {
    TransferState stateOf(List<TransferSnapshot> snapshots, String taskId) =>
        snapshots.singleWhere((s) => s.taskId == taskId).state;

    test('ユーザーが止めた転送は、allTasks に混ざっていても一時停止として返す', () {
      // allTasks は Dart 側の一時停止中も返す。「ネイティブが持っている」と
      // 数えると enqueued に化け、照合が取り消して再開データと書きかけを
      // 捨てる（起動のたびに数百 MB がやり直しになる。F5）。
      final snapshots = mergeTransferSnapshots(
        records: [('a', TaskStatus.paused)],
        listedIds: ['a'],
        resumeIds: {'a'},
        pausedIds: {'a'},
      );
      expect(stateOf(snapshots, 'a'), TransferState.paused);
      expect(snapshots.single.hasResumeData, isTrue);
    });

    test('走行中の記録のまま一時停止に残っているものも、一時停止として返して再開させる', () {
      // 時間切れの pause の後、ネイティブの再投入の前にプロセスが死んだ。
      final snapshots = mergeTransferSnapshots(
        records: [('a', TaskStatus.running)],
        listedIds: ['a'],
        resumeIds: {'a'},
        pausedIds: {'a'},
      );
      expect(stateOf(snapshots, 'a'), TransferState.paused);
    });

    test('時間切れの後にネイティブで走り直しているものは、一時停止に残っていても生きているとする', () {
      // パッケージは最終状態まで一時停止の記録を消さない。一時停止として
      // 返すと、照合が走っている転送を二重に再開してしまう。
      final snapshots = mergeTransferSnapshots(
        records: [('a', TaskStatus.running)],
        listedIds: ['a', 'a'],
        resumeIds: {'a'},
        pausedIds: {'a'},
      );
      expect(stateOf(snapshots, 'a'), TransferState.running);
    });

    test('記録が走行中なのにネイティブが知らないものは、消えたとして積み直させる', () {
      final snapshots = mergeTransferSnapshots(
        records: [('a', TaskStatus.running)],
        listedIds: const [],
        resumeIds: const {},
        pausedIds: const {},
      );
      expect(stateOf(snapshots, 'a'), TransferState.notFound);
    });

    test('記録が遅れていても、ネイティブが持っているものは生きているとする', () {
      final snapshots = mergeTransferSnapshots(
        records: [('a', TaskStatus.paused)],
        listedIds: ['a'],
        resumeIds: const {},
        pausedIds: const {},
      );
      expect(stateOf(snapshots, 'a'), TransferState.enqueued);
    });
  });

  group('パッケージの設定', () {
    test('記録を自動で間引かない（閉じている間に終わった巻の完了を照合の前に消さない）', () {
      // 自動の間引きは投入時刻で状態に関係なく消す。10 日前に積んだ巻が
      // 閉じている間に終わると、書き上がった ZIP が孤児として掃除される（F6）。
      expect(archiveTransferStartOptions.autoCleanDatabase, isFalse);
      expect(
        archiveTransferStartOptions.doRescheduleKilledTasks,
        isFalse,
        reason: '古いトークンのまま、照合と二重に積み直すため',
      );
    });

    test('通知の許可があれば foreground で走らせ、9 分の時間切れで同時実行数を崩さない', () {
      // 時間切れの再投入は holding queue を通らず、HDD を 2 本で読ませる（F12）。
      expect(foregroundModeFor(notificationsGranted: true), Config.always);
    });

    test('通知の許可が無ければ foreground にしない（WorkManager の 10 分の上限で落ちるため）', () {
      // パッケージは許可を見ずに foreground 扱いにし、通知を出せず foreground
      // にも移れないまま 9 分の pause も起きなくなる。
      expect(foregroundModeFor(notificationsGranted: false), Config.never);
    });
  });

  group('mapTaskUpdate', () {
    test('状態と進捗をそれぞれのイベントに振り分ける', () {
      expect(
        mapTaskUpdate(TaskStatusUpdate(task(), TaskStatus.running)),
        isA<TransferStateChanged>(),
      );
      expect(
        mapTaskUpdate(TaskProgressUpdate(task(), 0.5, 100)),
        isA<TransferProgressed>(),
      );
    });
  });
}
