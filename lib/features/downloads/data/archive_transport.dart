import 'package:flutter/foundation.dart' show immutable;

/// ZIP の転送を OS のバックグラウンド転送に任せるためのポート（#10）。
///
/// アプリを閉じても 1 巻数百 MB の転送を続けるには、Dart の外（Android の
/// WorkManager / iOS の URLSession）で転送させるしかない。転送そのものは
/// ここに閉じ込め、**検証・rename・台帳の確定は Dart（`DownloadQueue`）に残す**。
/// パッケージ（`background_downloader`）の型はこのファイルに持ち込まない
/// （キューのテストをプラットフォームチャネル無しで書けるようにするため）。
abstract interface class ArchiveTransport {
  /// 転送の状態変化と進捗。broadcast。**[start] より前に購読する**
  /// （起動直後に届く、アプリが死んでいる間の完了を取りこぼさない）。
  Stream<TransferEvent> get events;

  /// 設定を反映して転送を受け付け始める。何度呼んでもよい。
  ///
  /// プラグインの自動再投入（古いトークンのまま積み直す）は使わない。
  /// 死んでいる間に消えたタスクの積み直しは、キューの照合（`_reconcile`）が
  /// 新しいトークンで行う。
  Future<void> start({
    required bool wifiOnly,
    required TransferNotificationTexts texts,
  });

  /// Wi-Fi 限定の設定を反映する（走行中の転送にも効く）。
  Future<void> setWifiOnly(bool value);

  /// 転送を積む。受け付けられなければ `false`。
  Future<bool> enqueue(ArchiveTransferRequest request);

  /// 一時停止。止められなければ `false`。
  ///
  /// **走っている（`running` が届いた）転送にだけ呼ぶ**こと。Android の
  /// パッケージは、holding queue や Wi-Fi 待ちで待機しているだけのタスクにも
  /// `true` を返す（止める印を付けるだけ）。そのタスクは待機のまま残り、
  /// 後で走り出して同時実行の枠を使ってから止まる。待機中の転送は取り消す。
  Future<bool> pause(String taskId);

  /// 再開。再開データが無ければ `false`（呼び出し側が積み直す）。
  Future<bool> resume(String taskId);

  Future<void> cancel(String taskId);

  /// いまパッケージが把握している、このアプリの転送の一覧。
  Future<List<TransferSnapshot>> snapshot();

  /// 完了 / 取り消し済みのタスクの記録と再開データを捨てる。
  Future<void> forget(String taskId);

  /// 前のセッション（ログアウト前）のタスクの記録を捨てる（#15）。
  ///
  /// [forget] と違い、パッケージが後から記録を書き戻しても消し直す
  /// （記録には前のユーザーの Bearer が平文で入っている）。同じ ID で
  /// 積み直すことのない ID にだけ使う。
  Future<void> forgetForeign(String taskId);

  /// どの転送も指していないパッケージの一時ファイルを消す。
  ///
  /// 通信の失敗で終わった転送の書きかけ（Android）が残り続けないように。
  /// 走っている転送があれば何もしない（書きかけを消すと完了時に失敗する）。
  Future<void> sweepOrphanTempFiles();

  /// 全部捨てる（ログアウト。#15）。
  ///
  /// タスクの記録には Bearer が平文で入っているので、ファイルより先に消す。
  /// パッケージの一時ファイルも消す（前のユーザーの部分データ）。
  Future<void> reset();

  /// 通知の許可を求める（Android 13 以上 / iOS）。拒否されても転送は続く。
  Future<bool> requestNotificationPermission();
}

/// 転送の状態。
enum TransferState {
  enqueued,
  running,
  waitingToRetry,
  paused,
  completed,
  failed,
  canceled,

  /// パッケージが把握していない（記録が消えた）。
  notFound,
}

/// 失敗の種類（キューが再試行するか・何と表示するかを決める）。
enum TransferFailureKind {
  /// 401。タスクに焼き込んだトークンが古いだけかもしれないので、すぐに
  /// ログアウト扱いにしない（キューがマニフェストを取り直して確かめる）。
  unauthorized,
  forbidden,
  notFound,
  server,
  tooManyRequests,
  connection,

  /// 再開しようとしたら ETag が変わっていた（別世代が混ざる）。
  resumeMismatch,
  fileSystem,
  other,
}

@immutable
class TransferFailure {
  const TransferFailure({required this.kind, this.httpCode, this.message = ''});

  final TransferFailureKind kind;
  final int? httpCode;
  final String message;

  @override
  String toString() => 'TransferFailure($kind, $httpCode, $message)';
}

@immutable
sealed class TransferEvent {
  const TransferEvent(this.taskId);

  final String taskId;
}

final class TransferProgressed extends TransferEvent {
  const TransferProgressed(super.taskId, {required this.received, this.total});

  /// 受信済みのバイト数。
  final int received;

  /// 全体のバイト数（分からなければ `null`）。
  final int? total;
}

final class TransferStateChanged extends TransferEvent {
  const TransferStateChanged(super.taskId, this.state, {this.failure});

  final TransferState state;

  /// [TransferState.failed] のときの理由。
  final TransferFailure? failure;
}

/// 1 巻ぶんの転送の依頼。
@immutable
class ArchiveTransferRequest {
  const ArchiveTransferRequest({
    required this.taskId,
    required this.uri,
    required this.headers,
    required this.directory,
    required this.filename,
    required this.creationTime,
    this.displayName = '',
  });

  final String taskId;
  final Uri uri;
  final Map<String, String> headers;

  /// アプリ専用領域（application support）からの相対ディレクトリ
  /// （`downloads/{volumeId}`）。絶対パスにしないのは、iOS ではアプリの
  /// 更新でコンテナのパスが変わるため。
  final String directory;

  /// 保存するファイル名（`{filesVersion}.zip.download`）。
  final String filename;

  /// 取得順。HDD の自宅サーバーに順に読ませるため、積んだ順に狭義単調増加に
  /// する（パッケージは同じ時刻のタスクの順序を保証しない）。
  final DateTime creationTime;

  /// 通知などに出す名前。
  final String displayName;
}

@immutable
class TransferSnapshot {
  const TransferSnapshot({
    required this.taskId,
    required this.state,
    this.hasResumeData = false,
  });

  final String taskId;
  final TransferState state;
  final bool hasResumeData;
}

/// 通知の文言（パッケージのプレースホルダ `{numFinished}` などを含めてよい）。
@immutable
class TransferNotificationTexts {
  const TransferNotificationTexts({
    this.runningTitle = 'ダウンロード中',
    this.runningBody = '{numFinished} / {numTotal} 巻',
    // 「読めます」とは書かない。この時点ではまだ検証（ZIP として開けるか）の前。
    this.completeTitle = 'ダウンロードが終わりました',
    this.completeBody = '{numFinished} 巻を受信しました',
    this.errorTitle = 'ダウンロードに失敗しました',
    this.errorBody = '{numFailed} 巻を取得できませんでした',
  });

  final String runningTitle;
  final String runningBody;
  final String completeTitle;
  final String completeBody;
  final String errorTitle;
  final String errorBody;
}
