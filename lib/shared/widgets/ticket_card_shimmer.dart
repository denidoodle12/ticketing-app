import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/themes/app_colors.dart';

/// Skeleton placeholder for a single ticket card. Carefully mirrors the
/// real [TicketCard] layout (padding 14, 2-line subject + 2-line description,
/// status pill, category & priority row, time row) so the swap to real data
/// is seamless.
class TicketCardShimmer extends StatelessWidget {
  const TicketCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.grey200,
      highlightColor: AppColors.grey100,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow.withAlpha(15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1 — subject (max 2 lines) + status pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bar(height: 14, width: double.infinity),
                      const SizedBox(height: 6),
                      _bar(height: 14, width: 140),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _bar(height: 22, width: 64, radius: 16),
              ],
            ),
            const SizedBox(height: 10),

            // Row 2 — category + priority dot
            Row(
              children: [
                _bar(height: 12, width: 12, radius: 3),
                const SizedBox(width: 6),
                _bar(height: 12, width: 90),
                const SizedBox(width: 12),
                _bar(height: 8, width: 8, radius: 4),
                const SizedBox(width: 6),
                _bar(height: 12, width: 50),
              ],
            ),
            const SizedBox(height: 10),

            // Row 3 — description (2 lines)
            _bar(height: 12, width: double.infinity),
            const SizedBox(height: 6),
            _bar(height: 12, width: 220),
            const SizedBox(height: 12),

            // Row 4 — time
            Row(
              children: [
                _bar(height: 12, width: 12, radius: 3),
                const SizedBox(width: 6),
                _bar(height: 12, width: 70),
              ],
            ),
          ],
        ),
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

/// Vertical list of [TicketCardShimmer]s for use as the loading state
/// of any tickets list screen.
///
/// Uses [Column] (not ListView.shrinkWrap) so it works inside any parent —
/// SliverList, PagedListView's firstPageProgressIndicatorBuilder, IntrinsicHeight,
/// or other widgets that query intrinsic dimensions.
class TicketCardShimmerList extends StatelessWidget {
  final int itemCount;
  final EdgeInsetsGeometry padding;

  const TicketCardShimmerList({
    super.key,
    this.itemCount = 3,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(
          itemCount,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 12),
            child: const TicketCardShimmer(),
          ),
        ),
      ),
    );
  }
}
