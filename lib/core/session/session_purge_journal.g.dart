// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_purge_journal.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionPurgeJournal)
final sessionPurgeJournalProvider = SessionPurgeJournalProvider._();

final class SessionPurgeJournalProvider
    extends
        $FunctionalProvider<
          SessionPurgeJournal,
          SessionPurgeJournal,
          SessionPurgeJournal
        >
    with $Provider<SessionPurgeJournal> {
  SessionPurgeJournalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionPurgeJournalProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionPurgeJournalHash();

  @$internal
  @override
  $ProviderElement<SessionPurgeJournal> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionPurgeJournal create(Ref ref) {
    return sessionPurgeJournal(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionPurgeJournal value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionPurgeJournal>(value),
    );
  }
}

String _$sessionPurgeJournalHash() =>
    r'3cf372183ae64e6bed4dd01747b7ac01bfd33703';
