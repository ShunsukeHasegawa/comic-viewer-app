// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'safe_mode_revalidator.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(safeModeRevalidationClock)
final safeModeRevalidationClockProvider = SafeModeRevalidationClockProvider._();

final class SafeModeRevalidationClockProvider
    extends
        $FunctionalProvider<
          SafeModeRevalidationClock,
          SafeModeRevalidationClock,
          SafeModeRevalidationClock
        >
    with $Provider<SafeModeRevalidationClock> {
  SafeModeRevalidationClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'safeModeRevalidationClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$safeModeRevalidationClockHash();

  @$internal
  @override
  $ProviderElement<SafeModeRevalidationClock> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SafeModeRevalidationClock create(Ref ref) {
    return safeModeRevalidationClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SafeModeRevalidationClock value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SafeModeRevalidationClock>(value),
    );
  }
}

String _$safeModeRevalidationClockHash() =>
    r'88879202e480c1586dd0c68cc2911a0f9900a552';

/// セーフモードが ON になったあと、ダウンロード済みの巻を確かめ直す（#15）。
///
/// **自動削除（`AutoDeleteRunner`）とは別物**。あちらはユーザーが選んだ規則で
/// 読み終えた巻を消し、こちらは「サーバーがもう配信しない巻」を消す。
///
/// `safe_mode` の変更で一括削除はしない（同じユーザーの数 GB と、サーバーにも
/// 無い読書位置を黙って消さない。#11）。代わりにダウンロード済みの巻を持つ
/// タイトルを 1 件ずつ `GET /api/v2/books/{id}` で問い合わせ、**404 が返った
/// タイトルだけ**消す。サーバーは `is_unsafe` のタイトルをセーフモードの
/// ユーザーに 404 で返す（`V2\BookController::show` の `isHiddenBySafeMode`）。
///
/// 404 は「非公開」以外でも返る（プロキシの誤設定・ルートの欠け・DB の障害）ので、
/// 消すのは次の 3 つが揃ったタイトルだけにする（1 回の障害で数 GB を全部消さない）。
///   1. 404 の本文がコントローラの JSON（`{"message": "Not Found"}`）。
///   2. その回の問い合わせが通信エラー無しで最後まで終わった。
///   3. 一覧（`/api/books`。セーフモードでは `is_unsafe` を除いた版）が空でなく、
///      そのタイトルが載っていない。
///
/// - 通信エラー・タイムアウト・5xx・429・401・想定外の 404 では何も消さず、
///   予約を残して次の機会（前面復帰 / 回線復帰 / 次の起動・ログイン）にやり直す。
///   前面復帰 / 回線復帰は [resumeInterval] に 1 回までに間引く。
///   「オフラインか」は実際の通信結果で判断する（回線の監視は合図だけ）。
/// - 403 はリソース単位の権限エラーで、セーフモードの判定ではないので消さない。
/// - 200 なら、一覧に無い巻があっても消さない（`is_unsafe` はタイトル単位。
///   巻の欠けには処理中・削除など別の理由がありうる）。
/// - 巻単位の manifest ではなくタイトル単位の詳細を使うのは、問い合わせが
///   タイトル数で済み、manifest はサーバーで ZIP を開くことがあるため。
/// - いまビューアで開いている巻は消さずに予約を残す（読んでいる途中の ZIP を
///   消して表示を壊さない）。
///
/// state は直近に消した結果（何も消していなければ `null`）。

@ProviderFor(SafeModeRevalidator)
final safeModeRevalidatorProvider = SafeModeRevalidatorProvider._();

