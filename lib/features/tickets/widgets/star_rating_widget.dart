import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';

/// Interactive star rating widget with tap and animation support
/// Used in both rating submission (interactive) and rating display (read-only)
class StarRatingWidget extends StatefulWidget {
  final int rating;
  final int maxRating;
  final double starSize;
  final bool readOnly;
  final ValueChanged<int>? onRatingChanged;

  const StarRatingWidget({
    super.key,
    this.rating = 0,
    this.maxRating = 5,
    this.starSize = 40,
    this.readOnly = false,
    this.onRatingChanged,
  });

  @override
  State<StarRatingWidget> createState() => _StarRatingWidgetState();
}

class _StarRatingWidgetState extends State<StarRatingWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  int _currentRating = 0;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.rating;

    _controllers = List.generate(
      widget.maxRating,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    _scaleAnimations = _controllers.map((controller) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
      ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();
  }

  @override
  void didUpdateWidget(StarRatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rating != oldWidget.rating) {
      setState(() => _currentRating = widget.rating);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _handleTap(int index) {
    if (widget.readOnly) return;

    setState(() {
      _currentRating = index + 1;
    });

    // Play bounce animation for tapped star and all before it
    for (int i = 0; i <= index; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (mounted) {
          _controllers[i].forward(from: 0);
        }
      });
    }

    widget.onRatingChanged?.call(_currentRating);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.maxRating, (index) {
        final isActive = index < _currentRating;

        return GestureDetector(
          onTap: () => _handleTap(index),
          child: AnimatedBuilder(
            animation: _scaleAnimations[index],
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimations[index].value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    isActive ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: widget.starSize,
                    color: isActive
                        ? AppColors.warning500
                        : AppColors.secondary200,
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
