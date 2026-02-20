import 'package:flutter/material.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../models/dashboard_stats_model.dart';

/// Priority Distribution Card with horizontal bar chart
/// Fetches distribution data from dashboard API and displays
/// breakdown of tickets by priority level (low, medium, high, critical)
class PriorityDistributionCard extends StatefulWidget {
  const PriorityDistributionCard({super.key});

  @override
  State<PriorityDistributionCard> createState() =>
      _PriorityDistributionCardState();
}

class _PriorityDistributionCardState extends State<PriorityDistributionCard> {
  DistributionData? _distribution;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDistribution();
  }

  Future<void> _loadDistribution() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = DioClient.userInstance;
      final response = await dio.get(
        ApiEndpoints.dashboardStats,
        queryParameters: {'include': 'distribution'},
      );
      final stats = DashboardStats.fromJson(response.data);
      if (mounted) {
        setState(() {
          _distribution = stats.distribution;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load distribution data';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        if (_isLoading)
          const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error != null || _distribution == null)
          _buildEmptyState()
        else
          _buildContent(),
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
              'Priority Breakdown',
              style: AppTextStyles.h6.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'By priority level',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, size: 36, color: AppColors.grey300),
            const SizedBox(height: 8),
            Text(
              'No priority data available',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final items = _distribution!.byPriority;
    final total = _distribution!.totalPriorityCount;

    if (total == 0) return _buildEmptyState();

    return Column(
      children: [
        // Stacked horizontal bar
        _buildStackedBar(items, total),
        const SizedBox(height: 16),
        // Legend grid
        _buildLegendGrid(items, total),
      ],
    );
  }

  /// Build a single stacked horizontal bar showing all priorities
  Widget _buildStackedBar(List<PriorityDistributionItem> items, int total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: items.map((item) {
            final fraction = item.count / total;
            if (fraction == 0) return const SizedBox.shrink();
            return Expanded(
              flex: (fraction * 1000).round(),
              child: Container(color: _getPriorityColor(item.priority)),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Build legend grid (2x2)
  Widget _buildLegendGrid(List<PriorityDistributionItem> items, int total) {
    return Wrap(
      spacing: 8,
      runSpacing: 12,
      children: items.map((item) {
        final percentage = total > 0
            ? (item.count / total * 100).toStringAsFixed(0)
            : '0';
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 80) / 2,
          child: _buildLegendItem(item, percentage),
        );
      }).toList(),
    );
  }

  Widget _buildLegendItem(PriorityDistributionItem item, String percentage) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _getPriorityColor(item.priority),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.displayName} ($percentage%)',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${item.count} tickets',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Get priority color from app theme (consistent with ticket cards)
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return AppColors.priorityLow;
      case 'medium':
        return AppColors.priorityMedium;
      case 'high':
        return AppColors.priorityHigh;
      case 'critical':
        return AppColors.priorityUrgent;
      default:
        return AppColors.grey400;
    }
  }
}