/// セーフモードが ON になったあと、ダウンロード済みの巻を確かめ直す（#15）。
///
/// **自動削除（`AutoDeleteRunner`）とは別物**。あちらはユーザーが選んだ規則で
/// 読み終えた巻を消し、こちらは「サーバーがもう配信しない巻」を消す。
///
/// `safe_mode` の変更で一括削除はしない（同じユーザーの数 GB と、サーバーにも
/// 無い読書位置を黙って消さない。#11）。代わりにダウンロード済みの巻を持つ
/// タイトルを 1 件ずつ `GET /api/v2/books/{id}` で問い合わせ、**404 が返った
/// タイトルだけ**消す。サーバーは `is_unsafe` のタイトルをセーフモードの
/// ユーザーに 404 で返す（`V2\BookController::show` の `isHiddenBySafeMode`）。
///
/// 404 は「非公開」以外でも返る（プロキシの誤設定・ルートの欠け・DB の障害）ので、
/// 消すのは次の 3 つが揃ったタイトルだけにする（1 回の障害で数 GB を全部消さない）。
///   1. 404 の本文がコントローラの JSON（`{"message": "Not Found"}`）。
///   2. その回の問い合わせが通信エラー無しで最後まで終わった。
///   3. 一覧（`/api/books`。セーフモードでは `is_unsafe` を除いた版）が空でなく、
///      そのタイトルが載っていない。
///
/// - 通信エラー・タイムアウト・5xx・429・401・想定外の 404 では何も消さず、
///   予約を残して次の機会（前面復帰 / 回線復帰 / 次の起動・ログイン）にやり直す。
///   前面復帰 / 回線復帰は [resumeInterval] に 1 回までに間引く。
///   「オフラインか」は実際の通信結果で判断する（回線の監視は合図だけ）。
/// - 403 はリソース単位の権限エラーで、セーフモードの判定ではないので消さない。
/// - 200 なら、一覧に無い巻があっても消さない（`is_unsafe` はタイトル単位。
///   巻の欠けには処理中・削除など別の理由がありうる）。
/// - 巻単位の manifest ではなくタイトル単位の詳細を使うのは、問い合わせが
///   タイトル数で済み、manifest はサーバーで ZIP を開くことがあるため。
/// - いまビューアで開いている巻は消さずに予約を残す（読んでいる途中の ZIP を
///   消して表示を壊さない）。
///
/// state は直近に消した結果（何も消していなければ `null`）。
final class SafeModeRevalidatorProvider
    extends
        $NotifierProvider<SafeModeRevalidator, SafeModeRevalidationResult?> {
  /// セーフモードが ON になったあと、ダウンロード済みの巻を確かめ直す（#15）。
  ///
  /// **自動削除（`AutoDeleteRunner`）とは別物**。あちらはユーザーが選んだ規則で
  /// 読み終えた巻を消し、こちらは「サーバーがもう配信しない巻」を消す。
  ///
  /// `safe_mode` の変更で一括削除はしない（同じユーザーの数 GB と、サーバーにも
  /// 無い読書位置を黙って消さない。#11）。代わりにダウンロード済みの巻を持つ
  /// タイトルを 1 件ずつ `GET /api/v2/books/{id}` で問い合わせ、**404 が返った
  /// タイトルだけ**消す。サーバーは `is_unsafe` のタイトルをセーフモードの
  /// ユーザーに 404 で返す（`V2\BookController::show` の `isHiddenBySafeMode`）。
  ///
  /// 404 は「非公開」以外でも返る（プロキシの誤設定・ルートの欠け・DB の障害）ので、
  /// 消すのは次の 3 つが揃ったタイトルだけにする（1 回の障害で数 GB を全部消さない）。
  ///   1. 404 の本文がコントローラの JSON（`{"message": "Not Found"}`）。
  ///   2. その回の問い合わせが通信エラー無しで最後まで終わった。
  ///   3. 一覧（`/api/books`。セーフモードでは `is_unsafe` を除いた版）が空でなく、
  ///      そのタイトルが載っていない。
  ///
  /// - 通信エラー・タイムアウト・5xx・429・401・想定外の 404 では何も消さず、
  ///   予約を残して次の機会（前面復帰 / 回線復帰 / 次の起動・ログイン）にやり直す。
  ///   前面復帰 / 回線復帰は [resumeInterval] に 1 回までに間引く。
  ///   「オフラインか」は実際の通信結果で判断する（回線の監視は合図だけ）。
  /// - 403 はリソース単位の権限エラーで、セーフモードの判定ではないので消さない。
  /// - 200 なら、一覧に無い巻があっても消さない（`is_unsafe` はタイトル単位。
  ///   巻の欠けには処理中・削除など別の理由がありうる）。
  /// - 巻単位の manifest ではなくタイトル単位の詳細を使うのは、問い合わせが
  ///   タイトル数で済み、manifest はサーバーで ZIP を開くことがあるため。
  /// - いまビューアで開いている巻は消さずに予約を残す（読んでいる途中の ZIP を
  ///   消して表示を壊さない）。
  ///
  /// state は直近に消した結果（何も消していなければ `null`）。
  SafeModeRevalidatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'safeModeRevalidatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$safeModeRevalidatorHash();

  @$internal
  @override
  SafeModeRevalidator create() => SafeModeRevalidator();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SafeModeRevalidationResult? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SafeModeRevalidationResult?>(value),
    );
  }
}

