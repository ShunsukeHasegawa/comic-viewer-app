/// 整数の配列を読む（`["1", 2]` のような混在も許容する）。
List<int> intListFromJson(Object? value) {
  if (value is! List) return const [];
  return [
    for (final element in value)
      if (switch (element) {
            final int value => value,
            final num value => value.toInt(),
            final String value => int.tryParse(value),
            _ => null,
          }
          case final int parsed)
        parsed,
  ];
}

/// 文字列の配列を読む（`null` 要素は落とす）。
List<String> stringListFromJson(Object? value) {
  if (value is! List) return const [];
  return [
    for (final element in value)
      if (element != null) element.toString(),
  ];
}
