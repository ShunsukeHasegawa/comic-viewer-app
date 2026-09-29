import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_resume_monitor.g.dart';

/// アプリが前面に戻ったことの通知。
///
/// 画面を持たない層（`DownloadQueue` など）が「前面に戻った」を契機に
/// やり直すために使う。`AppLifecycleListener` は `WidgetsBinding` が要るので、
/// テストでは差し替えられるよう抽象を切る。
abstract interface class AppResumeMonitor {
  Stream<void> get onResumed;
}

class LifecycleAppResumeMonitor implements AppResumeMonitor {
  /// 購読している間だけ `AppLifecycleListener` を作る（購読をやめたら外す）。
  @override
  Stream<void> get onResumed => Stream<void>.multi((controller) {
    final listener = AppLifecycleListener(onResume: () => controller.add(null));
    controller.onCancel = listener.dispose;
  });
}

@Riverpod(keepAlive: true)
AppResumeMonitor appResumeMonitor(Ref ref) => LifecycleAppResumeMonitor();
