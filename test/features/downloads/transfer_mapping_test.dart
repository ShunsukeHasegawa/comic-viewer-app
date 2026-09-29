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

    test('403 は権限の問題なので再試行しない forbidden に写す', () {
      expect(httpFailure(403).kind, TransferFailureKind.forbidden);
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
