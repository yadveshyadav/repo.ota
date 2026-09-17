/// Safe robust Date/Time parsing utilities handling ISO strings, Unix timestamps,
/// formatted date strings, null values, Indian Standard Time (IST - UTC+5:30), and malformed inputs without crashing.
abstract class DateParserUtils {
  /// Safely parse any dynamic raw date input into DateTime?
  static DateTime? parse(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input;

    if (input is int) {
      if (input > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(input, isUtc: true);
      } else if (input > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(input * 1000, isUtc: true);
      }
    }

    final str = input.toString().trim();
    if (str.isEmpty || str == 'null' || str == 'N/A' || str == 'undefined') {
      return null;
    }

    // Try parsing numeric timestamp string
    final numVal = int.tryParse(str);
    if (numVal != null) {
      if (numVal > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(numVal, isUtc: true);
      } else if (numVal > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(numVal * 1000, isUtc: true);
      }
    }

    // Try ISO-8601 parsing
    try {
      final strUpper = str.toUpperCase();
      if (!strUpper.endsWith('Z') && !strUpper.contains('+') && !RegExp(r'T\d{2}:\d{2}:\d{2}-\d{2}').hasMatch(strUpper)) {
        final parsed = DateTime.parse(str);
        return DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
      }
      return DateTime.parse(str);
    } catch (_) {}

    return null;
  }

  /// Convert any DateTime input strictly to Indian Standard Time (IST - UTC+5:30) / Local Time
  static DateTime? toIst(dynamic input) {
    final dt = parse(input);
    if (dt == null) return null;

    if (dt.isUtc) {
      return dt.toLocal();
    }
    return dt;
  }

  /// Format time strictly in Indian Standard Time / Local Time (hh:mm AM/PM)
  static String formatIstTime(dynamic rawDate, {String fallback = 'N/A'}) {
    final ist = toIst(rawDate);
    if (ist == null) return fallback;
    try {
      final hour = ist.hour > 12 ? ist.hour - 12 : (ist.hour == 0 ? 12 : ist.hour);
      final minute = ist.minute.toString().padLeft(2, '0');
      final period = ist.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:$minute $period';
    } catch (_) {
      return fallback;
    }
  }

  /// Format date strictly in Indian Standard Time / Local Time (dd MMM yyyy)
  static String formatIstDate(dynamic rawDate, {String fallback = 'N/A'}) {
    final ist = toIst(rawDate);
    if (ist == null) return fallback;
    try {
      final year = ist.year;
      final month = _monthName(ist.month);
      final day = ist.day.toString().padLeft(2, '0');
      return '$day $month $year';
    } catch (_) {
      return fallback;
    }
  }

  /// Format DateTime safely for UI presentation in IST / Local Time
  static String formatDisplay(dynamic rawDate, {String fallback = 'N/A'}) {
    final ist = toIst(rawDate);
    if (ist == null) return fallback;
    try {
      final year = ist.year;
      final month = _monthName(ist.month);
      final day = ist.day.toString().padLeft(2, '0');
      final hour = ist.hour > 12
          ? ist.hour - 12
          : (ist.hour == 0 ? 12 : ist.hour);
      final minute = ist.minute.toString().padLeft(2, '0');
      final period = ist.hour >= 12 ? 'PM' : 'AM';
      return '$day $month $year, ${hour.toString().padLeft(2, '0')}:$minute $period';
    } catch (_) {
      return fallback;
    }
  }

  /// Convert DateTime safely to ISO-8601 string
  static String? toIso8601String(dynamic rawDate) {
    final dt = parse(rawDate);
    return dt?.toIso8601String();
  }

  static String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}
