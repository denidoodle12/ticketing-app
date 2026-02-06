import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';

/// Statistics filter type for ticket statistics
enum StatisticsFilterType { status, priority, category }

/// Data model for chart section
class ChartSectionData {
  final String label;
  final int count;
  final Color color;

  const ChartSectionData({
    required this.label,
    required this.count,
    required this.color,
  });

  double get percentage => count > 0 ? count.toDouble() : 0;
}

/// Ticket Statistics Card with donut chart
class TicketStatisticsCard extends StatefulWidget {
  final Map<String, int> statusCounts;
  final Map<String, int> priorityCounts;
  final Map<String, int> categoryCounts;
  final bool isLoading;
  final StatisticsFilterType initialFilter;
  final ValueChanged<StatisticsFilterType>? onFilterChanged;
  final bool showHeader;

  const TicketStatisticsCard({
    super.key,
    required this.statusCounts,
    this.priorityCounts = const {},
    this.categoryCounts = const {},
    this.isLoading = false,
    this.initialFilter = StatisticsFilterType.status,
    this.onFilterChanged,
    this.showHeader = true,
  });

  @override
  State<TicketStatisticsCard> createState() => _TicketStatisticsCardState();
}

class _TicketStatisticsCardState extends State<TicketStatisticsCard> {
  late StatisticsFilterType _selectedFilter;
  int? _touchedIndex;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
  }

  List<ChartSectionData> get _chartData {
    switch (_selectedFilter) {
      case StatisticsFilterType.status:
        return _getStatusChartData();
      case StatisticsFilterType.priority:
        return _getPriorityChartData();
      case StatisticsFilterType.category:
        return _getCategoryChartData();
    }
  }

  List<ChartSectionData> _getStatusChartData() {
    return [
      ChartSectionData(
        label: 'Open',
        count: widget.statusCounts['open'] ?? 0,
        color: AppColors.statusOpen,
      ),
      ChartSectionData(
        label: 'In Progress',
        count: widget.statusCounts['in_progress'] ?? 0,
        color: AppColors.statusInProgress,
      ),
      ChartSectionData(
        label: 'Pending',
        count: widget.statusCounts['pending'] ?? 0,
        color: AppColors.primary400,
      ),
      ChartSectionData(
        label: 'Resolved',
        count: widget.statusCounts['resolved'] ?? 0,
        color: AppColors.statusResolved,
      ),
      ChartSectionData(
        label: 'Closed',
        count: widget.statusCounts['closed'] ?? 0,
        color: AppColors.statusClosed,
      ),
    ];
  }

  List<ChartSectionData> _getPriorityChartData() {
    return [
      ChartSectionData(
        label: 'Low',
        count: widget.priorityCounts['low'] ?? 0,
        color: AppColors.priorityLow,
      ),
      ChartSectionData(
        label: 'Medium',
        count: widget.priorityCounts['medium'] ?? 0,
        color: AppColors.priorityMedium,
      ),
      ChartSectionData(
        label: 'High',
        count: widget.priorityCounts['high'] ?? 0,
        color: AppColors.priorityHigh,
      ),
      ChartSectionData(
        label: 'Critical',
        count: widget.priorityCounts['critical'] ?? 0,
        color: AppColors.priorityUrgent,
      ),
    ];
  }

  List<ChartSectionData> _getCategoryChartData() {
    final colors = [
      AppColors.primary500,
      AppColors.accent500,
      AppColors.warning500,
      AppColors.success500,
      AppColors.error500,
      AppColors.primary400,
      AppColors.accent400,
    ];

    return widget.categoryCounts.entries.map((entry) {
      final index = widget.categoryCounts.keys.toList().indexOf(entry.key);
      return ChartSectionData(
        label: entry.key,
        count: entry.value,
        color: colors[index % colors.length],
      );
    }).toList();
  }

  int get _totalCount {
    return _chartData.fold(0, (sum, item) => sum + item.count);
  }

  String get _filterLabel {
    switch (_selectedFilter) {
      case StatisticsFilterType.status:
        return 'By Status';
      case StatisticsFilterType.priority:
        return 'By Priority';
      case StatisticsFilterType.category:
        return 'By Category';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showHeader) ...[
            _buildHeader(),
            const SizedBox(height: 20),
          ] else ...[
            // Show Overview label and filter dropdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Overview',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _buildFilterDropdown(),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (widget.isLoading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_totalCount == 0)
            _buildEmptyState()
          else ...[
            _buildDonutChart(),
            const SizedBox(height: 20),
            _buildLegend(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Ticket Statistics',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        _buildFilterDropdown(),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return PopupMenuButton<StatisticsFilterType>(
      onSelected: (filter) {
        setState(() {
          _selectedFilter = filter;
          _touchedIndex = null;
        });
        widget.onFilterChanged?.call(filter);
      },
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        _buildPopupMenuItem(StatisticsFilterType.status, 'By Status'),
        _buildPopupMenuItem(StatisticsFilterType.priority, 'By Priority'),
        _buildPopupMenuItem(StatisticsFilterType.category, 'By Category'),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _filterLabel,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary500,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: AppColors.primary500,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<StatisticsFilterType> _buildPopupMenuItem(
    StatisticsFilterType filter,
    String label,
  ) {
    final isSelected = _selectedFilter == filter;
    return PopupMenuItem<StatisticsFilterType>(
      value: filter,
      child: Row(
        children: [
          if (isSelected)
            Icon(Icons.check, size: 18, color: AppColors.primary500)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isSelected ? AppColors.primary500 : AppColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 200,
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

  Widget _buildDonutChart() {
    final dataWithValues = _chartData.where((d) => d.count > 0).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        height: 220,
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
                centerSpaceRadius: 70,
                sections: _buildChartSections(dataWithValues),
              ),
            ),
            // Center text
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _totalCount.toString(),
                  style: AppTextStyles.h1.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 40,
                  ),
                ),
                Text(
                  'Total Tickets',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections(
    List<ChartSectionData> dataWithValues,
  ) {
    return dataWithValues.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final isTouched = index == _touchedIndex;
      final radius = isTouched ? 22.0 : 18.0;
      final percentage = (_totalCount > 0)
          ? (data.count / _totalCount * 100).toStringAsFixed(0)
          : '0';

      return PieChartSectionData(
        color: data.color,
        value: data.count.toDouble(),
        title: '$percentage%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: data.color,
        ),
        titlePositionPercentageOffset: 1.8,
        badgePositionPercentageOffset: 1.0,
      );
    }).toList();
  }

  Widget _buildLegend() {
    final dataWithValues = _chartData.where((d) => d.count > 0).toList();

    return Column(
      children: dataWithValues.asMap().entries.map((entry) {
        final index = entry.key;
        final data = entry.value;
        final isLast = index == dataWithValues.length - 1;
        return _buildLegendRow(data.label, data.count, data.color, isLast);
      }).toList(),
    );
  }

  Widget _buildLegendRow(String label, int count, Color color, bool isLast) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              // Square color indicator
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              // Label
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Count
              Text(
                count.toString(),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: AppColors.grey200),
      ],
    );
  }
}
