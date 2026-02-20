import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

/// Data model for ticket statistics from API
class TicketStatsData {
  final int totalTickets;
  final int openCount;
  final int inProgressCount;
  final int pendingCount;
  final int resolvedCount;
  final int closedCount;

  const TicketStatsData({
    required this.totalTickets,
    required this.openCount,
    required this.inProgressCount,
    required this.pendingCount,
    required this.resolvedCount,
    required this.closedCount,
  });

  factory TicketStatsData.fromMap(Map<String, int> statusCounts) {
    final open = statusCounts['open'] ?? 0;
    final inProgress = statusCounts['in_progress'] ?? 0;
    final pending = statusCounts['pending'] ?? 0;
    final resolved = statusCounts['resolved'] ?? 0;
    final closed = statusCounts['closed'] ?? 0;
    return TicketStatsData(
      totalTickets: open + inProgress + pending + resolved + closed,
      openCount: open,
      inProgressCount: inProgress,
      pendingCount: pending,
      resolvedCount: resolved,
      closedCount: closed,
    );
  }
}

/// Modern Ticket Statistics Card with donut chart and status grid
class TicketStatisticsCard extends StatefulWidget {
  final Map<String, int> statusCounts;
  final bool isLoading;

  const TicketStatisticsCard({
    super.key,
    required this.statusCounts,
    this.isLoading = false,
  });

  @override
  State<TicketStatisticsCard> createState() => _TicketStatisticsCardState();
}

class _TicketStatisticsCardState extends State<TicketStatisticsCard> {
  int? _touchedIndex;

  TicketStatsData get _stats => TicketStatsData.fromMap(widget.statusCounts);

  List<_ChartItem> get _chartItems => [
    _ChartItem(
      label: 'Open',
      count: _stats.openCount,
      color: const Color(0xFF3B82F6),
      svgPath: 'assets/icons/dashboard/ic_open_status.svg',
    ),
    _ChartItem(
      label: 'In Progress',
      count: _stats.inProgressCount,
      color: const Color(0xFF8B5CF6),
      svgPath: 'assets/icons/dashboard/ic_inprogress_status.svg',
    ),
    _ChartItem(
      label: 'Pending',
      count: _stats.pendingCount,
      color: const Color(0xFFF59E0B),
      svgPath: 'assets/icons/dashboard/ic_pending_status.svg',
    ),
    _ChartItem(
      label: 'Resolved',
      count: _stats.resolvedCount,
      color: const Color(0xFF10B981),
      svgPath: 'assets/icons/dashboard/ic_resolved_status.svg',
    ),
    _ChartItem(
      label: 'Closed',
      count: _stats.closedCount,
      color: const Color(0xFF64748B),
      svgPath: 'assets/icons/dashboard/ic_closed_status.svg',
    ),
  ];

  int get _totalCount => _stats.totalTickets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        if (widget.isLoading)
          const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_totalCount == 0)
          _buildEmptyState()
        else ...[
          _buildDonutChart(),
          const SizedBox(height: 20),
          _buildStatusGrid(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ticket Overview',
          style: AppTextStyles.h6.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'All Time',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 48, color: AppColors.grey300),
            const SizedBox(height: 12),
            Text(
              'No ticket data available',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Centered donut chart with total count
  Widget _buildDonutChart() {
    final dataWithValues = _chartItems.where((d) => d.count > 0).toList();

    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 3,
              centerSpaceRadius: 48,
              sections: _buildChartSections(dataWithValues),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _totalCount.toString(),
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Total',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections(
    List<_ChartItem> dataWithValues,
  ) {
    return dataWithValues.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 24.0 : 20.0;

      return PieChartSectionData(
        color: data.color,
        value: data.count.toDouble(),
        title: '',
        radius: radius,
        borderSide: isTouched
            ? BorderSide(color: AppColors.white, width: 2)
            : BorderSide.none,
      );
    }).toList();
  }

  /// Status grid: 2 on top, 3 on bottom
  Widget _buildStatusGrid() {
    return Column(
      children: [
        // Row 1: Open, In Progress (wider cards)
        Row(
          children: [
            Expanded(child: _buildStatusCard(_chartItems[0])),
            const SizedBox(width: 8),
            Expanded(child: _buildStatusCard(_chartItems[1])),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: Pending, Resolved, Closed
        Row(
          children: [
            Expanded(child: _buildStatusCard(_chartItems[2])),
            const SizedBox(width: 8),
            Expanded(child: _buildStatusCard(_chartItems[3])),
            const SizedBox(width: 8),
            Expanded(child: _buildStatusCard(_chartItems[4])),
          ],
        ),
      ],
    );
  }

  /// Single status card with icon, count, and percentage
  Widget _buildStatusCard(_ChartItem item) {
    final percentage = _totalCount > 0
        ? (item.count / _totalCount * 100).toStringAsFixed(0)
        : '0';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + label row
          Row(
            children: [
              SvgPicture.asset(
                item.svgPath,
                width: 12,
                height: 12,
                colorFilter: ColorFilter.mode(item.color, BlendMode.srcIn),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Count + percentage
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                item.count.toString(),
                style: AppTextStyles.h6.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                '$percentage%',
                style: AppTextStyles.caption.copyWith(
                  color: item.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartItem {
  final String label;
  final int count;
  final Color color;
  final String svgPath;

  const _ChartItem({
    required this.label,
    required this.count,
    required this.color,
    required this.svgPath,
  });
}
