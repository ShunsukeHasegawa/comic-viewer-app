import 'package:comic_laz/features/downloads/domain/archive_task_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('アプリが死んでいる間に届いた完了を巻・世代・セッションに戻せるよう、往復で同じ値に戻る', () {
    const id = ArchiveTaskId(
      volumeId: 12,
      filesVersion: 1700000000,
      sessionTag: 'a1B2c3D4e5F6',
    );
    final text = id.toString();
    expect(text, 'v12.f1700000000.sa1B2c3D4e5F6');
    expect(ArchiveTaskId.tryParse(text), id);
  });

  test('他の用途の taskId は取り込まないよう null にする', () {
    // パッケージが既定で振る乱数の ID など。
    expect(ArchiveTaskId.tryParse('1234567890'), isNull);
    expect(ArchiveTaskId.tryParse('volume-12'), isNull);
  });

  test('壊れた taskId は取り違えないよう null にする', () {
    expect(ArchiveTaskId.tryParse(''), isNull);
    expect(ArchiveTaskId.tryParse('v12.f1'), isNull);
    expect(ArchiveTaskId.tryParse('v12.f1.s'), isNull);
    expect(ArchiveTaskId.tryParse('v12.f1.sabc.extra'), isNull);
    expect(ArchiveTaskId.tryParse('vx.f1.sabc'), isNull);
    expect(ArchiveTaskId.tryParse(' v12.f1.sabc'), isNull);
    expect(ArchiveTaskId.tryParse('v12.f1.sab-c'), isNull);
  });

  test('負の値はありえない巻・世代なので null にする', () {
    expect(ArchiveTaskId.tryParse('v-12.f1.sabc'), isNull);
    expect(ArchiveTaskId.tryParse('v12.f-1.sabc'), isNull);
  });

  test('巻・世代・セッションのどれかが違えば別のタスクとして扱う', () {
    const base = ArchiveTaskId(volumeId: 1, filesVersion: 2, sessionTag: 'a');
    expect(
      base,
      isNot(const ArchiveTaskId(volumeId: 1, filesVersion: 3, sessionTag: 'a')),
    );
    expect(
      base,
      isNot(const ArchiveTaskId(volumeId: 1, filesVersion: 2, sessionTag: 'b')),
    );
    expect(
      base.hashCode,
      const ArchiveTaskId(
        volumeId: 1,
        filesVersion: 2,
        sessionTag: 'a',
      ).hashCode,
    );
  });
}
