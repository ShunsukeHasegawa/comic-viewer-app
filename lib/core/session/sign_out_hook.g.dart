// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sign_out_hook.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// 登録済みのフック。ログアウトのたびに上から順に呼ぶ。

@ProviderFor(signOutHooks)
final signOutHooksProvider = SignOutHooksProvider._();

/// 登録済みのフック。ログアウトのたびに上から順に呼ぶ。

final class SignOutHooksProvider
    extends
        $FunctionalProvider<
          List<SignOutHook>,
          List<SignOutHook>,
          List<SignOutHook>
        >
    with $Provider<List<SignOutHook>> {
  /// 登録済みのフック。ログアウトのたびに上から順に呼ぶ。
  SignOutHooksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'signOutHooksProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$signOutHooksHash();

  @$internal
  @override
  $ProviderElement<List<SignOutHook>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<SignOutHook> create(Ref ref) {
    return signOutHooks(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SignOutHook> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SignOutHook>>(value),
    );
  }
}

String _$signOutHooksHash() => r'1505d64fe74111121eee20b398915de0b031dad3';
