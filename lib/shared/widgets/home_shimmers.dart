import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/themes/app_colors.dart';

/// Shimmer that mirrors the [TicketStatisticsCard] layout — a 140×140 donut
/// on the left and a 5-row legend column on the right.
class TicketStatisticsShimmer extends StatelessWidget {
  const TicketStatisticsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200,
      highlightColor: AppColors.grey100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — "Ticket Overview"
          _bar(height: 16, width: 140),
          const SizedBox(height: 20),
          // Donut + legend
          Row(
            children: [
              // Donut placeholder
              SizedBox(
                width: 140,
                height: 140,
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(5, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          _bar(height: 10, width: 10, radius: 5),
                          const SizedBox(width: 8),
                          Expanded(child: _bar(height: 10, width: 60)),
                          const SizedBox(width: 8),
                          _bar(height: 10, width: 24),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _bar({
    required double height,
    required double width,
    double radius = 4,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Shimmer that mirrors the [TicketActivityChart] layout — title, period
/// chips, and a row of bar pills.
class TicketActivityShimmer extends StatelessWidget {
  const TicketActivityShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200,
      highlightColor: AppColors.grey100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _bar(height: 16, width: 120),
          const SizedBox(height: 16),
          // Period chips
          Row(
            children: [
              _bar(height: 28, width: 80, radius: 20),
              const SizedBox(width: 12),
              _bar(height: 28, width: 80, radius: 20),
            ],
          ),
          const SizedBox(height: 20),
          // Chart area — 7 vertical pills of varying heights
          SizedBox(
            height: 138,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: const [
                _BarPill(heightRatio: 0.5),
                _BarPill(heightRatio: 0.7),
                _BarPill(heightRatio: 0.4),
                _BarPill(heightRatio: 0.85),
                _BarPill(heightRatio: 0.6),
                _BarPill(heightRatio: 0.75),
                _BarPill(heightRatio: 0.5),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // X-axis labels
          Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Center(child: _bar(height: 10, width: 16)),
              );
            }),
          ),
        ],
      ),
    );
  }

  static Widget _bar({
    required double height,
    required double width,
    double radius = 4,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _BarPill extends StatelessWidget {
  final double heightRatio;
  const _BarPill({required this.heightRatio});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 16,
            height: 130 * heightRatio,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
