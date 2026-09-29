// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// アプリ共通の [Dio]。
///
/// ETag 条件付き GET やリトライ（#4）は追加のインターセプタで足す。

@ProviderFor(dio)
final dioProvider = DioProvider._();

/// アプリ共通の [Dio]。
///
/// ETag 条件付き GET やリトライ（#4）は追加のインターセプタで足す。

final class DioProvider extends $FunctionalProvider<Dio, Dio, Dio>
    with $Provider<Dio> {
  /// アプリ共通の [Dio]。
  ///
  /// ETag 条件付き GET やリトライ（#4）は追加のインターセプタで足す。
  DioProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dioProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dioHash();

  @$internal
  @override
  $ProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Dio create(Ref ref) {
    return dio(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Dio value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Dio>(value),
    );
  }
}

String _$dioHash() => r'0a786cb7882ae62d23964afe34a4e0af5547a691';
