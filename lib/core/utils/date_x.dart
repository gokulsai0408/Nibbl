import 'package:intl/intl.dart';

/// Date helpers. Days are keyed as `yyyy-MM-dd` in local time.
extension DateX on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);

  String get dayKey =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  bool isSameDay(DateTime other) => year == other.year && month == other.month && day == other.day;

  bool get isToday => isSameDay(DateTime.now());

  /// "Today", "Yesterday", or e.g. "Mon, 3 Nov".
  String get friendlyLabel {
    final now = DateTime.now();
    if (isSameDay(now)) return 'Today';
    if (isSameDay(now.subtract(const Duration(days: 1)))) return 'Yesterday';
    if (isSameDay(now.add(const Duration(days: 1)))) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(this);
  }
}

DateTime parseDayKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

String greetingFor(DateTime time) {
  final h = time.hour;
  if (h < 5) return 'Good night';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

final _kcalFormat = NumberFormat.decimalPattern();

String formatKcal(num value) => _kcalFormat.format(value.round());

String formatGrams(num value) {
  if (value >= 10 || value == value.roundToDouble()) return '${value.round()}g';
  return '${value.toStringAsFixed(1)}g';
}

/// Formats portion multipliers nicely: 1 → "1", 0.5 → "½", 1.25 → "1¼".
String formatMultiplier(double m) {
  final whole = m.floor();
  final frac = m - whole;
  String fracStr = '';
  if ((frac - 0.25).abs() < 0.01) fracStr = '¼';
  if ((frac - 0.5).abs() < 0.01) fracStr = '½';
  if ((frac - 0.75).abs() < 0.01) fracStr = '¾';
  if (fracStr.isEmpty && frac > 0.01) return m.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '');
  if (whole == 0 && fracStr.isNotEmpty) return fracStr;
  return '$whole$fracStr';
}
