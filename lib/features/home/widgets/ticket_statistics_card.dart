import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../main/screens/main_screen.dart';

/// Data model for ticket statistics from API
class TicketStatsData {
  final int totalTickets;
  final int openCount;
  final int inProgressCount;
  final int resolvedCount;

  const TicketStatsData({
    required this.totalTickets,
    required this.openCount,
    required this.inProgressCount,
    required this.resolvedCount,
  });

  factory TicketStatsData.fromMap(Map<String, int> statusCounts) {
    final open = statusCounts['open'] ?? 0;
    final inProgress = statusCounts['in_progress'] ?? 0;
    final resolved = statusCounts['resolved'] ?? 0;
    return TicketStatsData(
      totalTickets: open + inProgress + resolved,
      openCount: open,
      inProgressCount: inProgress,
      resolvedCount: resolved,
    );
  }
}

/// Modern Ticket Statistics Card with donut chart
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
      color: const Color(0xFF64B5F6), // Light blue
    ),
    _ChartItem(
      label: 'In Progress',
      count: _stats.inProgressCount,
      color: const Color(0xFF1565C0), // Dark blue
    ),
    _ChartItem(
      label: 'Resolved',
      count: _stats.resolvedCount,
      color: const Color(0xFF0D47A1), // Navy blue
    ),
  ];

  int get _totalCount => _stats.totalTickets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(),
        const SizedBox(height: 16),

        // Content
        if (widget.isLoading)
          const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_totalCount == 0)
          _buildEmptyState()
        else
          _buildChartWithLegend(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
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
        ),
        GestureDetector(
          onTap: () {
            // Navigate to tickets screen
            context.findAncestorStateOfType<MainScreenState>()?.switchToTab(1);
          },
          child: Text(
            'See Details',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary500,
              fontWeight: FontWeight.w600,
            ),
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

  Widget _buildChartWithLegend() {
    final dataWithValues = _chartItems.where((d) => d.count > 0).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut Chart
        Expanded(
          flex: 5,
          child: SizedBox(
            height: 180,
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
                          _touchedIndex = pieTouchResponse
                              .touchedSection!
                              .touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 50,
                    sections: _buildChartSections(dataWithValues),
                  ),
                ),
                // Center text
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
                      'Total Ticket',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 40),

        // Legend with percentages
        Expanded(
          flex: 4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _chartItems.map((item) {
              final percentage = _totalCount > 0
                  ? (item.count / _totalCount * 100).toStringAsFixed(0)
                  : '0';
              return _buildLegendItem(item, percentage);
            }).toList(),
          ),
        ),
      ],
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

  Widget _buildLegendItem(_ChartItem item, String percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Color dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: item.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          // Percentage and label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$percentage%',
                  style: AppTextStyles.h6.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  item.label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
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

  const _ChartItem({
    required this.label,
    required this.count,
    required this.color,
  });
}
