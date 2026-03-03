import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../providers/ticket_provider.dart';
import 'star_rating_widget.dart';

/// Modern bottom sheet for submitting ticket rating
/// Features: dynamic emoji, interactive stars, feedback field, gradient submit button
class TicketRatingBottomSheet extends StatefulWidget {
  final int ticketId;

  const TicketRatingBottomSheet({super.key, required this.ticketId});

  /// Show the rating bottom sheet
  static Future<bool?> show(BuildContext context, int ticketId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TicketRatingBottomSheet(ticketId: ticketId),
    );
  }

  @override
  State<TicketRatingBottomSheet> createState() =>
      _TicketRatingBottomSheetState();
}

class _TicketRatingBottomSheetState extends State<TicketRatingBottomSheet>
    with SingleTickerProviderStateMixin {
  int _selectedRating = 0;
  final _commentController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Rating labels & emojis
  static const _ratingEmojis = [
    '\u{1F621}',
    '\u{1F615}',
    '\u{1F610}',
    '\u{1F60A}',
    '\u{1F929}',
  ];
  static const _ratingLabels = ['Very Bad', 'Bad', 'Okay', 'Good', 'Excellent'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onRatingChanged(int rating) {
    setState(() => _selectedRating = rating);
  }

  Future<void> _onSubmit() async {
    if (_selectedRating == 0) return;

    final provider = context.read<TicketProvider>();
    final comment = _commentController.text.trim();

    final success = await provider.submitTicketRating(
      ticketId: widget.ticketId,
      rating: _selectedRating,
      comment: comment.isNotEmpty ? comment : null,
    );

    if (!mounted) return;

    // Always close bottom sheet — detail screen handles success/error display
    Navigator.of(context).pop(success);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        margin: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                _buildDragHandle(),
                const SizedBox(height: 20),

                // Title
                Text(
                  'How Was Your Experience?',
                  style: AppTextStyles.h5.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rate the service you received',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Emoji & Label
                _buildEmojiSection(),
                const SizedBox(height: 20),

                // Star rating
                StarRatingWidget(
                  rating: _selectedRating,
                  starSize: 44,
                  onRatingChanged: _onRatingChanged,
                ),
                const SizedBox(height: 24),

                // Feedback field
                _buildFeedbackField(),
                const SizedBox(height: 24),

                // Submit button
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.secondary200,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildEmojiSection() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return ScaleTransition(scale: animation, child: child);
      },
      child: _selectedRating > 0
          ? Column(
              key: ValueKey(_selectedRating),
              children: [
                Text(
                  _ratingEmojis[_selectedRating - 1],
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getRatingColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getRatingColor().withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _ratingLabels[_selectedRating - 1],
                    style: AppTextStyles.labelLarge.copyWith(
                      color: _getRatingColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              key: const ValueKey(0),
              children: [
                Icon(
                  Icons.star_outline_rounded,
                  size: 48,
                  color: AppColors.secondary200,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap a star to rate',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFeedbackField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: TextField(
        controller: _commentController,
        maxLines: 3,
        maxLength: 500,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Write your feedback (optional)...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textDisabled,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          counterStyle: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textDisabled,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Consumer<TicketProvider>(
      builder: (context, provider, child) {
        final isSubmitting = provider.isSubmittingRating;
        final isEnabled = _selectedRating > 0 && !isSubmitting;

        return SizedBox(
          width: double.infinity,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: isEnabled
                  ? const LinearGradient(
                      colors: [AppColors.primary600, AppColors.primary500],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: isEnabled ? null : AppColors.secondary200,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: AppColors.primary500.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: MaterialButton(
              onPressed: isEnabled ? _onSubmit : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.white,
                        ),
                      ),
                    )
                  : Text(
                      'Submit Rating',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.white,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Color _getRatingColor() {
    switch (_selectedRating) {
      case 1:
        return AppColors.error500;
      case 2:
        return AppColors.priorityHigh; // Orange
      case 3:
        return AppColors.warning500;
      case 4:
        return AppColors.accent500;
      case 5:
        return AppColors.success500;
      default:
        return AppColors.secondary500;
    }
  }
}
