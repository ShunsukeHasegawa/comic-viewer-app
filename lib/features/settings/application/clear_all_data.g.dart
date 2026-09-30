// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clear_all_data.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 「すべてのデータを削除」（#13）。
///
/// 消すもの: ダウンロード済みの巻（転送中・書きかけを含む）、一時キャッシュ
/// （ページ + サムネイル。メモリ上の画像も）、ダウンロードが無くなった
/// タイトルのオフライン用の控え、自動削除の記録。
///
/// **消さないもの**: 未送信の読書進捗（サーバーにも無い = 失うと戻らない）、
/// 設定、ログイン状態、一覧の控え（数百 KB。圏外で一覧を出し続けるため）。
/// ログアウトはしない。
///
/// 1 つの手順が失敗しても残りは続ける（途中で止めると「ダウンロードは
/// 消えたがキャッシュは残った」状態を黙って作る）。

@ProviderFor(clearAllData)
final clearAllDataProvider = ClearAllDataProvider._();

/// 「すべてのデータを削除」（#13）。
///
/// 消すもの: ダウンロード済みの巻（転送中・書きかけを含む）、一時キャッシュ
/// （ページ + サムネイル。メモリ上の画像も）、ダウンロードが無くなった
/// タイトルのオフライン用の控え、自動削除の記録。
///
/// **消さないもの**: 未送信の読書進捗（サーバーにも無い = 失うと戻らない）、
/// 設定、ログイン状態、一覧の控え（数百 KB。圏外で一覧を出し続けるため）。
/// ログアウトはしない。
///
/// 1 つの手順が失敗しても残りは続ける（途中で止めると「ダウンロードは
/// 消えたがキャッシュは残った」状態を黙って作る）。

final class ClearAllDataProvider
    extends $FunctionalProvider<ClearAllData, ClearAllData, ClearAllData>
    with $Provider<ClearAllData> {
  /// 「すべてのデータを削除」（#13）。
  ///
  /// 消すもの: ダウンロード済みの巻（転送中・書きかけを含む）、一時キャッシュ
  /// （ページ + サムネイル。メモリ上の画像も）、ダウンロードが無くなった
  /// タイトルのオフライン用の控え、自動削除の記録。
  ///
  /// **消さないもの**: 未送信の読書進捗（サーバーにも無い = 失うと戻らない）、
  /// 設定、ログイン状態、一覧の控え（数百 KB。圏外で一覧を出し続けるため）。
  /// ログアウトはしない。
  ///
  /// 1 つの手順が失敗しても残りは続ける（途中で止めると「ダウンロードは
  /// 消えたがキャッシュは残った」状態を黙って作る）。
  ClearAllDataProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clearAllDataProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clearAllDataHash();

  @$internal
  @override
  $ProviderElement<ClearAllData> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ClearAllData create(Ref ref) {
    return clearAllData(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClearAllData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClearAllData>(value),
    );
  }
}

String _$clearAllDataHash() => r'65eb055e2b1cc3e8d3888b8ce6ec75e414ba510e';
