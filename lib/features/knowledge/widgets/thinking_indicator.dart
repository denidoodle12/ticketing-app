import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/asset_paths.dart';

/// Gemini-style thinking indicator with circular loading around Tixcora icon
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular loading with Tixcora icon inside
        SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Spinning circle indicator
              RotationTransition(
                turns: _controller,
                child: CustomPaint(
                  size: const Size(32, 32),
                  painter: _GradientCirclePainter(),
                ),
              ),
              // Tixcora icon in center
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Image.asset(
                  AssetPaths.tixcoraColor,
                  width: 18,
                  height: 18,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // "TixAI is thinking..." text
        Text(
          'TixAI is thinking...',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Custom painter for gradient arc around the icon
class _GradientCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    const sweepAngle = 4.2; // ~240 degrees arc

    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: sweepAngle,
        colors: [
          AppColors.primary500.withAlpha(10),
          AppColors.primary400,
          AppColors.primary600,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(1.5), // Inset to fit stroke inside bounds
      -1.57, // Start from top (−π/2)
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
