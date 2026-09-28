/// バイト数を人に読める形にする（ダウンロード容量の表示用）。
///
/// 1024 進法で、MB 以上は小数 1 桁。
String formatBytes(int bytes) {
  if (bytes < 0) return '-';
  if (bytes < 1024) return '$bytes B';

  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  // KB は小数を出さない（細かすぎて読みにくい）。
  final digits = unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
}

/// `YYYY-MM` を「YYYY年M月」にする。
String formatYearMonth(String yearMonth) {
  final parts = yearMonth.split('-');
  if (parts.length != 2) return yearMonth;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  if (year == null || month == null) return yearMonth;
  return '$year年$month月';
}

/// 日時を「YYYY/MM/DD HH:MM」にする（端末のタイムゾーン）。
String formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}/$month/$day $hour:$minute';
}
