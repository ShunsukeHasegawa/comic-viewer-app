import 'dart:async';

import 'package:comic_laz/domain/models/book_detail.dart';
import 'package:comic_laz/features/downloads/application/auto_delete_settings.dart';
import 'package:comic_laz/features/downloads/data/free_space_probe.dart';
import 'package:comic_laz/features/downloads/domain/volume_download.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'download_fakes.dart';
import 'offline_fakes.dart';

/// drift を触らない自動削除の設定（既定はすべてオフ = 本番の既定と同じ）。
class StubAutoDeleteSettingsController extends AutoDeleteSettingsController {
  StubAutoDeleteSettingsController([this.initial = const AutoDeleteSettings()]);

  final AutoDeleteSettings initial;

  /// 設定を読んだ回数（「オフなら何も読まない」の前提を確かめる）。
  int reads = 0;

  @override
  Future<AutoDeleteSettings> build() async {
    reads++;
    return initial;
  }

  @override
  Future<void> set(AutoDeleteSettings value) async => state = AsyncData(value);
}

/// 削除を台帳（`state`）にも反映し、削除 / 全削除の呼び出しを記録するキュー。
///
/// 画面や自動削除が「消したら容量が減る」「消す直前の状態を見直す」ことを
/// 確かめるために使う。
class RecordingDownloadQueue extends StubDownloadQueue {
  RecordingDownloadQueue({super.initial, super.failingRemovals})
    : super(applyRemovals: true);

  /// 台帳を読んだ回数。
  int builds = 0;

  /// 台帳の読み込みを待たせる（起動直後の読み込み中を作る）。
  Completer<void>? buildGate;

  int purgeCount = 0;

  /// `purgeAll` で投げる例外。
  Object? purgeError;

  /// 各 `remove` の前に割り込ませる処理（削除の途中で状態を変える）。
  Future<void> Function(int volumeId)? beforeRemove;

  @override
  Future<Map<int, VolumeDownload>> build() async {
    builds++;
    await buildGate?.future;
    return super.build();
  }

  @override
  Future<void> remove(int volumeId) async {
    await beforeRemove?.call(volumeId);
    return super.remove(volumeId);
  }

  @override
  Future<void> purgeAll() async {
    purgeCount++;
    if (purgeError case final error?) throw error;
    await super.purgeAll();
  }
}

/// 読んだタイトルと掃除の回数を記録する控え。
class RecordingOfflineMetadataGateway extends FakeOfflineMetadataGateway {
  RecordingOfflineMetadataGateway({super.details, this.pruneError});

  final readDetails = <int>[];

  /// `prune` で投げる例外。
  Object? pruneError;

  @override
  Future<BookDetail?> readBookDetail(int bookId) {
    readDetails.add(bookId);
    return super.readBookDetail(bookId);
  }

  @override
  Future<void> prune() async {
    await super.prune();
    if (pruneError case final error?) throw error;
  }
}

/// 決まった値を返す端末のストレージ（`null` は「分からない」）。
DeviceStorageProbe fixedDeviceStorage(DeviceStorage? storage) =>
    () async => storage;

/// 読了フラグだけを持つ控え（自動削除の「他端末で読了」を作る）。
BookDetail finishedDetail(int bookId, {required Map<int, bool> volumes}) =>
    BookDetail(
      id: bookId,
      title: 'タイトル$bookId',
      volumes: [
        for (final MapEntry(key: id, value: finished) in volumes.entries)
          BookVolume(
            id: id,
            volume: id,
            filesVersion: 1,
            archiveBytes: 1,
            userStatus: VolumeUserStatus(
              currentPage: finished ? 10 : 1,
              maxPage: 10,
              isFinished: finished,
            ),
          ),
      ],
    );
