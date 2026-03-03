/// Model for dashboard statistics from API
class DashboardStats {
  final int totalTickets;
  final int openCount;
  final int inProgressCount;
  final int resolvedCount;
  final int closedCount;
  final int overdueCount;
  final TrendData? trend;
  final ComparisonData? comparison;
  final DistributionData? distribution;

  const DashboardStats({
    required this.totalTickets,
    required this.openCount,
    required this.inProgressCount,
    required this.resolvedCount,
    required this.closedCount,
    required this.overdueCount,
    this.trend,
    this.comparison,
    this.distribution,
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
      comparison: data['comparison'] != null
          ? ComparisonData.fromJson(data['comparison'])
          : null,
      distribution: data['distribution'] != null
          ? DistributionData.fromJson(data['distribution'])
          : null,
    );
  }
}

/// Distribution data for pie/bar charts (by status & by priority)
class DistributionData {
  final List<PriorityDistributionItem> byPriority;

  const DistributionData({required this.byPriority});

  factory DistributionData.fromJson(Map<String, dynamic> json) {
    return DistributionData(
      byPriority:
          (json['by_priority'] as List<dynamic>?)
              ?.map((item) => PriorityDistributionItem.fromJson(item))
              .toList() ??
          [],
    );
  }

  int get totalPriorityCount =>
      byPriority.fold(0, (sum, item) => sum + item.count);
}

/// Single priority distribution item
class PriorityDistributionItem {
  final String priority;
  final int count;
  final String color;

  const PriorityDistributionItem({
    required this.priority,
    required this.count,
    required this.color,
  });

  factory PriorityDistributionItem.fromJson(Map<String, dynamic> json) {
    return PriorityDistributionItem(
      priority: json['priority'] ?? '',
      count: json['count'] ?? 0,
      color: json['color'] ?? '#94A3B8',
    );
  }

  /// Get display name (capitalize first letter)
  String get displayName =>
      priority.isEmpty ? '' : priority[0].toUpperCase() + priority.substring(1);
}

/// Comparison data for trend indicators (today vs yesterday)
class ComparisonData {
  final String period;
  final Map<String, ComparisonChange> changes;

  const ComparisonData({required this.period, required this.changes});

  factory ComparisonData.fromJson(Map<String, dynamic> json) {
    final changesJson = json['changes'] as Map<String, dynamic>? ?? {};
    final changes = <String, ComparisonChange>{};
    changesJson.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        changes[key] = ComparisonChange.fromJson(value);
      }
    });
    return ComparisonData(
      period: json['period'] ?? 'yesterday',
      changes: changes,
    );
  }

  /// Get change for a specific stat key
  ComparisonChange? getChange(String key) => changes[key];
}

/// Single comparison change item
class ComparisonChange {
  final int current;
  final int previous;
  final int change;
  final double changePercent;

  const ComparisonChange({
    required this.current,
    required this.previous,
    required this.change,
    required this.changePercent,
  });

  factory ComparisonChange.fromJson(Map<String, dynamic> json) {
    return ComparisonChange(
      current: json['current'] ?? 0,
      previous: json['previous'] ?? 0,
      change: json['change'] ?? 0,
      changePercent: (json['change_percent'] ?? 0).toDouble(),
    );
  }

  bool get isPositive => change > 0;
  bool get isNegative => change < 0;
  bool get isNeutral => change == 0;
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
