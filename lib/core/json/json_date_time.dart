/// API から届く日時文字列を読む。
///
/// Laravel は基本 ISO8601（`2026-09-25T01:00:45.000000Z`）で返すが、
/// キャストされていないカラムは DB の値そのまま（`2026-09-20 12:34:56`）で届く。
/// サーバーの保存は UTC なので、**タイムゾーンが無い文字列は UTC として扱う**
/// （端末のタイムゾーンで解釈すると更新日順の並びがずれる）。
///
/// 解釈できない値で一覧全体のパースを失敗させたくないので `null` に倒す。
DateTime? dateTimeFromJson(Object? value) {
  if (value is! String) return null;
  final raw = value.trim();
  if (raw.isEmpty) return null;

  // MySQL のゼロ日付（`0000-00-00 00:00:00`）は「日付なし」。
  // Dart はこれを紀元前の日付として解釈してしまうので先に弾く。
  if (_isZeroDate(raw)) return null;

  return DateTime.tryParse(_withUtcDesignator(raw))?.toUtc();
}

/// 年 / 月 / 日のいずれかが 0 の日付か。
bool _isZeroDate(String raw) {
  final parts = raw.split(RegExp('[T ]')).first.split('-');
  if (parts.length != 3) return false;
  return parts.any((part) => (int.tryParse(part) ?? -1) == 0);
}

/// [dateTimeFromJson] の逆（ローカルキャッシュへの保存用）。
String? dateTimeToJson(DateTime? value) => value?.toUtc().toIso8601String();

/// タイムゾーンの指定が無ければ UTC として読ませる。
String _withUtcDesignator(String raw) {
  if (_hasTimeZone(raw)) return raw;

  final normalized = raw.replaceFirst(' ', 'T');
  // 日付だけ（`2026-09-20`）の場合は 0 時として扱う。
  return normalized.contains('T')
      ? '${normalized}Z'
      : '${normalized}T00:00:00Z';
}

/// `Z` / `+09:00` / `+0900` / `+09` のいずれの表記も許容する。
final _timeZoneSuffix = RegExp(r'([Zz]|[+-]\d{2}(:?\d{2})?)$');

final _timeSeparator = RegExp('[T ]');

/// タイムゾーン指定を持つか。
///
/// 日付だけ（`2026-09-20`）の末尾 `-20` をオフセットと誤認しないよう、
/// 時刻部分だけを見る。
bool _hasTimeZone(String raw) {
  final separatorIndex = raw.indexOf(_timeSeparator);
  if (separatorIndex < 0) return false;
  return _timeZoneSuffix.hasMatch(raw.substring(separatorIndex + 1));
}
