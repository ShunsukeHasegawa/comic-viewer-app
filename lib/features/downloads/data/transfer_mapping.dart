import 'package:background_downloader/background_downloader.dart';

import 'archive_transport.dart';

/// 巻の ZIP の転送をまとめるグループ名。
///
/// 通知（グループ通知）・一覧・ログアウト時の全消去をこの単位で行う。
/// 他の用途でパッケージを使っても、巻の転送だけを扱えるようにするため。
const archiveTransferGroup = 'volumes';

/// グループ通知の ID。巻ごとに通知を出すと、全巻ダウンロードで数十件の通知が
/// 溜まるので 1 件にまとめる。
const archiveTransferNotificationId = 'comic-laz-volumes';

/// 転送の依頼をパッケージのタスクに変換する。
///
/// 固定値にしている項目とその理由:
/// - `baseDirectory: applicationSupport` + 相対パス: iOS はアプリの更新で
///   コンテナのパスが変わる。絶対パスを焼き込むと、閉じている間に終わった
///   転送の完了先がずれる。Android は `filesDir` で path_provider と一致する。
/// - `retries: 0`: 再試行はキューが数える（ネイティブの 401 を「トークンの
///   確認」に回す、Wi-Fi 待ちを回数に数えない、などを判断するため）。
///   パッケージにも数えさせると二重になる。
/// - `allowPause: true`: Android の WorkManager は 9 分で時間切れになる。
///   一時停止できるタスクなら、ネイティブが自動で pause → 再投入して続ける。
/// - `priority: 5`: 5 未満は Android 12 以上で expedited 扱いになり、上限が
///   2 分に縮む。0（UIDT）は背面から予約できず、holding queue が背面で
///   取り出す 2 巻目以降で使えない。
/// - `requiresWiFi` は指定しない: global の `requireWiFi` が上書きする
///   （設定を変えたとき、走行中の転送にも反映させるため）。
/// - `creationTime`: holding queue は priority → creationTime（ミリ秒）の順に
///   取り出す。HDD の自宅サーバーに巻の順で読ませるため、依頼の値をそのまま使う。
DownloadTask buildDownloadTask(ArchiveTransferRequest request) => DownloadTask(
  taskId: request.taskId,
  url: request.uri.toString(),
  headers: Map.of(request.headers),
  directory: request.directory,
  filename: request.filename,
  baseDirectory: BaseDirectory.applicationSupport,
  group: archiveTransferGroup,
  updates: Updates.statusAndProgress,
  retries: 0,
  allowPause: true,
  priority: 5,
  creationTime: request.creationTime,
  displayName: request.displayName,
);

/// パッケージの更新をこのアプリのイベントに変換する。
///
/// 進捗のうち、状態を表す負の値（失敗・取り消しなど）や、バイト数に直せない
/// ものは `null`（状態の方は [TaskStatusUpdate] で別に届く）。
TransferEvent? mapTaskUpdate(TaskUpdate update) => switch (update) {
  TaskStatusUpdate() => mapStatus(update),
  TaskProgressUpdate() => mapProgress(update),
};

/// 状態の更新を変換する。
TransferStateChanged mapStatus(TaskStatusUpdate update) {
  final taskId = update.task.taskId;
  return switch (update.status) {
    // パッケージの notFound は「HTTP 404 で終わった」の意味（記録が無い、では
    // ない）。こちらでは失敗の一種として、404 の理由付きで渡す。
    TaskStatus.notFound => TransferStateChanged(
      taskId,
      TransferState.failed,
      failure: TransferFailure(
        kind: TransferFailureKind.notFound,
        httpCode: update.responseStatusCode ?? 404,
        message: update.exception?.description ?? '',
      ),
    ),
    TaskStatus.failed => TransferStateChanged(
      taskId,
      TransferState.failed,
      failure: mapException(
        update.exception,
        responseStatusCode: update.responseStatusCode,
      ),
    ),
    final status => TransferStateChanged(taskId, mapTaskStatus(status)),
  };
}

/// パッケージの状態をこのアプリの状態に変換する（一覧の突き合わせでも使う）。
///
/// [TaskStatus.notFound] は HTTP 404 で終わったことを表すので、
/// [TransferState.failed] に寄せる（[TransferState.notFound] は「パッケージが
/// 把握していない」の意味で、別物）。
TransferState mapTaskStatus(TaskStatus status) => switch (status) {
  TaskStatus.enqueued => TransferState.enqueued,
  TaskStatus.running => TransferState.running,
  TaskStatus.waitingToRetry => TransferState.waitingToRetry,
  TaskStatus.paused => TransferState.paused,
  TaskStatus.complete => TransferState.completed,
  TaskStatus.failed || TaskStatus.notFound => TransferState.failed,
  TaskStatus.canceled => TransferState.canceled,
};

/// 進捗の更新を受信バイト数に変換する。
///
/// 次のものは `null`:
/// - 負の値（`progressFailed` などの番兵）。状態の更新と重なり、進捗として
///   扱うと表示が負になる。
/// - 0 と 1。パッケージの説明どおり、このとき `expectedFileSize` は当てに
///   ならない。0 を流すと、再開直後に表示が 0 に戻ってしまう。1 の直後には
///   完了の状態が届く。
/// - 全体のサイズが分からないもの（割合をバイト数に直せない）。
TransferProgressed? mapProgress(TaskProgressUpdate update) {
  final progress = update.progress;
  if (!(progress > 0 && progress < 1)) return null;
  if (!update.hasExpectedFileSize) return null;
  final total = update.expectedFileSize;
  final received = (progress * total).round().clamp(0, total);
  return TransferProgressed(
    update.task.taskId,
    received: received,
    total: total,
  );
}

/// 失敗の理由を、キューが再試行・表示を決められる種類に変換する。
///
/// パッケージは失敗時に `responseStatusCode` を入れないことがある
/// （`TaskHttpException.httpResponseCode` の方に入る）。どちらにも無ければ
/// [responseStatusCode] を使う。
TransferFailure mapException(
  TaskException? exception, {
  int? responseStatusCode,
}) {
  final message = exception?.description ?? '';
  return switch (exception) {
    TaskHttpException(:final httpResponseCode) => _httpFailure(
      httpResponseCode,
      message,
    ),
    // 再開時に ETag が変わっていた / 弱い ETag だった（別世代が混ざる）。
    TaskResumeException() => TransferFailure(
      kind: TransferFailureKind.resumeMismatch,
      message: message,
    ),
    // 容量不足・書き込み失敗。再試行しても直らない。
    TaskFileSystemException() => TransferFailure(
      kind: TransferFailureKind.fileSystem,
      message: message,
    ),
    TaskConnectionException() => TransferFailure(
      kind: TransferFailureKind.connection,
      message: message,
    ),
    _ when responseStatusCode != null => _httpFailure(
      responseStatusCode,
      message,
    ),
    _ => TransferFailure(kind: TransferFailureKind.other, message: message),
  };
}

TransferFailure _httpFailure(int code, String message) => TransferFailure(
  kind: switch (code) {
    // タスクに焼き込んだトークンが古いだけかもしれない。再試行ではなく、
    // キューがマニフェストを取り直して本当に失効しているかを確かめる。
    401 => TransferFailureKind.unauthorized,
    403 => TransferFailureKind.forbidden,
    404 => TransferFailureKind.notFound,
    429 => TransferFailureKind.tooManyRequests,
    >= 500 && < 600 => TransferFailureKind.server,
    _ => TransferFailureKind.other,
  },
  httpCode: code,
  message: message,
);
