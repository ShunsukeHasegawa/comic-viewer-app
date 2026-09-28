/// Laravel のキャストによって `true` / `1` / `"1"` のいずれでも届きうる真偽値を読む。
bool boolFromJson(Object? value) => switch (value) {
  final bool value => value,
  final num value => value != 0,
  'true' || '1' => true,
  _ => false,
};

/// 真偽値として解釈できる形かどうか（解釈できない応答をエラーにしたい場合に使う）。
bool isBoolLike(Object? value) => switch (value) {
  bool() || num() => true,
  final String value => const {
    'true',
    'false',
    '1',
    '0',
  }.contains(value.trim()),
  _ => false,
};
