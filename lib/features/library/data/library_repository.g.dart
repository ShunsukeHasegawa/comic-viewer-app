// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(libraryCacheStore)
final libraryCacheStoreProvider = LibraryCacheStoreProvider._();

final class LibraryCacheStoreProvider
    extends
        $FunctionalProvider<
          LibraryCacheStore,
          LibraryCacheStore,
          LibraryCacheStore
        >
    with $Provider<LibraryCacheStore> {
  LibraryCacheStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryCacheStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryCacheStoreHash();

  @$internal
  @override
  $ProviderElement<LibraryCacheStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibraryCacheStore create(Ref ref) {
    return libraryCacheStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryCacheStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryCacheStore>(value),
    );
  }
}

String _$libraryCacheStoreHash() => r'1b5a48d75a09d7945b5295bc547ac656e07bddf3';

@ProviderFor(libraryRepository)
final libraryRepositoryProvider = LibraryRepositoryProvider._();

final class LibraryRepositoryProvider
    extends
        $FunctionalProvider<
          LibraryRepository,
          LibraryRepository,
          LibraryRepository
        >
    with $Provider<LibraryRepository> {
  LibraryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryRepositoryHash();

  @$internal
  @override
  $ProviderElement<LibraryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibraryRepository create(Ref ref) {
    return libraryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibraryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibraryRepository>(value),
    );
  }
}

String _$libraryRepositoryHash() => r'2a6f5b82c8de4c59a4cf2661176497db2d656418';

@ProviderFor(libraryCachePurger)
final libraryCachePurgerProvider = LibraryCachePurgerProvider._();

final class LibraryCachePurgerProvider
    extends
        $FunctionalProvider<
          SessionDataPurger,
          SessionDataPurger,
          SessionDataPurger
        >
    with $Provider<SessionDataPurger> {
  LibraryCachePurgerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'libraryCachePurgerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$libraryCachePurgerHash();

  @$internal
  @override
  $ProviderElement<SessionDataPurger> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionDataPurger create(Ref ref) {
    return libraryCachePurger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionDataPurger value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionDataPurger>(value),
    );
  }
}

String _$libraryCachePurgerHash() =>
    r'83733c76d95e21ed7341859e1dafa7cba2df8614';
