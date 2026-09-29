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
///   ただしこの再投入は holding queue を迂回するので、foreground 実行で
///   時間切れそのものを避ける（[foregroundModeFor]）。これは foreground に
///   移れなかったタスクの保険。
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
    // 容量不足・書き込み失敗は再試行しても直らない。ただし Android は
    // `TaskRunner.setTaskException` で SocketException 以外の IOException を
    // すべて fileSystem にする（本文の途中で切れた `ProtocolException:
    // unexpected end of stream`、TLS の `SSLException: Connection reset`、
    // `UnknownHostException` など）。型だけでは回線の瞬断と容量不足を
    // 見分けられないので、端末側の問題だと文言で分かるものだけを fileSystem
    // にし、残りは待てば直る connection として再試行に回す。
    TaskFileSystemException() => TransferFailure(
      kind: isStorageFailureMessage(message)
          ? TransferFailureKind.fileSystem
          : TransferFailureKind.connection,
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

/// 失敗の文言が「端末の保存領域の問題」を表しているか。
///
/// パッケージの失敗は errno を持たないので文言で見る。当てはまらない
/// `TaskFileSystemException` は回線の問題として扱う（[mapException]）。
/// 取りこぼして回線扱いにしても、再試行の上限（3 回）で失敗に落ちるので
/// 自宅サーバーを叩き続けることはない。逆に回線の瞬断を fileSystem に
/// 取り違えると、数百 MB の転送が一度で恒久的に失敗する。
bool isStorageFailureMessage(String message) =>
    _storageFailurePattern.hasMatch(message);

final _storageFailurePattern = RegExp(
  [
    // 容量不足（Android の事前チェック / iOS / errno 28）
    'ENOSPC',
    'no space',
    'not enough space',
    'insufficient space',
    'disk full',
    'EDQUOT',
    'quota',
    // 権限・読み取り専用
    'EACCES',
    'EROFS',
    'EPERM',
    'permission denied',
    'read-only file system',
    // パッケージ自身のファイル操作（書き込み先の用意・移動）
    'file operation failed',
    'could not determine directory',
    'invalid directory',
    'failed to create document',
    'failed to open output stream',
    'FileSystemException',
    'NoSuchFileException',
    'FileNotFoundException',
  ].join('|'),
  caseSensitive: false,
);

/// `FileDownloader.start` に渡す設定。
///
/// - `doRescheduleKilledTasks: false`: プラグインの自動再投入（5 秒後）は
///   古いトークンのまま積み直し、キューの照合と二重に投入するので使わない。
/// - `autoCleanDatabase: false`: 自動の間引きは `creationTime`（投入時刻）で
///   状態に関係なく記録を消す。10 日より前に積んだ巻がアプリの死んでいる間に
///   終わると、照合（snapshot）より先に記録が消え、書き上がった ZIP が
///   孤児として掃除されてしまう。記録はキューが終わったタスクごとに
///   `forget` で消すので、自動で間引かなくても増え続けない。
const archiveTransferStartOptions = (
  doRescheduleKilledTasks: false,
  autoCleanDatabase: false,
);

/// Android の foreground 実行（`Config.runInForeground`）の設定値。
///
/// foreground で走るタスクには WorkManager の 9 分の時間切れが無い
/// （`TaskRunner.kt` の `isTimedOut && !runInForeground`）。時間切れの
/// 再投入は holding queue を通らず（`DownloadTaskRunner.kt` の
/// `BDPlugin.doEnqueue(..., 1000)`）、しかも holding queue の同時実行数を
/// 先に 1 減らすので、自宅サーバーの HDD を 2 本以上で同時に読ませてしまう。
///
/// ただし**通知の許可が無いときは使わない**。パッケージは許可を確かめずに
/// `runInForeground` を立て、通知を出せないので foreground にも移れない
/// （`Notifications.kt` の `displayNotification` が黙って戻る）。すると
/// 9 分の pause も起きないまま WorkManager の 10 分の上限で止められ、
/// 長い巻が毎回失敗する。
///
/// 許可は後から取り消せる。パッケージは保存した値だけを見るので、取り消し後も
/// 「always」のまま走る。アプリが開いている間の取り消しは前面復帰のたびに
/// 合わせ直し（`ArchiveTransport.refreshForegroundMode`）、閉じている間の
/// 取り消しはネイティブの `ComicLazApplication` がプロセスの起動時に
/// 「never」へ直す（取り消しはプロセスを殺すので、次のワーカーは必ずそこを通る）。
///
/// 残る穴: Android 12 以上ではアプリが背面にいる間に foreground へ移れない。
/// holding queue が背面で取り出した 2 巻目以降はパッケージが通常実行に
/// 戻す（`setForegroundNotification` の例外を拾って `runInForeground =
/// false`）ので、9 分を超える巻では同時実行数 1 が崩れうる（HDD を 2 本で
/// 読む。データが壊れることはない）。実機で logcat の「paused due to
/// timeout」の後に別の巻の「Starting task」が続かないかを確かめる。
String foregroundModeFor({required bool notificationsGranted}) =>
    notificationsGranted ? Config.always : Config.never;

/// 起動時の一覧（`TransferSnapshot`）を組み立てる。
///
/// - [records]: パッケージの記録（最後に届いた状態）。
/// - [listedIds]: `allTasks` が返した ID を**重複ごと**並べたもの。
///   `allTasks` はネイティブの待機中 / 走行中に、Dart 側の一時停止中
///   （`getPausedTasks`）と再試行待ちを足して返す。
/// - [resumeIds]: 再開データがある ID。
/// - [pausedIds]: Dart 側の一時停止中の ID。
///
/// 一時停止中のタスクを「ネイティブが持っている = 生きている」と数えると
/// enqueued に化け、照合がユーザーの止めた転送を取り消して再開データと
/// 書きかけを捨ててしまう（起動のたびに数百 MB がやり直しになる）。
/// なので一時停止の保存領域から来た分を引いてから、ネイティブが持って
/// いるかを判断する。
///
/// 集合の差ではなく**個数で**引くのは、9 分の時間切れで止まったタスクが
/// 「Dart 側の一時停止中」に残ったままネイティブで走り直すため（パッケージは
/// 最終状態まで一時停止の記録を消さない）。その ID は 2 回並ぶ。差を取ると
/// 走っている転送を一時停止と見なし、照合が同じタスクを二重に再開してしまう。
List<TransferSnapshot> mergeTransferSnapshots({
  required Iterable<(String, TaskStatus)> records,
  required List<String> listedIds,
  required Set<String> resumeIds,
  required Set<String> pausedIds,
}) {
  final counts = <String, int>{};
  for (final taskId in listedIds) {
    counts[taskId] = (counts[taskId] ?? 0) + 1;
  }
  final nativeIds = {
    for (final MapEntry(key: taskId, value: count) in counts.entries)
      if (count - (pausedIds.contains(taskId) ? 1 : 0) > 0) taskId,
  };
  bool isAlive(TransferState? state) =>
      state == TransferState.enqueued ||
      state == TransferState.running ||
      state == TransferState.waitingToRetry;

  final states = <String, TransferState>{};
  for (final (taskId, status) in records) {
    final state = mapTaskStatus(status);
    if (isAlive(state) && !nativeIds.contains(taskId)) {
      // 記録は「走行中」なのにネイティブが知らない。一時停止として残って
      // いれば再開データから続きを取れる。無ければプロセスごと殺されて
      // 消えた（holding queue の中身はメモリにしか無い）ので積み直しが要る。
      states[taskId] = pausedIds.contains(taskId)
          ? TransferState.paused
          : TransferState.notFound;
    } else {
      states[taskId] = state;
    }
  }
  for (final taskId in nativeIds) {
    // 記録が遅れていても、ネイティブが持っているなら生きている。
    if (!isAlive(states[taskId])) states[taskId] = TransferState.enqueued;
  }
  for (final taskId in {...resumeIds, ...pausedIds}) {
    states.putIfAbsent(taskId, () => TransferState.paused);
  }
  return [
    for (final MapEntry(key: taskId, value: state) in states.entries)
      TransferSnapshot(
        taskId: taskId,
        state: state,
        hasResumeData: resumeIds.contains(taskId),
      ),
  ];
}
