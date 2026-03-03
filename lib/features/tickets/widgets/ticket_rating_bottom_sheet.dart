import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../providers/ticket_provider.dart';
import 'star_rating_widget.dart';

/// Modern bottom sheet for submitting ticket rating
/// Features: interactive stars, text labels, feedback field, success animation
class TicketRatingBottomSheet extends StatefulWidget {
  final int ticketId;

  const TicketRatingBottomSheet({super.key, required this.ticketId});

  /// Show the rating bottom sheet
  static Future<bool?> show(BuildContext context, int ticketId) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TicketRatingBottomSheet(ticketId: ticketId),
    );
  }

  @override
  State<TicketRatingBottomSheet> createState() =>
      _TicketRatingBottomSheetState();
}

class _TicketRatingBottomSheetState extends State<TicketRatingBottomSheet>
    with TickerProviderStateMixin {
  int _selectedRating = 0;
  bool _isSuccess = false;
  final _commentController = TextEditingController();

  // Entry animation
  late AnimationController _entryController;
  late Animation<double> _entryFade;

  // Success animation
  late AnimationController _successController;
  late Animation<double> _checkScale;
  late Animation<double> _successFade;

  // Rating labels
  static const _ratingLabels = ['Very Bad', 'Bad', 'Okay', 'Good', 'Excellent'];

  @override
  void initState() {
    super.initState();

    // Entry animation
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _entryController.forward();

    // Success animation
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _checkScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 60),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 40),
        ]).animate(
          CurvedAnimation(parent: _successController, curve: Curves.easeOut),
        );
    _successFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _entryController.dispose();
    _successController.dispose();
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

    if (success) {
      // Show success animation, then auto-close
      setState(() => _isSuccess = true);
      _successController.forward();

      await Future.delayed(const Duration(milliseconds: 1800));

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      // Close and let detail screen show error toast
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FadeTransition(
      opacity: _entryFade,
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
          child: AnimatedSize(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: _isSuccess ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  /// The rating form content
  Widget _buildFormView() {
    return Padding(
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
            style: AppTextStyles.h5.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Rate the service you received',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Star rating
          StarRatingWidget(
            rating: _selectedRating,
            starSize: 44,
            onRatingChanged: _onRatingChanged,
          ),
          const SizedBox(height: 12),

          // Rating label badge
          _buildRatingLabel(),
          const SizedBox(height: 24),

          // Feedback field
          _buildFeedbackField(),
          const SizedBox(height: 24),

          // Submit button
          _buildSubmitButton(),
        ],
      ),
    );
  }

  /// The success animation view
  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          _buildDragHandle(),
          const SizedBox(height: 32),

          // Animated checkmark circle
          AnimatedBuilder(
            animation: _successController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _successFade,
                child: Transform.scale(
                  scale: _checkScale.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.success500, AppColors.accent500],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.success500.withAlpha(60),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: AppColors.white,
                      size: 44,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Thank you text
          AnimatedBuilder(
            animation: _successFade,
            builder: (context, child) {
              return FadeTransition(opacity: _successFade, child: child);
            },
            child: Column(
              children: [
                Text(
                  'Thank You!',
                  style: AppTextStyles.h4.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your feedback helps us improve',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Star display (read-only)
          AnimatedBuilder(
            animation: _successFade,
            builder: (context, child) {
              return FadeTransition(opacity: _successFade, child: child);
            },
            child: StarRatingWidget(
              rating: _selectedRating,
              starSize: 32,
              readOnly: true,
            ),
          ),
          const SizedBox(height: 8),
        ],
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

  /// Animated rating label badge
  Widget _buildRatingLabel() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _selectedRating > 0
          ? Container(
              key: ValueKey(_selectedRating),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _getRatingColor().withAlpha(20),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _getRatingColor().withAlpha(60)),
              ),
              child: Text(
                _ratingLabels[_selectedRating - 1],
                style: AppTextStyles.labelLarge.copyWith(
                  color: _getRatingColor(),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            )
          : Text(
              key: const ValueKey(0),
              'Tap a star to rate',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textDisabled,
              ),
            ),
    );
  }

  Widget _buildFeedbackField() {
    return TextField(
      controller: _commentController,
      maxLines: 3,
      maxLength: 500,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Write your feedback (optional)...',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textDisabled,
        ),
        filled: true,
        fillColor: AppColors.neutral50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.secondary200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.secondary200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        counterText: '',
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
        return AppColors.priorityHigh;
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
