import 'package:comic_laz/features/downloads/data/task_record_scrubber.dart';
import 'package:flutter_test/flutter_test.dart';

/// パッケージのタスク記録の保存領域を模す。
///
/// 本物（`base_downloader.dart`）と同じく、状態の更新による記録の書き込みは
/// 非同期のキューに積まれ、呼び出し元（ログアウトの削除）とは関係なく後から
/// 終わる。記録にはタスクの JSON（`Authorization: Bearer ...` 入り）が入る。
class _FakeRecordStore {
  final records = <String, String>{};
  Future<void> _writes = Future.value();

  /// 状態の更新が届いた（パッケージは書き込みを積んでから通知する）。
  void queueWrite(String taskId, {Duration after = Duration.zero}) {
    _writes = _writes.then((_) async {
      await Future<void>.delayed(after);
      records[taskId] = '{"headers":{"Authorization":"Bearer old-token"}}';
    });
  }

  Future<void> erase(String taskId) async => records.remove(taskId);

  Future<bool> exists(String taskId) async => records.containsKey(taskId);

  Future<void> get drained => _writes;
}

void main() {
  late _FakeRecordStore store;
  late TaskRecordScrubber scrubber;

  setUp(() {
    store = _FakeRecordStore();
    scrubber = TaskRecordScrubber(
      erase: store.erase,
      exists: store.exists,
      delay: const Duration(milliseconds: 5),
    );
  });

  test('ログアウトで消した後に取り消しの書き戻しが来ても、Bearer 入りの記録を残さない', () async {
    // ログアウト: 記録を消して取り消しを頼んだ。canceled の書き込みは後から来る。
    store.records['v1.f1.sold'] = 'token';
    await store.erase('v1.f1.sold');
    store.queueWrite('v1.f1.sold', after: const Duration(milliseconds: 3));
    scrubber.purge(['v1.f1.sold']);

    await store.drained;
    await scrubber.idle;

    expect(store.records, isEmpty, reason: '1 回消すだけでは非同期の書き戻しに負ける（#15）');
  });

  test('消した ID の更新が後から届いたら、その書き戻しも消し直す', () async {
    scrubber.purge(['v1.f1.sold']);
    await scrubber.idle;

    // アプリが生きている間に、遅れて canceled が届いた。
    store.queueWrite('v1.f1.sold');
    scrubber.onUpdate('v1.f1.sold');
    await store.drained;
    await scrubber.idle;

    expect(store.records, isEmpty);
  });

  test('消すと決めていない ID の更新では記録に触らない', () async {
    // 今のセッションの ID は同じ ID で積み直すので、新しい転送の記録まで消さない。
    store.records['v1.f1.snew'] = 'current';
    scrubber.onUpdate('v1.f1.snew');
    await scrubber.idle;

    expect(store.records, contains('v1.f1.snew'));
    expect(scrubber.isPurged('v1.f1.snew'), isFalse);
  });

  test('書き戻しが続いても、消し直しは上限の回数で止まる（無限に回さない）', () async {
    var erases = 0;
    final stubborn = TaskRecordScrubber(
      erase: (_) async => erases++,
      exists: (_) async => true,
      delay: Duration.zero,
      maxRounds: 3,
    );
    stubborn.purge(['v1.f1.sold']);
    await stubborn.idle;

    expect(erases, 3);
  });
}