String _$safeModeRevalidatorHash() =>
    r'805780be76e176c1c6ec6530e6c01bc863047e60';

/// セーフモードが ON になったあと、ダウンロード済みの巻を確かめ直す（#15）。
///
/// **自動削除（`AutoDeleteRunner`）とは別物**。あちらはユーザーが選んだ規則で
/// 読み終えた巻を消し、こちらは「サーバーがもう配信しない巻」を消す。
///
/// `safe_mode` の変更で一括削除はしない（同じユーザーの数 GB と、サーバーにも
/// 無い読書位置を黙って消さない。#11）。代わりにダウンロード済みの巻を持つ
/// タイトルを 1 件ずつ `GET /api/v2/books/{id}` で問い合わせ、**404 が返った
/// タイトルだけ**消す。サーバーは `is_unsafe` のタイトルをセーフモードの
/// ユーザーに 404 で返す（`V2\BookController::show` の `isHiddenBySafeMode`）。
///
/// 404 は「非公開」以外でも返る（プロキシの誤設定・ルートの欠け・DB の障害）ので、
/// 消すのは次の 3 つが揃ったタイトルだけにする（1 回の障害で数 GB を全部消さない）。
///   1. 404 の本文がコントローラの JSON（`{"message": "Not Found"}`）。
///   2. その回の問い合わせが通信エラー無しで最後まで終わった。
///   3. 一覧（`/api/books`。セーフモードでは `is_unsafe` を除いた版）が空でなく、
///      そのタイトルが載っていない。
///
/// - 通信エラー・タイムアウト・5xx・429・401・想定外の 404 では何も消さず、
///   予約を残して次の機会（前面復帰 / 回線復帰 / 次の起動・ログイン）にやり直す。
///   前面復帰 / 回線復帰は [resumeInterval] に 1 回までに間引く。
///   「オフラインか」は実際の通信結果で判断する（回線の監視は合図だけ）。
/// - 403 はリソース単位の権限エラーで、セーフモードの判定ではないので消さない。
/// - 200 なら、一覧に無い巻があっても消さない（`is_unsafe` はタイトル単位。
///   巻の欠けには処理中・削除など別の理由がありうる）。
/// - 巻単位の manifest ではなくタイトル単位の詳細を使うのは、問い合わせが
///   タイトル数で済み、manifest はサーバーで ZIP を開くことがあるため。
/// - いまビューアで開いている巻は消さずに予約を残す（読んでいる途中の ZIP を
///   消して表示を壊さない）。
///
/// state は直近に消した結果（何も消していなければ `null`）。

abstract class _$SafeModeRevalidator
    extends $Notifier<SafeModeRevalidationResult?> {
  SafeModeRevalidationResult? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<SafeModeRevalidationResult?, SafeModeRevalidationResult?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                SafeModeRevalidationResult?,
                SafeModeRevalidationResult?
              >,
              SafeModeRevalidationResult?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
