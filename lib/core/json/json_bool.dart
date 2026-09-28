/// Laravel のキャストによって `true` / `1` / `"1"` のいずれでも届きうる真偽値を読む。
bool boolFromJson(Object? value) => switch (value) {
  final bool value => value,
  final num value => value != 0,
  'true' || '1' => true,
  _ => false,
};
