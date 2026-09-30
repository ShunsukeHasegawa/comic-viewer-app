import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // background_downloader のダウンロード通知（進捗 / 完了）を受け取るため（#10）。
    // パッケージの README（doc/notifications.md）が求める設定。
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DeviceProtectionChannel") {
      DeviceProtectionChannel.register(with: registrar.messenger())
    }
  }
}

/// 端末の保護（#15）。Dart 側は `lib/core/device/device_protection.dart`。
///
/// 数 GB の ZIP と、Bearer が平文で入った background_downloader の Dart 側の
/// タスク記録（Application Support）、drift の DB（Documents）を iCloud / PC の
/// バックアップに載せない。プラグインは使わない（除外フラグ 1 行のために無関係な
/// 機能を持ち込まない）。
///
/// 残存リスク: Dart が繋がっていない間（アプリが終了 / 停止中に URLSession が
/// 完了・失敗・一時停止した）の状態通知と再開データは、プラグインのネイティブ側が
/// `UserDefaults.standard`（Library/Preferences）の
/// `com.bbflight.background_downloader.{statusUpdateMap,progressUpdateMap,resumeDataMap}.v2`
/// に Task の JSON ごと書く。Task にはヘッダ（`Authorization: Bearer ...`）が入る。
/// Preferences は常にバックアップされ除外できないので、次にアプリを起動して
/// `FileDownloader` が取り出す（起動時の `ArchiveTransport.start`）までの間は
/// Bearer がバックアップに載りうる。取り出す前に消すと完了の通知を失うので、
/// ここでは消さない（受け入れた残存リスク。#15 / CLAUDE.md）。
/// Xcode プロジェクトにファイルを足さずに済むよう、このファイルに置く。
enum DeviceProtectionChannel {
  static let name = "com.lazgram.comic_laz/device_protection"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup",
        let args = call.arguments as? [String: Any],
        let paths = args["paths"] as? [String]
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(excludeFromBackup(paths: paths))
    }
  }

  /// 除外に失敗したパスを返す。存在しないパスは飛ばす（次の起動で掛け直す）。
  /// ディレクトリに付けると配下も除外される（後から作られるファイルを含む）。
  private static func excludeFromBackup(paths: [String]) -> [String] {
    var failed: [String] = []
    for path in paths {
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
        continue
      }
      var url = URL(fileURLWithPath: path, isDirectory: isDirectory.boolValue)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
      } catch {
        failed.append(path)
      }
    }
    return failed
  }
}
