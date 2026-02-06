/// Model for dashboard statistics from API
class DashboardStats {
  final int totalTickets;
  final int openCount;
  final int inProgressCount;
  final int resolvedCount;
  final int closedCount;
  final int overdueCount;
  final TrendData? trend;

  const DashboardStats({
    required this.totalTickets,
    required this.openCount,
    required this.inProgressCount,
    required this.resolvedCount,
    required this.closedCount,
    required this.overdueCount,
    this.trend,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return DashboardStats(
      totalTickets: data['total_tickets'] ?? 0,
      openCount: data['open_count'] ?? 0,
      inProgressCount: data['in_progress_count'] ?? 0,
      resolvedCount: data['resolved_count'] ?? 0,
      closedCount: data['closed_count'] ?? 0,
      overdueCount: data['overdue_count'] ?? 0,
      trend: data['trend'] != null ? TrendData.fromJson(data['trend']) : null,
    );
  }
}

/// Trend data for activity chart
class TrendData {
  final String period;
  final String startDate;
  final String endDate;
  final List<TrendItem> items;

  const TrendData({
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.items,
  });

  factory TrendData.fromJson(Map<String, dynamic> json) {
    return TrendData(
      period: json['period'] ?? 'weekly',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => TrendItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  /// Get formatted date range (e.g., "29 Jan - 5 Feb")
  String get formattedDateRange {
    if (startDate.isEmpty || endDate.isEmpty) return '';
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final months = [
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
        'Dec',
      ];
      return '${start.day} ${months[start.month - 1]} - ${end.day} ${months[end.month - 1]}';
    } catch (e) {
      return '';
    }
  }
}

/// Single trend item (daily data)
class TrendItem {
  final String date;
  final String label;
  final int created;
  final int open;
  final int inProgress;
  final int resolved;
  final int closed;
  final int overdue;

  const TrendItem({
    required this.date,
    required this.label,
    required this.created,
    required this.open,
    required this.inProgress,
    required this.resolved,
    required this.closed,
    required this.overdue,
  });

  factory TrendItem.fromJson(Map<String, dynamic> json) {
    return TrendItem(
      date: json['date'] ?? '',
      label: json['label'] ?? '',
      created: json['created'] ?? 0,
      open: json['open'] ?? 0,
      inProgress: json['in_progress'] ?? 0,
      resolved: json['resolved'] ?? 0,
      closed: json['closed'] ?? 0,
      overdue: json['overdue'] ?? 0,
    );
  }
}
