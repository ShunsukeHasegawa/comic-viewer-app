import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';

part 'in_app_browser.g.dart';

/// Web のページをアプリの上に重ねて開く（Android は Custom Tabs、iOS は
/// SFSafariViewController）。
///
/// ブラウザ本体（`LaunchMode.externalApplication`）で開くと、開くたびに Chrome の
/// タブが増える。Custom Tabs は閉じれば消え、Cookie は Chrome と共有するので、
/// Chrome で Web 版にログイン済みならそのまま入れる（#20）。
abstract interface class InAppBrowser {
  /// 開けたら `true`。ブラウザが無いなどで開けなければ `false`（投げない）。
  Future<bool> open(Uri url);
}

class PlatformInAppBrowser implements InAppBrowser {
  const PlatformInAppBrowser();

  @override
  Future<bool> open(Uri url) async {
    try {
      // 既定の `platformDefault` も https なら同じ動きだが、意図を固定するため
      // 明示する（既定が変わってもブラウザ本体で開かないように）。
      return await launchUrl(url, mode: LaunchMode.inAppBrowserView);
    } on Object {
      // Android は開けないとき PlatformException を投げる。呼び出し側では
      // 「開けなかった」と知らせるだけなので、ここで bool に揃える。
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
InAppBrowser inAppBrowser(Ref ref) => const PlatformInAppBrowser();
