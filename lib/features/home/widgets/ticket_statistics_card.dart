import 'dart:math';
import 'package:flutter/material.dart';
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

/// Ticket Overview with custom rounded donut chart and status legend
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
  int? _selectedIndex;

  TicketStatsData get _stats => TicketStatsData.fromMap(widget.statusCounts);

  List<_ChartItem> get _chartItems => [
    _ChartItem(
      label: 'Open',
      count: _stats.openCount,
      color: AppColors.statusOpen,
      gradientColors: [AppColors.primary600, AppColors.primary500],
    ),
    _ChartItem(
      label: 'In Progress',
      count: _stats.inProgressCount,
      color: const Color(0xFF8B5CF6),
      gradientColors: [const Color(0xFF8B5CF6), const Color(0xFFA78BFA)],
    ),
    _ChartItem(
      label: 'Pending',
      count: _stats.pendingCount,
      color: AppColors.statusInProgress,
      gradientColors: [AppColors.warning500, const Color(0xFFFBBF24)],
    ),
    _ChartItem(
      label: 'Resolved',
      count: _stats.resolvedCount,
      color: AppColors.statusResolved,
      gradientColors: [AppColors.success500, const Color(0xFF34D399)],
    ),
    _ChartItem(
      label: 'Closed',
      count: _stats.closedCount,
      color: AppColors.statusClosed,
      gradientColors: [AppColors.secondary500, AppColors.grey400],
    ),
  ];

  int get _totalCount => _stats.totalTickets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 20),
        if (widget.isLoading)
          const SizedBox(
            height: 130,
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
    return Text(
      'Ticket Overview',
      style: AppTextStyles.h6.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pie_chart_outline, size: 40, color: AppColors.grey300),
            const SizedBox(height: 8),
            Text(
              'No ticket data yet',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Donut chart (left) + legend list (right)
  Widget _buildChartWithLegend() {
    // Only segments with data
    final activeItems = _chartItems.where((item) => item.count > 0).toList();
    final segments = activeItems
        .map(
          (item) => _DonutSegment(
            color: item.color,
            value: item.count.toDouble(),
            gradientColors: item.gradientColors,
          ),
        )
        .toList();

    // Calculate segment angles for hit detection
    const gapAngle = 0.06;
    final totalGap = gapAngle * segments.length;
    final availableAngle = 2 * pi - totalGap;
    final total = segments.fold<double>(0, (sum, s) => sum + s.value);

    return Row(
      children: [
        // Custom rounded donut chart with tap detection
        GestureDetector(
          onTapUp: (details) {
            if (total == 0) return;
            _handleDonutTap(
              details.localPosition,
              activeItems,
              total,
              availableAngle,
              gapAngle,
            );
          },
          child: SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(130, 130),
                  painter: _RoundedDonutPainter(
                    segments: segments,
                    strokeWidth: 14,
                    selectedIndex: _selectedIndex != null
                        ? activeItems.indexWhere(
                            (item) =>
                                item.label ==
                                _chartItems[_selectedIndex!].label,
                          )
                        : null,
                  ),
                ),
                // Center text: total or selected segment info
                GestureDetector(
                  onTap: () {
                    // Tap center to dismiss selection
                    if (_selectedIndex != null) {
                      setState(() => _selectedIndex = null);
                    }
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _selectedIndex != null
                        ? _buildSelectedCenter()
                        : _buildTotalCenter(),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 20),

        // Legend list
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _chartItems.asMap().entries.map((entry) {
              return _buildLegendItem(entry.value, entry.key);
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _handleDonutTap(
    Offset localPosition,
    List<_ChartItem> activeItems,
    double total,
    double availableAngle,
    double gapAngle,
  ) {
    final center = const Offset(65, 65); // 130/2
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = sqrt(dx * dx + dy * dy);

    // Only respond to taps on the donut ring area (not center, not outside)
    const strokeWidth = 14.0;
    final radius = (130 - strokeWidth) / 2;
    if (distance < radius - strokeWidth || distance > radius + strokeWidth) {
      // Tapped outside the ring — dismiss
      if (_selectedIndex != null) {
        setState(() => _selectedIndex = null);
      }
      return;
    }

    // Calculate angle from top (same as painter's start angle)
    var angle = atan2(dy, dx) + pi / 2; // rotate so 0 = top
    if (angle < 0) angle += 2 * pi;

    // Find which segment was tapped
    double cumAngle = 0;
    for (int i = 0; i < activeItems.length; i++) {
      final sweepAngle =
          (activeItems[i].count.toDouble() / total) * availableAngle;
      if (angle >= cumAngle && angle < cumAngle + sweepAngle) {
        // Find the original index in _chartItems
        final originalIndex = _chartItems.indexWhere(
          (item) => item.label == activeItems[i].label,
        );
        setState(() {
          _selectedIndex = _selectedIndex == originalIndex
              ? null
              : originalIndex;
        });
        return;
      }
      cumAngle += sweepAngle + gapAngle;
    }
  }

  Widget _buildTotalCenter() {
    return Column(
      key: const ValueKey('total'),
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
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedCenter() {
    final item = _chartItems[_selectedIndex!];
    return Column(
      key: ValueKey('selected_${item.label}'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.count.toString(),
          style: AppTextStyles.h2.copyWith(
            color: item.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          item.label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(_ChartItem item, int index) {
    final percentage = _totalCount > 0
        ? (item.count / _totalCount * 100).toStringAsFixed(0)
        : '0';
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = _selectedIndex == index ? null : index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? item.color.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 12 : 10,
              height: isSelected ? 12 : 10,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: item.color.withValues(alpha: 0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$percentage%',
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? item.color : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Rounded Donut Chart Painter ─────────────────────────────

class _DonutSegment {
  final Color color;
  final double value;
  final List<Color>? gradientColors;

  const _DonutSegment({
    required this.color,
    required this.value,
    this.gradientColors,
  });
}

class _RoundedDonutPainter extends CustomPainter {
  final List<_DonutSegment> segments;
  final double strokeWidth;
  final int? selectedIndex;

  _RoundedDonutPainter({
    required this.segments,
    this.strokeWidth = 14,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total == 0) return;

    // Small gap in radians between segments
    const gapAngle = 0.06;
    final totalGap = gapAngle * segments.length;
    final availableAngle = 2 * pi - totalGap;

    // Start from top (-90 degrees)
    double startAngle = -pi / 2;

    // Draw each segment with rounded ends
    for (int idx = 0; idx < segments.length; idx++) {
      final segment = segments[idx];
      final sweepAngle = (segment.value / total) * availableAngle;
      final isSelected = selectedIndex == idx;
      final currentStrokeWidth = isSelected ? strokeWidth + 3 : strokeWidth;

      if (segment.gradientColors != null &&
          segment.gradientColors!.length >= 2) {
        // Draw gradient by splitting arc into small sub-segments
        const steps = 30;
        final c1 = segment.gradientColors!.first;
        final c2 = segment.gradientColors!.last;

        for (int i = 0; i < steps; i++) {
          final t = i / steps;
          final subStart = startAngle + sweepAngle * t;
          final subSweep = sweepAngle / steps + 0.005; // tiny overlap
          final color = Color.lerp(c1, c2, t)!;

          final subPaint = Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = currentStrokeWidth
            ..strokeCap = StrokeCap.butt;

          canvas.drawArc(rect, subStart, subSweep, false, subPaint);
        }

        // Rounded cap at start
        final startCapCenter = Offset(
          center.dx + radius * cos(startAngle),
          center.dy + radius * sin(startAngle),
        );
        canvas.drawCircle(
          startCapCenter,
          currentStrokeWidth / 2,
          Paint()..color = c1,
        );

        // Rounded cap at end
        final endCapCenter = Offset(
          center.dx + radius * cos(startAngle + sweepAngle),
          center.dy + radius * sin(startAngle + sweepAngle),
        );
        canvas.drawCircle(
          endCapCenter,
          currentStrokeWidth / 2,
          Paint()..color = c2,
        );
      } else {
        final paint = Paint()
          ..color = segment.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentStrokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      }

      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _RoundedDonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

// ─── Data Model ─────────────────────────────────────────────────────

class _ChartItem {
  final String label;
  final int count;
  final Color color;
  final List<Color>? gradientColors;

  const _ChartItem({
    required this.label,
    required this.count,
    required this.color,
    this.gradientColors,
  });
}
