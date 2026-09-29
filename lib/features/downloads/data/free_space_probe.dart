import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'free_space_probe.g.dart';

/// 端末の空き容量（バイト）。**分からない場合は `null`**。
typedef FreeSpaceProbe = Future<int?> Function();

/// 既定の空き容量取得（常に「分からない」）。
///
/// `dart:io` に空き容量を取る API は無く、実測にはプラットフォームプラグインが要る。
/// **今回は追加しない**と判断した。理由:
/// - プラグインはプラットフォームチャネル越しなので、テストからは触れない
///   （このプロジェクトの規約）。容量不足の分岐をこの差し込み口にしておけば、
///   プラグイン無しでも「足りなければ開始しない」ロジックはテストできる。
/// - Android / iOS の「利用可能容量」は OS が回収予定のキャッシュを含むかどうかが
///   端末・OS バージョンで揺れる。数百 MB の誤差で開始を止めると、実際には
///   入るはずのダウンロードができなくなる。
/// - 巻 1 つは数十〜数百 MB で、書き込み失敗（ENOSPC）は `DownloadQueue` が
///   捕まえて「空き容量が足りません」として扱える。最悪でも一時ファイルが
///   消されるだけで、ダウンロード済みのデータは壊れない。
///
/// プラグインを入れるときはこの provider を override すれば、キュー側は変えずに済む。
Future<int?> unknownFreeSpace() async => null;

@Riverpod(keepAlive: true)
FreeSpaceProbe freeSpaceProbe(Ref ref) => unknownFreeSpace;
