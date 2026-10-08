import 'package:comic_laz/core/storage/app_database.dart';
import 'package:comic_laz/features/viewer/data/open_volume_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// 他のテストは `InMemoryOpenVolumeStore` を使うので、drift に置く形はここで確かめる。
void main() {
  late AppDatabase database;
  late DriftOpenVolumeStore store;

  const volume = OpenVolume(
    bookId: 12,
    volumeId: 340,
    title: '進撃の巨人',
    volume: 3,
  );

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = DriftOpenVolumeStore(database);
    addTearDown(database.close);
  });

  test('作り直した store（= 次の起動）でも読み返せる', () async {
    await store.save(volume);

    final saved = await DriftOpenVolumeStore(database).read();

    expect(saved?.bookId, 12);
    expect(saved?.volumeId, 340);
    expect(saved?.title, '進撃の巨人');
    expect(saved?.volume, 3);
  });

  test('別の巻の後始末では消さない（次の巻へ進んだ直後に控えを失わない）', () async {
    await store.save(volume);

    await store.clearIfVolume(339);
    expect(await store.read(), isNotNull);

    await store.clearIfVolume(340);
    expect(await store.read(), isNull);
  });

  test('読み解けない控えは「無し」として扱う（起動を止めない）', () async {
    await database
        .into(database.settings)
        .insertOnConflictUpdate(
          const SettingRow(key: DriftOpenVolumeStore.key, value: '{broken'),
        );

    expect(await store.read(), isNull);
  });

  test('ログアウトでは捨て、safe_mode の変更でも捨てる（見せられないタイトルを尋ねない）', () async {
    await store.save(volume);
    final purger = OpenVolumePurger(() => store);

    expect(purger.purgesRefetchableOnly, isTrue);
    await purger.purgeSessionData();
    expect(await store.read(), isNull);
  });
}
