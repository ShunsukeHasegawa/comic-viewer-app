import 'dart:io';

import '../../../core/network/api_exception.dart';
import '../data/archive_transport.dart';

// 転送の失敗の解釈（再試行するか・何と出すか）。
//
// DownloadQueue から切り出した、状態を持たない判断だけをここに置く。
// 実際に転送を捨てる / 積み直す / 待つのはキューの側（#29）。

/// 1 巻あたりの転送の試行回数（初回を含む）。
const maxDownloadAttempts = 3;

/// 転送の失敗に対してキューが取る手。
enum FailureAction {
  /// 待っても直らない（削除済み / セーフモードで配信されない / 容量不足）。
  /// 回数を数えずに失敗にする。
  giveUp,

  /// ネイティブの 401。タスクに焼き込んだ古いトークンへの応答かもしれない
  /// ので、すぐにログアウトさせず、回数を数えてマニフェストから取り直す
  /// （本当に失効していれば Dio の 401 が AuthInterceptor の 1 経路に合流する）。
  recheckSession,

  /// 403（署名付き URL の期限切れ / 改ざん / 発行元トークンの失効。#22）・
  /// 409（発行後の ZIP 差し替え）・再開時の ETag 不一致。書きかけは使えない
  /// ので、回数を数え、書きかけを捨てて URL を発行し直し先頭から取る。
  reissueFromScratch,

  /// Wi-Fi 限定で Wi-Fi が切れた失敗。回数に数えず積み直す（数えると Wi-Fi が
  /// 3 回途切れるだけで「失敗」になる）。ネイティブが Wi-Fi に戻るまで待つ。
  resubmitUncounted,

  /// 通信エラー / 5xx / 429 / その他。回数を数え、間を空けて積み直す。
  retryWithBackoff,
}

/// 転送の失敗に対する手を決める。
///
/// [isWaitingForWifi] は「Wi-Fi 限定で Wi-Fi を待っている」か
/// （`DownloadGate.waitingForWifi`）。HTTP の応答が無い通信エラー / その他の
/// 失敗のときだけ呼ぶ。
FailureAction failureActionFor(
  TransferFailure failure, {
  required bool Function() isWaitingForWifi,
}) => switch (failure.kind) {
  TransferFailureKind.notFound ||
  TransferFailureKind.fileSystem => FailureAction.giveUp,
  TransferFailureKind.unauthorized => FailureAction.recheckSession,
  TransferFailureKind.forbidden ||
  TransferFailureKind.archiveReplaced ||
  TransferFailureKind.resumeMismatch => FailureAction.reissueFromScratch,
  // `other` も含めるのは、Android では Wi-Fi の制約が外れると WorkManager が
  // ワーカーを止め、その失敗が connection ではなく理由無し / 一般の例外
  // （CancellationException）として届くため（モバイル回線が生きているので、
  // パッケージの「オフラインなら再試行待ち」も効かない）。
  // HTTP の応答があった失敗は除く。サーバーまで届いている = Wi-Fi 切れでは
  // ない。Wi-Fi 待ちの判定（VPN だけの回線などを従量制とみなす）と OS の
  // 制約が食い違うと、決まって 4xx を返す巻を数えずに待ち時間無しで積み直し
  // 続け、自宅サーバーを叩き続ける。下の「数えて待つ」側に回す。
  TransferFailureKind.connection || TransferFailureKind.other
      when failure.httpCode == null && isWaitingForWifi() =>
    FailureAction.resubmitUncounted,
  TransferFailureKind.connection ||
  TransferFailureKind.server ||
  TransferFailureKind.tooManyRequests ||
  TransferFailureKind.other => FailureAction.retryWithBackoff,
};

/// [attempt] 回目の失敗の後に積み直すまでの待ち時間（2 秒 → 4 秒）。
///
/// 自宅サーバーを叩き続けない。429 の Retry-After は見ない（パッケージの
/// 失敗の更新に応答ヘッダーが載る保証が無い）ので、5xx と同じ間隔で待つ。
Duration retryBackoff(int attempt) => Duration(seconds: 1 << attempt);

/// 巻ごとの転送の試行回数（再試行の上限）。
class DownloadAttempts {
  final _counts = <int, int>{};

  /// 試行を 1 回数える。上限（[maxDownloadAttempts]）に達したら回数を
  /// 忘れて `false`（呼び出し側が失敗にする。次の「再開」は 1 回目から）。
  bool count(int volumeId) {
    final attempt = (_counts[volumeId] ?? 0) + 1;
    _counts[volumeId] = attempt;
    if (attempt < maxDownloadAttempts) return true;
    _counts.remove(volumeId);
    return false;
  }

  /// 今までに数えた回数（まだ数えていなければ 1 とみなす）。
  int current(int volumeId) => _counts[volumeId] ?? 1;

  void reset(int volumeId) => _counts.remove(volumeId);

  void clear() => _counts.clear();
}

/// 回線が無い / 届かない失敗か（待てば直る見込みがある）。
bool isOfflineError(Object error) =>
    error is NetworkException || error is ApiTimeoutException;

/// 投入の途中（マニフェスト / URL の取得）で起きた例外の文言。
String downloadErrorMessage(Object error) => switch (error) {
  final ApiException error => error.message,
  final FileSystemException error => fileSystemFailureMessage(error),
  _ => 'ダウンロードに失敗しました。',
};

/// 転送の失敗の文言。
String transferFailureMessage(
  TransferFailure failure,
) => switch (failure.kind) {
  TransferFailureKind.unauthorized => const UnauthorizedException().message,
  TransferFailureKind.forbidden => const ForbiddenException().message,
  TransferFailureKind.notFound => const NotFoundException().message,
  TransferFailureKind.server => const ServerException(statusCode: 500).message,
  TransferFailureKind.tooManyRequests =>
    const TooManyRequestsException().message,
  TransferFailureKind.connection => const NetworkException().message,
  TransferFailureKind.resumeMismatch || TransferFailureKind.archiveReplaced =>
    'ダウンロード中にサーバー側のデータが更新されました。もう一度お試しください。',
  TransferFailureKind.fileSystem =>
    _isOutOfSpace(failure.message) ? outOfSpaceMessage : '端末にデータを保存できませんでした。',
  TransferFailureKind.other => 'ダウンロードに失敗しました。',
};

/// 容量不足の文言。
const outOfSpaceMessage = '端末の空き容量が足りません。不要なデータを削除してからやり直してください。';

/// ネイティブの失敗は errno を持たないので、文言で容量不足を見分ける。
bool _isOutOfSpace(String message) {
  final lower = message.toLowerCase();
  return lower.contains('enospc') ||
      lower.contains('no space') ||
      lower.contains('not enough space') ||
      lower.contains('insufficient');
}

/// 端末側の書き込み失敗。容量不足（ENOSPC）だけは原因を明示する。
String fileSystemFailureMessage(FileSystemException error) {
  // errno 28 = ENOSPC（Android / iOS / Linux / macOS 共通）。
  // Windows は ERROR_DISK_FULL(112) / ERROR_HANDLE_DISK_FULL(39)。
  const outOfSpace = {28, 39, 112};
  if (outOfSpace.contains(error.osError?.errorCode)) {
    return outOfSpaceMessage;
  }
  return '端末にデータを保存できませんでした。';
}
