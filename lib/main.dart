import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'features/settings/application/theme_mode_setting.dart';

Future<void> main() async {
  // runApp より前に DB（表示テーマの設定）を読むため。
  WidgetsFlutterBinding.ensureInitialized();

  // `--dart-define` の不備は起動時に気づけるようにする。
  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on AppConfigException catch (error) {
    runApp(ConfigErrorApp(message: error.message));
    return;
  }

  final container = await bootstrapContainer([
    appConfigProvider.overrideWithValue(config),
  ]);
  runApp(buildRootApp(container));
}

/// アプリのコンテナを作り、最初のフレームに要る設定（表示テーマ #17）を
/// 読み込んでから返す。
///
/// 表示テーマは最初のフレームから保存済みの設定で描く。読み込みを待たずに描くと、
/// スプラッシュの後に「システムに合わせる」の色で一瞬描かれてから切り替わる。
/// 読み込みの間は OS のスプラッシュが出たままになる。
/// コンテナを先に作るのは、読み込んだ値をそのままアプリに渡すため
/// （別に DB を開くと同じ SQLite を 2 つの接続で開くことになる）。
///
/// `main` とテストの両方がここを通るので、「runApp の前に読み込む」の取り違えを
/// テストで止められる。[overrides] には [appConfigProvider] の差し替えを含める
/// （Riverpod は同じプロバイダの二重 override を拒むので、ここでは足さない）。
@visibleForTesting
Future<ProviderContainer> bootstrapContainer(List<Override> overrides) async {
  final container = ProviderContainer(overrides: overrides);
  await preloadThemeMode(container);
  return container;
}

/// [bootstrapContainer] で読み込んだコンテナを**そのまま**アプリに渡す。
///
/// `ProviderScope(overrides: ...)` にすると別のコンテナ（と別の DB 接続）が
/// 作られ、読み込んでおいた表示テーマが捨てられて最初のフレームが
/// 「システムに合わせる」の色になる。
@visibleForTesting
Widget buildRootApp(ProviderContainer container) =>
    UncontrolledProviderScope(container: container, child: const ComicLazApp());

/// ビルド時設定が不正なときに表示する最小の画面。
@visibleForTesting
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('設定エラー\n\n$message', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
