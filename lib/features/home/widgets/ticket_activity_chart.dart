import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../shared/widgets/home_shimmers.dart';
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

  // Connectivity listener for auto-reload when online
  StreamSubscription<bool>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadTrendData();

    // Auto-reload when connection restores
    _connectivitySubscription = ConnectivityService().connectionStream.listen((
      isConnected,
    ) {
      if (isConnected && _error != null && mounted) {
        _loadTrendData();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
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

      // Prefetch the other period in background for offline availability
      _prefetchOtherPeriod(repo);
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

  /// Prefetch other period data in background for offline use.
  /// For weekly → prefetch monthly data for current + 2 previous months.
  /// For monthly → prefetch weekly data.
  Future<void> _prefetchOtherPeriod(TicketRepository repo) async {
    try {
      final dio = DioClient.userInstance;

      if (_selectedPeriod == 'weekly') {
        // Prefetch current month + 2 previous months of monthly data
        final now = DateTime.now();
        for (int i = 0; i < 3; i++) {
          final targetMonth = DateTime(now.year, now.month - i);
          final month = targetMonth.month.toString().padLeft(2, '0');
          final monthKey = 'trend_monthly_${targetMonth.year}-$month';

          try {
            final response = await dio.get(
              ApiEndpoints.dashboardStats,
              queryParameters: {
                'include': 'trend',
                'trend_period': 'monthly',
                'trend_month': '${targetMonth.year}-$month',
              },
            );
            await repo.localDatasource?.cacheDashboardStats(
              monthKey,
              jsonEncode(response.data),
            );
          } catch (_) {
            // Individual month prefetch failure is non-critical
          }
        }
      } else {
        // Prefetch weekly data
        final response = await dio.get(
          ApiEndpoints.dashboardStats,
          queryParameters: {'include': 'trend', 'trend_period': 'weekly'},
        );
        await repo.localDatasource?.cacheDashboardStats(
          'trend_weekly',
          jsonEncode(response.data),
        );
      }
    } catch (_) {
      // Prefetch failure is non-critical — silently ignore
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

    // No cache available — show descriptive offline message
    if (mounted) {
      setState(() {
        _error = _selectedPeriod == 'monthly'
            ? 'This month\'s data is not available offline.\nConnect to the internet to load it.'
            : 'No internet connection';
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
    if (_isLoading && _trendData == null) {
      return const TicketActivityShimmer();
    }

    if (_error != null) {
      final isOfflineError =
          _error!.contains('internet') ||
          _error!.contains('Offline') ||
          _error!.contains('offline');

      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOfflineError ? Icons.wifi_off_rounded : Icons.error_outline,
                color: isOfflineError
                    ? AppColors.textSecondary
                    : AppColors.error500,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              if (!isOfflineError) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadTrendData,
                  child: const Text('Retry'),
                ),
              ],
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
    if (maxCreated == 0) maxCreated = 1;

    final isMonthly = _selectedPeriod == 'monthly';

    final barData = items.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      String dateNum = '';
      String dayLabel = '';
      String fullDate = '';

      if (isMonthly) {
        dateNum = 'W${index + 1}';
        fullDate = item.label;
      } else {
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

    // Layout constants
    const double gridHeight = 130.0;
    const double topOverflow = 8.0;
    const double barAreaHeight = gridHeight + topOverflow;
    final double xLabelHeight = isMonthly ? 20.0 : 34.0;

    // Nice Y-axis ticks
    final yTicks = _calculateYTicks(maxCreated);
    final yMax = yTicks.last;

    // Dynamic Y-axis width based on longest label
    final maxLabel = _formatYLabel(yMax);
    final double yAxisWidth = maxLabel.length <= 2 ? 22.0 : (maxLabel.length <= 3 ? 28.0 : 34.0);

    return GestureDetector(
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
            height: barAreaHeight + xLabelHeight + 16,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main chart layout: Y-axis + (grid lines + bars) + X labels
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Y-Axis Labels ──
                    Padding(
                      padding: const EdgeInsets.only(top: topOverflow),
                      child: SizedBox(
                        width: yAxisWidth,
                        height: gridHeight,
                        child: _buildYAxisLabels(yTicks, gridHeight),
                      ),
                    ),

                    // ── Chart Area (grid + bars + x-labels) ──
                    Expanded(
                      child: Column(
                        children: [
                          // Bar area with grid behind
                          SizedBox(
                            height: barAreaHeight,
                            child: Stack(
                              children: [
                                // Dotted grid lines (offset down by topOverflow)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: topOverflow,
                                  height: gridHeight,
                                  child: CustomPaint(
                                    painter: _GridLinesPainter(
                                      tickCount: yTicks.length,
                                    ),
                                  ),
                                ),
                                // Bars row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: barData.map((bar) {
                                    return Expanded(
                                      child: _buildSingleBar(
                                        bar: bar,
                                        maxValue: yMax,
                                        isSelected:
                                            _selectedBarIndex == bar.index,
                                        barAreaHeight: barAreaHeight,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // ── X-Axis Labels ──
                          _buildXAxisLabels(barData, isMonthly),
                        ],
                      ),
                    ),
                  ],
                ),

                // Tooltip overlay
                if (_selectedBarIndex != null &&
                    _selectedBarIndex! < barData.length)
                  _buildTooltipOverlay(
                    bar: barData[_selectedBarIndex!],
                    barCount: barData.length,
                    isMonthly: isMonthly,
                    totalWidth: totalWidth,
                    yAxisOffset: yAxisWidth,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Y-axis labels positioned so text center aligns with grid lines
  Widget _buildYAxisLabels(List<int> ticks, double height) {
    // Each tick is at y = height * i / (tickCount - 1), from top (max) to bottom (0)
    // We use reversed ticks so index 0 = top = max value
    final reversedTicks = ticks.reversed.toList();
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(reversedTicks.length, (i) {
        final y = height * i / (reversedTicks.length - 1);
        return Positioned(
          right: 4,
          top: y - 5, // offset by half text height (~10px font)
          child: Text(
            _formatYLabel(reversedTicks[i]),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.grey400,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// X-axis labels row
  Widget _buildXAxisLabels(List<_BarData> barData, bool isMonthly) {
    return Row(
      children: barData.map((bar) {
        final hasData = bar.created > 0;
        final isSelected = _selectedBarIndex == bar.index;
        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                bar.dateNum,
                textAlign: TextAlign.center,
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
              if (!isMonthly)
                Text(
                  bar.dayLabel.toUpperCase(),
                  textAlign: TextAlign.center,
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
        );
      }).toList(),
    );
  }

  /// Calculate nice Y-axis tick values
  List<int> _calculateYTicks(int maxValue) {
    if (maxValue <= 4) {
      return List.generate(maxValue + 1, (i) => i);
    }

    // Choose a "nice" step that gives 4-6 ticks
    final niceSteps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500, 5000, 10000];
    int step = 1;
    for (final s in niceSteps) {
      if ((maxValue / s).ceil() <= 6) {
        step = s;
        break;
      }
    }
    // Fallback for very large values
    if ((maxValue / step).ceil() > 6) {
      step = (maxValue / 5).ceil();
      // Round step to a nice number
      final magnitude = _pow10((step.toString().length - 1).clamp(0, 10));
      step = ((step / magnitude).ceil() * magnitude).toInt();
    }

    final ticks = <int>[0];
    int tick = step;
    while (tick < maxValue) {
      ticks.add(tick);
      tick += step;
    }
    ticks.add(tick);
    return ticks;
  }

  /// Format Y-axis label: abbreviate large numbers
  String _formatYLabel(int value) {
    if (value >= 10000) {
      final k = value / 1000;
      return k == k.truncateToDouble() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    } else if (value >= 1000) {
      final k = value / 1000;
      return k == k.truncateToDouble() ? '${k.toInt()}K' : '${k.toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  int _pow10(int exp) {
    int result = 1;
    for (int i = 0; i < exp; i++) {
      result *= 10;
    }
    return result;
  }

  /// Single bar pill (no count label, no x-label — handled separately)
  Widget _buildSingleBar({
    required _BarData bar,
    required int maxValue,
    required bool isSelected,
    required double barAreaHeight,
  }) {
    final hasData = bar.created > 0;
    final fillRatio = hasData ? bar.created / maxValue : 0.0;
    const barWidth = 16.0;
    final fillHeight = barAreaHeight * fillRatio;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBarIndex = _selectedBarIndex == bar.index ? null : bar.index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: barAreaHeight,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Background track (flat bottom, rounded top)
                Container(
                  width: barWidth,
                  height: barAreaHeight,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary100
                        : AppColors.secondary200,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(barWidth / 2),
                      topRight: Radius.circular(barWidth / 2),
                    ),
                  ),
                ),
                // Filled bar
                if (hasData)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
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
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular((barWidth + 2) / 2),
                        topRight: Radius.circular((barWidth + 2) / 2),
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
            ),
          ),
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
    double yAxisOffset = 0,
  }) {
    // Calculate horizontal position — bars start after Y-axis
    final chartWidth = totalWidth - yAxisOffset;
    final barFraction = (bar.index + 0.5) / barCount;

    final tooltipWidth = isMonthly ? 170.0 : 160.0;
    final barCenterX = yAxisOffset + chartWidth * barFraction;

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

/// Dotted horizontal grid lines painter for bar chart
class _GridLinesPainter extends CustomPainter {
  final int tickCount;

  const _GridLinesPainter({required this.tickCount});

  @override
  void paint(Canvas canvas, Size size) {
    if (tickCount < 2) return;

    final paint = Paint()
      ..color = const Color(0xFFE8ECF0)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < tickCount; i++) {
      final y = size.height * i / (tickCount - 1);
      _drawDottedLine(canvas, Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 3.0;
    const dashSpace = 4.0;
    final totalLength = (end - start).distance;
    final direction = (end - start) / totalLength;
    double drawn = 0;

    while (drawn < totalLength) {
      final dashEnd = (drawn + dashWidth).clamp(0.0, totalLength);
      canvas.drawLine(
        start + direction * drawn,
        start + direction * dashEnd,
        paint,
      );
      drawn += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_GridLinesPainter oldDelegate) =>
      tickCount != oldDelegate.tickCount;
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
