import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/dashboard_stats_model.dart';

/// Ticket Activity Chart with custom pill-shaped bars
class TicketActivityChart extends StatefulWidget {
  const TicketActivityChart({super.key});

  @override
  State<TicketActivityChart> createState() => _TicketActivityChartState();
}

class _TicketActivityChartState extends State<TicketActivityChart> {
  bool _isLoading = true;
  String _selectedPeriod = 'weekly';
  TrendData? _trendData;
  String? _error;

  // Month picker state — defaults to current month
  late DateTime _selectedMonth;

  static const _monthNames = [
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

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadTrendData();
  }

  Future<void> _loadTrendData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = DioClient.userInstance;
      final queryParams = <String, dynamic>{
        'include': 'trend',
        'trend_period': _selectedPeriod,
      };

      // Add trend_month when monthly is selected
      if (_selectedPeriod == 'monthly') {
        final month = _selectedMonth.month.toString().padLeft(2, '0');
        queryParams['trend_month'] = '${_selectedMonth.year}-$month';
      }

      final response = await dio.get(
        ApiEndpoints.dashboardStats,
        queryParameters: queryParams,
      );

      final stats = DashboardStats.fromJson(response.data);
      if (mounted) {
        setState(() {
          _trendData = stats.trend;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Failed to load activity data';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load activity data';
          _isLoading = false;
        });
      }
    }
  }

  void _onPeriodChanged(String period) {
    if (_selectedPeriod != period) {
      setState(() {
        _selectedPeriod = period;
      });
      _loadTrendData();
    }
  }

  void _onMonthChanged(int delta) {
    final now = DateTime.now();
    final newMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + delta,
    );

    // Don't allow future months
    if (newMonth.isAfter(DateTime(now.year, now.month))) return;

    setState(() {
      _selectedMonth = newMonth;
    });
    _loadTrendData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildPeriodFilter(),
        if (_selectedPeriod == 'monthly') ...[
          const SizedBox(height: 12),
          _buildMonthSelector(),
        ],
        const SizedBox(height: 20),
        _buildContent(),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ticket Activity',
          style: AppTextStyles.h6.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_trendData != null && _trendData!.formattedDateRange.isNotEmpty)
          Text(
            _trendData!.formattedDateRange,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }

  Widget _buildPeriodFilter() {
    return Row(
      children: [
        _buildFilterChip('Weekly', 'weekly'),
        const SizedBox(width: 12),
        _buildFilterChip('Monthly', 'monthly'),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return GestureDetector(
      onTap: () => _onPeriodChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.grey300,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isSelected ? AppColors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Build month selector row with ← Month Year → navigation
  Widget _buildMonthSelector() {
    final now = DateTime.now();
    final isCurrentMonth =
        _selectedMonth.year == now.year && _selectedMonth.month == now.month;

    final monthLabel =
        '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous month button
          _buildMonthNavButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => _onMonthChanged(-1),
            enabled: true,
          ),
          // Current month label
          Text(
            monthLabel,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Next month button (disabled if current month)
          _buildMonthNavButton(
            icon: Icons.chevron_right_rounded,
            onTap: isCurrentMonth ? null : () => _onMonthChanged(1),
            enabled: !isCurrentMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthNavButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: enabled ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.textPrimary : AppColors.grey300,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppColors.error500, size: 32),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadTrendData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_trendData == null || _trendData!.items.isEmpty) {
      return _buildEmptyState();
    }

    return _buildBarChart();
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 48, color: AppColors.grey300),
            const SizedBox(height: 12),
            Text(
              'No activity data available',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Custom Pill Bar Chart ──────────────────────────────────────

  Widget _buildBarChart() {
    final items = _trendData!.items;

    // Find max created value for scaling
    int maxCreated = 0;
    for (final item in items) {
      if (item.created > maxCreated) maxCreated = item.created;
    }
    // Ensure at least 1 to avoid division by zero
    if (maxCreated == 0) maxCreated = 1;

    final isMonthly = _selectedPeriod == 'monthly';

    final barData = items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      String dateNum = '';
      String dayLabel = '';

      if (isMonthly) {
        // Monthly: label as W1, W2, W3, etc.
        dateNum = 'W${index + 1}';
      } else {
        // Weekly: show date number + day name
        try {
          final dt = DateTime.parse(item.date);
          dateNum = dt.day.toString();
          dayLabel = _dayName(dt.weekday);
        } catch (_) {
          dateNum = item.label;
        }
      }

      return _BarData(
        dateNum: dateNum,
        dayLabel: dayLabel,
        created: item.created,
      );
    }).toList();

    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: barData.map((bar) {
          return Expanded(
            child: _buildSingleBar(
              bar: bar,
              maxValue: maxCreated,
              isMonthly: isMonthly,
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Single bar column: count label → pill bar → date → day
  Widget _buildSingleBar({
    required _BarData bar,
    required int maxValue,
    required bool isMonthly,
  }) {
    final hasData = bar.created > 0;
    final fillRatio = hasData ? bar.created / maxValue : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMonthly ? 1.5 : 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Count label (only show if there's data)
          SizedBox(
            height: 20,
            child: hasData
                ? Text(
                    bar.created.toString(),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 4),

          // Pill bar with background track
          SizedBox(
            height: 120,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barHeight = constraints.maxHeight;
                final fillHeight = barHeight * fillRatio;
                final barWidth = isMonthly ? 10.0 : 16.0;

                return Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Background track (full height, light color)
                    Container(
                      width: barWidth,
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: AppColors.secondary200,
                        borderRadius: BorderRadius.circular(barWidth / 2),
                      ),
                    ),
                    // Filled bar (from bottom)
                    if (hasData)
                      Container(
                        width: barWidth,
                        height: fillHeight < barWidth
                            ? barWidth
                            : fillHeight, // min height = bar width for pill shape
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppColors.primary600,
                              AppColors.primary500,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(barWidth / 2),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Date number
          Text(
            bar.dateNum,
            style: AppTextStyles.bodySmall.copyWith(
              color: hasData ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: hasData ? FontWeight.w700 : FontWeight.normal,
              fontSize: 12,
            ),
          ),

          // Day label (only for weekly)
          if (!isMonthly)
            Text(
              bar.dayLabel.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
        ],
      ),
    );
  }

  String _dayName(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[(weekday - 1) % 7];
  }
}

/// Internal data model for a single bar
class _BarData {
  final String dateNum;
  final String dayLabel;
  final int created;

  const _BarData({
    required this.dateNum,
    required this.dayLabel,
    required this.created,
  });
}
