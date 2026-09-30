// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_cleanup_notice.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ログイン時に前回のデータを消し切れなかったことを画面へ知らせる合図（#15）。
///
/// 個人用アプリなので、消し残しがあってもログインは止めない（`AuthController`
/// の説明）。その代わり黙って通さず、`ComicLazApp` が SnackBar で 1 回知らせる。
/// state は知らせるべき回数の通し番号（増えたときだけ表示する）。

@ProviderFor(SessionCleanupNotice)
final sessionCleanupNoticeProvider = SessionCleanupNoticeProvider._();

/// ログイン時に前回のデータを消し切れなかったことを画面へ知らせる合図（#15）。
///
/// 個人用アプリなので、消し残しがあってもログインは止めない（`AuthController`
/// の説明）。その代わり黙って通さず、`ComicLazApp` が SnackBar で 1 回知らせる。
/// state は知らせるべき回数の通し番号（増えたときだけ表示する）。
final class SessionCleanupNoticeProvider
    extends $NotifierProvider<SessionCleanupNotice, int> {
  /// ログイン時に前回のデータを消し切れなかったことを画面へ知らせる合図（#15）。
  ///
  /// 個人用アプリなので、消し残しがあってもログインは止めない（`AuthController`
  /// の説明）。その代わり黙って通さず、`ComicLazApp` が SnackBar で 1 回知らせる。
  /// state は知らせるべき回数の通し番号（増えたときだけ表示する）。
  SessionCleanupNoticeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionCleanupNoticeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionCleanupNoticeHash();

  @$internal
  @override
  SessionCleanupNotice create() => SessionCleanupNotice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$sessionCleanupNoticeHash() =>
    r'c5ae2dfbe9ad76fa516243944ac215f31cb372ed';

/// ログイン時に前回のデータを消し切れなかったことを画面へ知らせる合図（#15）。
///
/// 個人用アプリなので、消し残しがあってもログインは止めない（`AuthController`
/// の説明）。その代わり黙って通さず、`ComicLazApp` が SnackBar で 1 回知らせる。
/// state は知らせるべき回数の通し番号（増えたときだけ表示する）。

abstract class _$SessionCleanupNotice extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
