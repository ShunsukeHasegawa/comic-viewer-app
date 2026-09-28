// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'books_api.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(booksApi)
final booksApiProvider = BooksApiProvider._();

final class BooksApiProvider
    extends $FunctionalProvider<BooksApi, BooksApi, BooksApi>
    with $Provider<BooksApi> {
  BooksApiProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'booksApiProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$booksApiHash();

  @$internal
  @override
  $ProviderElement<BooksApi> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BooksApi create(Ref ref) {
    return booksApi(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BooksApi value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BooksApi>(value),
    );
  }
}

String _$booksApiHash() => r'ec5cf998254ae451f8e9437eb81890a1ff06c11e';
