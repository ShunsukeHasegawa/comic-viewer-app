import 'dart:io';

import 'package:comic_laz/core/network/api_exception.dart';
import 'package:comic_laz/features/downloads/application/download_failure_policy.dart';
import 'package:comic_laz/features/downloads/data/archive_transport.dart';
import 'package:flutter_test/flutter_test.dart';

FailureAction _action(
  TransferFailureKind kind, {
  int? httpCode,
  bool waitingForWifi = false,
}) => failureActionFor(
  TransferFailure(kind: kind, httpCode: httpCode),
  isWaitingForWifi: () => waitingForWifi,
);

void main() {
  group('failureActionFor', () {
    test('削除済み / 容量不足は待っても直らないので、回数を数えずに失敗にする', () {
      expect(_action(TransferFailureKind.notFound), FailureAction.giveUp);
      expect(_action(TransferFailureKind.fileSystem), FailureAction.giveUp);
    });

    test('ネイティブの 401 は古いトークンへの応答かもしれないので、ログアウトさせずに確かめ直す', () {
      expect(
        _action(TransferFailureKind.unauthorized),
        FailureAction.recheckSession,
      );
    });

    test('403 / 409 / ETag 不一致は書きかけが使えないので、URL を発行し直して先頭から取る（#22）', () {
      for (final kind in [
        TransferFailureKind.forbidden,
        TransferFailureKind.archiveReplaced,
        TransferFailureKind.resumeMismatch,
      ]) {
        expect(
          _action(kind),
          FailureAction.reissueFromScratch,
          reason: '$kind',
        );
      }
    });

    test('Wi-Fi 待ちの間の応答無しの失敗は、Wi-Fi が途切れるたびに失敗へ近づかないよう数えない', () {
      expect(
        _action(TransferFailureKind.connection, waitingForWifi: true),
        FailureAction.resubmitUncounted,
      );
      // Android は Wi-Fi の制約が外れたワーカーの停止を理由無しで届ける。
      expect(
        _action(TransferFailureKind.other, waitingForWifi: true),
        FailureAction.resubmitUncounted,
      );
    });

    test('Wi-Fi 待ちでも HTTP の応答があった失敗は、サーバーを叩き続けないよう数えて待つ', () {
      expect(
        _action(TransferFailureKind.other, httpCode: 400, waitingForWifi: true),
        FailureAction.retryWithBackoff,
      );
    });

    test('通信エラー / 5xx / 429 は一時的なものとして、数えて間を空けて積み直す', () {
      for (final kind in [
        TransferFailureKind.connection,
        TransferFailureKind.server,
        TransferFailureKind.tooManyRequests,
        TransferFailureKind.other,
      ]) {
        expect(_action(kind), FailureAction.retryWithBackoff, reason: '$kind');
      }
    });

    test('Wi-Fi 待ちかどうかは要るときだけ確かめる（他の失敗で回線の状態を読まない）', () {
      var asked = 0;
      failureActionFor(
        const TransferFailure(kind: TransferFailureKind.forbidden),
        isWaitingForWifi: () {
          asked++;
          return true;
        },
      );
      expect(asked, 0);
    });
  });

  test('再試行の待ち時間は 2 秒 → 4 秒と延ばし、自宅サーバーを叩き続けない', () {
    expect(retryBackoff(1), const Duration(seconds: 2));
    expect(retryBackoff(2), const Duration(seconds: 4));
  });

  group('DownloadAttempts', () {
    test('上限に達したら失敗にし、次の「再開」が 1 回目から数え直せるよう回数を忘れる', () {
      final attempts = DownloadAttempts();
      for (var i = 1; i < maxDownloadAttempts; i++) {
        expect(attempts.count(1), isTrue);
        expect(attempts.current(1), i);
      }
      expect(attempts.count(1), isFalse);
      expect(attempts.current(1), 1);
      expect(attempts.count(1), isTrue);
    });

    test('巻ごとに数える（他の巻の失敗で上限に近づかない）', () {
      final attempts = DownloadAttempts()
        ..count(1)
        ..count(1);
      expect(attempts.count(2), isTrue);
      expect(attempts.current(2), 1);
    });

    test('reset / clear で数え直す（ユーザーの再開・照合のやり直し・ログアウト）', () {
      final attempts = DownloadAttempts()
        ..count(1)
        ..count(2)
        ..reset(1);
      expect(attempts.current(1), 1);
      expect(attempts.current(2), 1);
      attempts
        ..count(2)
        ..clear();
      for (var i = 1; i < maxDownloadAttempts; i++) {
        expect(attempts.count(2), isTrue);
      }
    });
  });

  group('文言', () {
    test('圏外 / 時間切れだけを「待てば直る」として扱う（初回の巻を待機のまま残す）', () {
      expect(isOfflineError(const NetworkException()), isTrue);
      expect(isOfflineError(const ApiTimeoutException()), isTrue);
      expect(isOfflineError(const ServerException(statusCode: 500)), isFalse);
      expect(isOfflineError(const NotFoundException()), isFalse);
      expect(isOfflineError(StateError('x')), isFalse);
    });

    test('ネイティブの容量不足は errno が無いので、文言から見分けて原因を出す', () {
      for (final message in [
        'ENOSPC',
        'No space left on device',
        'Not enough space',
        'Insufficient storage',
      ]) {
        expect(
          transferFailureMessage(
            TransferFailure(
              kind: TransferFailureKind.fileSystem,
              message: message,
            ),
          ),
          outOfSpaceMessage,
          reason: message,
        );
      }
      expect(
        transferFailureMessage(
          const TransferFailure(
            kind: TransferFailureKind.fileSystem,
            message: 'permission denied',
          ),
        ),
        '端末にデータを保存できませんでした。',
      );
    });

    test('端末の書き込み失敗は ENOSPC（Windows のディスク満杯を含む）だけ容量不足と出す', () {
      for (final code in [28, 39, 112]) {
        expect(
          fileSystemFailureMessage(
            FileSystemException('x', 'p', OSError('full', code)),
          ),
          outOfSpaceMessage,
          reason: '$code',
        );
      }
      expect(
        fileSystemFailureMessage(
          const FileSystemException('x', 'p', OSError('denied', 13)),
        ),
        '端末にデータを保存できませんでした。',
      );
      expect(
        fileSystemFailureMessage(const FileSystemException('x')),
        '端末にデータを保存できませんでした。',
      );
    });

    test('API の失敗はサーバー由来の文言をそのまま出し、それ以外は一般的な文言にする', () {
      expect(
        downloadErrorMessage(const NotFoundException()),
        const NotFoundException().message,
      );
      expect(
        downloadErrorMessage(
          const FileSystemException('x', 'p', OSError('full', 28)),
        ),
        outOfSpaceMessage,
      );
      expect(downloadErrorMessage(StateError('x')), 'ダウンロードに失敗しました。');
    });

    test('ZIP の差し替えは壊れたのではないので、もう一度試せば取れると伝える', () {
      for (final kind in [
        TransferFailureKind.archiveReplaced,
        TransferFailureKind.resumeMismatch,
      ]) {
        expect(
          transferFailureMessage(TransferFailure(kind: kind)),
          'ダウンロード中にサーバー側のデータが更新されました。もう一度お試しください。',
        );
      }
    });
  });
}
