import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../tickets/repositories/ticket_repository.dart';
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

  /// Build a unique cache key for this trend query
  String _buildCacheKey() {
    if (_selectedPeriod == 'monthly') {
      final month = _selectedMonth.month.toString().padLeft(2, '0');
      return 'trend_${_selectedPeriod}_${_selectedMonth.year}-$month';
    }
    return 'trend_$_selectedPeriod';
  }

  Future<void> _loadTrendData() async {
    // Capture repo before async gap to avoid BuildContext lint
    final repo = context.read<TicketRepository>();

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

      // Cache the trend data for offline use
      try {
        final cacheKey = _buildCacheKey();
        final jsonData = jsonEncode(response.data);
        await repo.localDatasource?.cacheDashboardStats(cacheKey, jsonData);
      } catch (_) {
        // Cache failure is non-critical
      }

      if (mounted) {
        setState(() {
          _trendData = stats.trend;
          _isLoading = false;
        });
      }
    } on DioException catch (_) {
      // Offline — try to load from cache
      await _loadFromCache(repo);
    } catch (e) {
      // Also try cache on any network-related error
      if (e is DioException) {
        await _loadFromCache(repo);
      } else if (mounted) {
        setState(() {
          _error = 'Failed to load activity data';
          _isLoading = false;
        });
      }
    }
  }

  /// Load trend data from local cache
  Future<void> _loadFromCache(TicketRepository repo) async {
    try {
      final cacheKey = _buildCacheKey();
      final cachedJson = await repo.localDatasource?.getCachedDashboardStats(
        cacheKey,
      );

      if (cachedJson != null && mounted) {
        final data = jsonDecode(cachedJson) as Map<String, dynamic>;
        final stats = DashboardStats.fromJson(data);
        setState(() {
          _trendData = stats.trend;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {
      // Cache read failed
    }

    // No cache available
    if (mounted) {
      setState(() {
        _error = 'No internet connection';
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String period) {
    if (_selectedPeriod != period) {
      setState(() {
        _selectedPeriod = period;
        _selectedBarIndex = null;
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
      _selectedBarIndex = null;
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

  int? _selectedBarIndex;

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
      String fullDate = '';

      if (isMonthly) {
        // Monthly: label as W1, W2, W3, etc.
        dateNum = 'W${index + 1}';
        fullDate = item.label; // e.g., "Week 1 (Feb 3-9)"
      } else {
        // Weekly: show date number + day name
        try {
          final dt = DateTime.parse(item.date);
          dateNum = dt.day.toString();
          dayLabel = _dayName(dt.weekday);
          fullDate = _formatFullDate(dt);
        } catch (_) {
          dateNum = item.label;
          fullDate = item.label;
        }
      }

      return _BarData(
        index: index,
        dateNum: dateNum,
        dayLabel: dayLabel,
        fullDate: fullDate,
        created: item.created,
        open: item.open,
        inProgress: item.inProgress,
        resolved: item.resolved,
        closed: item.closed,
      );
    }).toList();

    return GestureDetector(
      // Tap outside bars to dismiss tooltip
      onTap: () {
        if (_selectedBarIndex != null) {
          setState(() => _selectedBarIndex = null);
        }
      },
      behavior: HitTestBehavior.translucent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          return SizedBox(
            height: 220,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Bar chart row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: barData.map((bar) {
                    return Expanded(
                      child: _buildSingleBar(
                        bar: bar,
                        maxValue: maxCreated,
                        isMonthly: isMonthly,
                        isSelected: _selectedBarIndex == bar.index,
                      ),
                    );
                  }).toList(),
                ),

                // Tooltip overlay (positioned above the selected bar)
                if (_selectedBarIndex != null &&
                    _selectedBarIndex! < barData.length)
                  _buildTooltipOverlay(
                    bar: barData[_selectedBarIndex!],
                    barCount: barData.length,
                    isMonthly: isMonthly,
                    totalWidth: totalWidth,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Single bar column: count label → pill bar → date → day
  Widget _buildSingleBar({
    required _BarData bar,
    required int maxValue,
    required bool isMonthly,
    required bool isSelected,
  }) {
    final hasData = bar.created > 0;
    final fillRatio = hasData ? bar.created / maxValue : 0.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          // Toggle: tap same bar to dismiss, tap different to switch
          _selectedBarIndex = _selectedBarIndex == bar.index ? null : bar.index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
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
                        color: isSelected
                            ? AppColors.primary600
                            : AppColors.primary,
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
                          color: isSelected
                              ? AppColors.primary100
                              : AppColors.secondary200,
                          borderRadius: BorderRadius.circular(barWidth / 2),
                        ),
                      ),
                      // Filled bar (from bottom)
                      if (hasData)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isSelected ? barWidth + 2 : barWidth,
                          height: fillHeight < barWidth ? barWidth : fillHeight,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: isSelected
                                  ? const [
                                      AppColors.primary500,
                                      AppColors.primary400,
                                    ]
                                  : const [
                                      AppColors.primary600,
                                      AppColors.primary500,
                                    ],
                            ),
                            borderRadius: BorderRadius.circular(
                              (barWidth + 2) / 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
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
                color: isSelected
                    ? AppColors.primary600
                    : (hasData
                          ? AppColors.textPrimary
                          : AppColors.textSecondary),
                fontWeight: (hasData || isSelected)
                    ? FontWeight.w700
                    : FontWeight.normal,
                fontSize: 12,
              ),
            ),

            // Day label (only for weekly)
            if (!isMonthly)
              Text(
                bar.dayLabel.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: isSelected
                      ? AppColors.primary500
                      : AppColors.textSecondary,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Tooltip Overlay ────────────────────────────────────────────

  Widget _buildTooltipOverlay({
    required _BarData bar,
    required int barCount,
    required bool isMonthly,
    required double totalWidth,
  }) {
    // Calculate horizontal position based on bar index
    // Each bar occupies 1/barCount of the width
    final barFraction = (bar.index + 0.5) / barCount;

    final tooltipWidth = isMonthly ? 170.0 : 160.0;
    final barCenterX = totalWidth * barFraction;

    // Clamp tooltip so it doesn't overflow edges
    double tooltipLeft = barCenterX - tooltipWidth / 2;
    if (tooltipLeft < 0) tooltipLeft = 0;
    if (tooltipLeft + tooltipWidth > totalWidth) {
      tooltipLeft = totalWidth - tooltipWidth;
    }

    // Arrow position relative to tooltip
    final arrowLeft = (barCenterX - tooltipLeft).clamp(
      12.0,
      tooltipWidth - 12.0,
    );

    return Positioned(
      left: tooltipLeft,
      top: -8, // Float above the bars
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 4 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tooltip card
            Container(
              width: tooltipWidth,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Text(
                    bar.fullDate,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Tickets created
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Created',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${bar.created}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),

                  // Status breakdown rows
                  _buildTooltipRow('Open', bar.open, AppColors.primary500),
                  const SizedBox(height: 3),
                  _buildTooltipRow(
                    'In Progress',
                    bar.inProgress,
                    const Color(0xFF8B5CF6),
                  ),
                  const SizedBox(height: 3),
                  _buildTooltipRow(
                    'Resolved',
                    bar.resolved,
                    AppColors.success500,
                  ),
                  if (bar.closed > 0) ...[
                    const SizedBox(height: 3),
                    _buildTooltipRow('Closed', bar.closed, AppColors.grey400),
                  ],
                ],
              ),
            ),

            // Arrow pointing down to the bar
            SizedBox(
              width: tooltipWidth,
              height: 6,
              child: CustomPaint(
                painter: _ArrowPainter(
                  arrowX: arrowLeft,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltipRow(String label, int count, Color dotColor) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatFullDate(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final day = days[(dt.weekday - 1) % 7];
    final month = _monthNames[dt.month - 1];
    return '$day, ${dt.day} $month';
  }

  String _dayName(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[(weekday - 1) % 7];
  }
}

/// Arrow painter for tooltip pointer
class _ArrowPainter extends CustomPainter {
  final double arrowX;
  final Color color;

  const _ArrowPainter({required this.arrowX, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(arrowX - 6, 0)
      ..lineTo(arrowX, 6)
      ..lineTo(arrowX + 6, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      arrowX != oldDelegate.arrowX || color != oldDelegate.color;
}

/// Internal data model for a single bar
class _BarData {
  final int index;
  final String dateNum;
  final String dayLabel;
  final String fullDate;
  final int created;
  final int open;
  final int inProgress;
  final int resolved;
  final int closed;

  const _BarData({
    required this.index,
    required this.dateNum,
    required this.dayLabel,
    required this.fullDate,
    required this.created,
    required this.open,
    required this.inProgress,
    required this.resolved,
    required this.closed,
  });
}
