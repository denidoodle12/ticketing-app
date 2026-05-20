/// Centralised date/time formatting for the entire app.
///
/// All UI surfaces (ticket cards, knowledge articles, notifications, detail
/// screens, timelines) should use one of these three methods so the user
/// sees consistent date strings everywhere. We deliberately do NOT use the
/// `intl` package here — formatting is simple and hardcoded English keeps
/// the binary lean.
///
/// Convention: **American English** (e.g. `May 20, 2026`).
///
/// | Use case                 | Method        | Example                      |
/// |--------------------------|---------------|------------------------------|
/// | List / card timestamp    | `relative()`  | `2h ago`, `Yesterday`, `May 20` |
/// | Date-only meta           | `date()`      | `May 20, 2026`               |
/// | Detail field / timeline  | `dateTime()`  | `May 20, 2026, 2:30 PM`      |
/// | Time-only (chat, log)    | `time()`      | `2:30 PM`                    |
class DateFormatter {
  DateFormatter._();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Smart relative time. Use this for list/card timestamps where the user
  /// scans many items quickly.
  ///
  /// Output progression as the date moves further into the past:
  /// - `< 1 minute`   → `Just now`
  /// - `< 1 hour`     → `5m ago`
  /// - `< 1 day`      → `2h ago`
  /// - `1 day`        → `Yesterday`
  /// - `< 7 days`     → `3d ago`
  /// - same year      → `May 20` (no time, no year)
  /// - older          → `May 20, 2025`
  ///
  /// Returns an empty string for null inputs (safe for chained access).
  static String relative(DateTime? dateTime) {
    if (dateTime == null) return '';

    final local = dateTime.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.isNegative) {
      // Future date — fall through to absolute formatting.
      return date(local);
    }

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    // Older than a week — show absolute month/day, omit year if same.
    if (local.year == now.year) {
      return '${_months[local.month - 1]} ${local.day}';
    }
    return '${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  /// Date-only formatting. Use for article meta, badges, and any place where
  /// we want the full date but no time.
  ///
  /// Example: `May 20, 2026`.
  /// Returns an empty string for null inputs.
  static String date(DateTime? dateTime) {
    if (dateTime == null) return '';
    final local = dateTime.toLocal();
    return '${_months[local.month - 1]} ${local.day}, ${local.year}';
  }

  /// Full date + time. Use for detail screens and audit-style fields where
  /// precision matters.
  ///
  /// Example: `May 20, 2026, 2:30 PM`.
  /// Returns an empty string for null inputs.
  static String dateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${date(dateTime)}, ${time(dateTime)}';
  }

  /// Time-only (12-hour clock). Use for chat bubbles, activity logs, and
  /// anywhere the date is already grouped/known.
  ///
  /// Example: `2:30 PM`.
  /// Returns an empty string for null inputs.
  static String time(DateTime? dateTime) {
    if (dateTime == null) return '';
    final local = dateTime.toLocal();
    final hour24 = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0
        ? 12
        : (hour24 > 12 ? hour24 - 12 : hour24);
    return '$hour12:$minute $period';
  }
}
