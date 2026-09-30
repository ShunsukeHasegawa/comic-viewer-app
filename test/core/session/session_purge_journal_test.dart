import 'package:comic_laz/core/session/session_data_purger.dart';
import 'package:comic_laz/core/session/session_purge_journal.dart';
import 'package:comic_laz/core/storage/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftSessionPurgeJournal journal;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    journal = DriftSessionPurgeJournal(database);
    addTearDown(database.close);
  });

  test('印が無ければ null', () async {
    expect(await journal.readPending(), isNull);
  });

  test('書いた範囲を読み返せる（アプリが落ちても次の起動で分かるように）', () async {
    await journal.markPending(SessionPurgeScope.refetchable);

    expect(await journal.readPending(), SessionPurgeScope.refetchable);
  });

  test('全部消す印を、取り直せるものだけの印で上書きしない（消し損ねたログアウトを忘れないため）', () async {
    await journal.markPending(SessionPurgeScope.session);
    await journal.markPending(SessionPurgeScope.refetchable);

    expect(await journal.readPending(), SessionPurgeScope.session);
  });

  test('取り直せるものだけの破棄が済んでも、全部消す印は残す', () async {
    await journal.markPending(SessionPurgeScope.session);

    await journal.complete(SessionPurgeScope.refetchable);

    expect(await journal.readPending(), SessionPurgeScope.session);
  });

  test('全部消す破棄が済めば、どちらの印も消える', () async {
    await journal.markPending(SessionPurgeScope.refetchable);

    await journal.complete(SessionPurgeScope.session);

    expect(await journal.readPending(), isNull);
  });

  test('読めない値は全部消す側に倒す（持ち主を確かめられないデータを残さないため）', () async {
    await database
        .into(database.settings)
        .insert(
          const SettingRow(key: DriftSessionPurgeJournal.key, value: '???'),
        );

    expect(await journal.readPending(), SessionPurgeScope.session);
  });
}
