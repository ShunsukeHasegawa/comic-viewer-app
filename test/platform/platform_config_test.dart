import 'dart:io';

import 'package:comic_laz/core/device/device_protection.dart';
import 'package:flutter_test/flutter_test.dart';

/// 端末の設定ファイル（#15）の退行を防ぐ。リポジトリのファイルを読むだけ。
///
/// どれもビルドやテストでは壊れたことに気づけない（バックアップは実機の
/// 復元でしか確かめられない）ので、文字列で押さえておく。
void main() {
  String read(String path) => File(path).readAsStringSync();

  const manifestPath = 'android/app/src/main/AndroidManifest.xml';
  const extractionRulesPath =
      'android/app/src/main/res/xml/data_extraction_rules.xml';
  const backupRulesPath = 'android/app/src/main/res/xml/backup_rules.xml';

  /// XML のコメントを除く（コメント内の説明文に引っかからないように）。
  String withoutComments(String xml) =>
      xml.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  test(
    'AndroidManifest はバックアップを無効にし、端末間転送の除外ルールを参照する（ZIP とトークン入りの記録を持ち出させないため）',
    () {
      final manifest = withoutComments(read(manifestPath));

      expect(manifest, contains('android:allowBackup="false"'));
      expect(
        manifest,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(
        manifest,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );
    },
  );

  test('データ抽出ルールは cloud-backup と device-transfer の両方で全領域を除外する（DB だけ復元されると台帳と ZIP が食い違うため）', () {
    final rules = withoutComments(read(extractionRulesPath));
    const domains = ['root', 'file', 'database', 'sharedpref', 'external'];

    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp(
        '<$section>(.*?)</$section>',
        dotAll: true,
      ).firstMatch(rules)?.group(1);
      expect(body, isNotNull, reason: '$section が無い');
      for (final domain in domains) {
        expect(
          body,
          contains('<exclude domain="$domain" path="." />'),
          reason: '$section で $domain を除外していない',
        );
      }
      expect(body, isNot(contains('<include')), reason: '一部だけ戻さない');
    }
  });

  test('Android 11 以下のバックアップ規則も全領域を除外する（allowBackup を戻されたときの保険）', () {
    final rules = withoutComments(read(backupRulesPath));

    for (final domain in ['root', 'file', 'database', 'sharedpref']) {
      expect(rules, contains('<exclude domain="$domain" path="." />'));
    }
    expect(rules, isNot(contains('<include')));
  });

  test('Info.plist は Files アプリへの公開を有効にしない（ダウンロードした ZIP をファイルアプリに出さないため）', () {
    final plist = read('ios/Runner/Info.plist');

    expect(plist, isNot(contains('UIFileSharingEnabled')));
    expect(plist, isNot(contains('LSSupportsOpeningDocumentsInPlace')));
  });

  // Android はバックアップ除外をマニフェストで行うのでチャネルを持たない（iOS だけ）。
  test('iOS のチャネル名が Dart 側と一致する（食い違うと保護が黙って掛からないため）', () {
    const name = MethodChannelDeviceProtection.channelName;

    expect(read('ios/Runner/AppDelegate.swift'), contains('"$name"'));
  });
}
