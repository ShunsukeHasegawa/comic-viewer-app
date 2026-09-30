import 'package:flutter/material.dart';

import '../../../../core/utils/format.dart';

/// ダウンロードを消す前の確認（巻 / タイトル / 複数選択で共通）。
///
/// 数百 MB の取り直しになるので、何巻・どれだけの容量が消えるかを見せてから
/// 消す。サーバー側のデータと読書進捗は消えないことも書く（「消したら
/// 読んだ記録まで無くなるのでは」と迷わせない）。
///
/// [includesUnfinished] はタイトル単位の削除で、進行中・失敗の巻も一緒に
/// 取り消すこと（見えていない行まで消えることを先に伝える）。
///
/// 確認されたら `true`。
Future<bool> confirmDeleteDownloads(
  BuildContext context, {
  required String title,
  required int volumeCount,
  required int bytes,
  bool includesUnfinished = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(
          [
            '$volumeCount 巻（${formatBytes(bytes)}）を端末から削除します。'
                'オフラインでは読めなくなります'
                '（サーバー上のデータと読書進捗は消えません）。',
            if (includesUnfinished) '進行中・失敗の分も含めて取り消します。',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
