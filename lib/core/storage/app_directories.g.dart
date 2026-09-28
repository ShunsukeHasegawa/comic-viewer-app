// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_directories.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDirectories)
final appDirectoriesProvider = AppDirectoriesProvider._();

final class AppDirectoriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppDirectories>,
          AppDirectories,
          FutureOr<AppDirectories>
        >
    with $FutureModifier<AppDirectories>, $FutureProvider<AppDirectories> {
  AppDirectoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDirectoriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDirectoriesHash();

  @$internal
  @override
  $FutureProviderElement<AppDirectories> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppDirectories> create(Ref ref) {
    return appDirectories(ref);
  }
}

String _$appDirectoriesHash() => r'4e5f19407fd5f5a1b794f9c53405d96aa7897165';
