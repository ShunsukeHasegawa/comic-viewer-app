import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_config.g.dart';

/// ビルド時に `--dart-define` で切り替える環境。
enum AppFlavor {
  development,
  production;

  /// 未知の値は例外にする（タイポで本番 URL に向いてしまう事故を防ぐ）。
  static AppFlavor parse(String raw) {
    for (final flavor in AppFlavor.values) {
      if (flavor.name == raw) return flavor;
    }
    throw AppConfigException(
      'APP_FLAVOR="$raw" は不正です。'
      '${AppFlavor.values.map((f) => f.name).join(' / ')} のいずれかを指定してください。',
    );
  }

  bool get isProduction => this == AppFlavor.production;
}

/// [AppConfig] の組み立てに失敗したことを表す例外。
class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

/// アプリのビルド時設定。
///
/// 例:
/// ```sh
/// flutter run \
///   --dart-define=API_BASE_URL=http://192.168.0.2:8000 \
///   --dart-define=APP_FLAVOR=development
/// ```
class AppConfig {
  const AppConfig._({required this.apiBaseUrl, required this.flavor});

  /// `--dart-define` の値から生成する。
  factory AppConfig.fromEnvironment() =>
      AppConfig.from(apiBaseUrl: _envApiBaseUrl, flavor: _envFlavor);

  /// 文字列から検証つきで生成する（テストからも使う）。
  factory AppConfig.from({required String apiBaseUrl, required String flavor}) {
    return AppConfig._(
      apiBaseUrl: _normalizeBaseUrl(apiBaseUrl),
      flavor: AppFlavor.parse(flavor),
    );
  }

  static const _envApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://comic.lazgram.com',
  );

  static const _envFlavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'production',
  );

  /// API とメディアの配信元。末尾スラッシュなしに正規化済み。
  final Uri apiBaseUrl;

  final AppFlavor flavor;

  /// `dio` の `BaseOptions.baseUrl` に渡す形。
  String get apiBaseUrlString => apiBaseUrl.toString();

  /// ベース URL 配下の絶対 URL を組み立てる。
  ///
  /// ベース URL がサブパス（`https://example.com/comic` など）を持つ場合も
  /// それを保ったまま連結する。
  Uri resolvePath(String path, {Map<String, String>? queryParameters}) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return apiBaseUrl.replace(
      path: '${apiBaseUrl.path}$normalized',
      queryParameters: queryParameters,
    );
  }

  static Uri _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const AppConfigException('API_BASE_URL が空です。');
    }

    final Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } on FormatException catch (error) {
      throw AppConfigException(
        'API_BASE_URL="$raw" を URL として解釈できません: ${error.message}',
      );
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw AppConfigException(
        'API_BASE_URL="$raw" は http / https で始まる絶対 URL にしてください。',
      );
    }
    if (!uri.hasAuthority || uri.host.isEmpty) {
      throw AppConfigException('API_BASE_URL="$raw" にホスト名がありません。');
    }
    if (uri.hasQuery || uri.hasFragment) {
      throw AppConfigException('API_BASE_URL="$raw" にクエリ / フラグメントは指定できません。');
    }

    // 末尾スラッシュを落として `resolvePath` での二重スラッシュを防ぐ。
    var path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return uri.replace(path: path);
  }

  @override
  String toString() =>
      'AppConfig(apiBaseUrl: $apiBaseUrl, flavor: ${flavor.name})';
}

/// アプリ全体で参照する [AppConfig]。テストでは override して差し替える。
@Riverpod(keepAlive: true)
AppConfig appConfig(Ref ref) => AppConfig.fromEnvironment();
