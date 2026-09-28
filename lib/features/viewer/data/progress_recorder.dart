import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/api/user_api.dart';

part 'progress_recorder.g.dart';

/// 読書進捗の記録先。
///
/// #12 でローカルキュー（drift）+ オンライン復帰時の一括同期に差し替える。
/// 現状はその場でサーバーへ送り、失敗は握る（次の機会に送り直す）。
abstract interface class ProgressRecorder {
  /// 進捗を記録する。送信できたかどうかを返す。
  Future<bool> record({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  });
}

class ApiProgressRecorder implements ProgressRecorder {
  const ApiProgressRecorder(this._api);

  final UserApi _api;

  @override
  Future<bool> record({
    required int volumeId,
    required int currentPage,
    required int maxPage,
    required DateTime readAt,
  }) async {
    try {
      await _api.recordVolumeStatus(
        volumeId: volumeId,
        currentPage: currentPage,
        maxPage: maxPage,
        readAt: readAt,
      );
      return true;
    } on ApiException {
      // 圏外・失敗しても読書は止めない。#12 でローカルに貯めて後で送る。
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
ProgressRecorder progressRecorder(Ref ref) =>
    ApiProgressRecorder(ref.watch(userApiProvider));
