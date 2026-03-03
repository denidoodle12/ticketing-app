import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../routes/app_routes.dart';

class ChangePasswordSuccessScreen extends StatefulWidget {
  const ChangePasswordSuccessScreen({super.key});

  @override
  State<ChangePasswordSuccessScreen> createState() =>
      _ChangePasswordSuccessScreenState();
}

class _ChangePasswordSuccessScreenState
    extends State<ChangePasswordSuccessScreen> with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _confettiController;
  late Animation<double> _checkScaleAnimation;
  late Animation<double> _checkFadeAnimation;
  late Animation<double> _confettiAnimation;

  @override
  void initState() {
    super.initState();

    // Check mark animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _checkScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: Curves.elasticOut,
      ),
    );

    _checkFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Confetti animation
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _confettiAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _confettiController,
        curve: Curves.easeOut,
      ),
    );

    // Start animations
    _checkController.forward().then((_) {
      _confettiController.forward();
    });
  }

  @override
  void dispose() {
    _checkController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    // Pass flag to show welcome toast on home screen
    context.go(AppRoutes.home, extra: {'showWelcomeToast': true});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Success illustration with animations
                _buildSuccessIllustration(),

                const SizedBox(height: 40),

                // Title
                Text(
                  'Password Changed!',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Your password has been changed successfully. You can now use your new password to login.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const Spacer(flex: 3),

                // Continue button
                CustomButton(
                  text: 'Continue to Home',
                  onPressed: _navigateToHome,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIllustration() {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Confetti particles
          AnimatedBuilder(
            animation: _confettiAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(280, 220),
                painter: ConfettiPainter(
                  progress: _confettiAnimation.value,
                  primaryColor: AppColors.primaryDark,
                  secondaryColor: AppColors.primary400,
                  accentColor: AppColors.success500,
                ),
              );
            },
          ),

          // Person illustration
          _buildPersonIllustration(),

          // Success check badge
          Positioned(
            top: 0,
            child: AnimatedBuilder(
              animation: _checkController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _checkScaleAnimation.value,
                  child: Opacity(
                    opacity: _checkFadeAnimation.value,
                    child: _buildSuccessBadge(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBadge() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.success500,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.success500.withAlpha(80),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.check_rounded,
        color: AppColors.white,
        size: 40,
      ),
    );
  }

  Widget _buildPersonIllustration() {
    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: PersonCelebrationPainter(
          primaryColor: AppColors.primaryDark,
          skinColor: const Color(0xFFFFDBB4),
          hairColor: const Color(0xFF4A4A4A),
        ),
      ),
    );
  }
}

/// Custom painter for the celebrating person
class PersonCelebrationPainter extends CustomPainter {
  final Color primaryColor;
  final Color skinColor;
  final Color hairColor;

  PersonCelebrationPainter({
    required this.primaryColor,
    required this.skinColor,
    required this.hairColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2 + 20;

    // Body (shirt)
    final bodyPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;

    final bodyPath = Path();
    bodyPath.moveTo(centerX - 35, centerY + 10);
    bodyPath.quadraticBezierTo(centerX - 40, centerY + 50, centerX - 30, centerY + 70);
    bodyPath.lineTo(centerX + 30, centerY + 70);
    bodyPath.quadraticBezierTo(centerX + 40, centerY + 50, centerX + 35, centerY + 10);
    bodyPath.close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Left arm raised
    final armPath1 = Path();
    armPath1.moveTo(centerX - 35, centerY + 15);
    armPath1.quadraticBezierTo(centerX - 60, centerY - 20, centerX - 55, centerY - 45);
    armPath1.quadraticBezierTo(centerX - 50, centerY - 50, centerX - 45, centerY - 45);
    armPath1.quadraticBezierTo(centerX - 45, centerY - 15, centerX - 30, centerY + 20);
    armPath1.close();
    canvas.drawPath(armPath1, bodyPaint);

    // Right arm raised
    final armPath2 = Path();
    armPath2.moveTo(centerX + 35, centerY + 15);
    armPath2.quadraticBezierTo(centerX + 60, centerY - 20, centerX + 55, centerY - 45);
    armPath2.quadraticBezierTo(centerX + 50, centerY - 50, centerX + 45, centerY - 45);
    armPath2.quadraticBezierTo(centerX + 45, centerY - 15, centerX + 30, centerY + 20);
    armPath2.close();
    canvas.drawPath(armPath2, bodyPaint);

    // Left hand
    final skinPaint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(centerX - 52, centerY - 50), 10, skinPaint);

    // Right hand
    canvas.drawCircle(Offset(centerX + 52, centerY - 50), 10, skinPaint);

    // Head/Face
    canvas.drawCircle(Offset(centerX, centerY - 15), 28, skinPaint);

    // Hair
    final hairPaint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.fill;

    final hairPath = Path();
    hairPath.moveTo(centerX - 25, centerY - 25);
    hairPath.quadraticBezierTo(centerX - 28, centerY - 50, centerX, centerY - 48);
    hairPath.quadraticBezierTo(centerX + 28, centerY - 50, centerX + 25, centerY - 25);
    hairPath.quadraticBezierTo(centerX + 20, centerY - 35, centerX, centerY - 38);
    hairPath.quadraticBezierTo(centerX - 20, centerY - 35, centerX - 25, centerY - 25);
    hairPath.close();
    canvas.drawPath(hairPath, hairPaint);

    // Eyes (closed/happy)
    // Left eye
    final leftEyePath = Path();
    leftEyePath.moveTo(centerX - 12, centerY - 18);
    leftEyePath.quadraticBezierTo(centerX - 8, centerY - 22, centerX - 4, centerY - 18);
    canvas.drawPath(
      leftEyePath,
      Paint()
        ..color = const Color(0xFF4A4A4A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Right eye (closed/happy)
    final rightEyePath = Path();
    rightEyePath.moveTo(centerX + 4, centerY - 18);
    rightEyePath.quadraticBezierTo(centerX + 8, centerY - 22, centerX + 12, centerY - 18);
    canvas.drawPath(
      rightEyePath,
      Paint()
        ..color = const Color(0xFF4A4A4A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Smile
    final smilePath = Path();
    smilePath.moveTo(centerX - 10, centerY - 5);
    smilePath.quadraticBezierTo(centerX, centerY + 5, centerX + 10, centerY - 5);
    canvas.drawPath(
      smilePath,
      Paint()
        ..color = const Color(0xFF4A4A4A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for confetti particles
class ConfettiPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  ConfettiPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final colors = [primaryColor, secondaryColor, accentColor, AppColors.warning500];

    // Draw confetti particles
    final confettiData = [
      // Left side particles
      {'x': -80.0, 'y': -40.0, 'rotation': 45.0, 'size': 8.0, 'colorIdx': 0},
      {'x': -60.0, 'y': -60.0, 'rotation': 30.0, 'size': 6.0, 'colorIdx': 1},
      {'x': -90.0, 'y': 0.0, 'rotation': 60.0, 'size': 7.0, 'colorIdx': 2},
      {'x': -70.0, 'y': 20.0, 'rotation': 15.0, 'size': 5.0, 'colorIdx': 3},
      {'x': -50.0, 'y': -30.0, 'rotation': 75.0, 'size': 6.0, 'colorIdx': 0},
      {'x': -100.0, 'y': -20.0, 'rotation': 40.0, 'size': 4.0, 'colorIdx': 1},
      // Right side particles
      {'x': 80.0, 'y': -40.0, 'rotation': -45.0, 'size': 8.0, 'colorIdx': 2},
      {'x': 60.0, 'y': -60.0, 'rotation': -30.0, 'size': 6.0, 'colorIdx': 3},
      {'x': 90.0, 'y': 0.0, 'rotation': -60.0, 'size': 7.0, 'colorIdx': 0},
      {'x': 70.0, 'y': 20.0, 'rotation': -15.0, 'size': 5.0, 'colorIdx': 1},
      {'x': 50.0, 'y': -30.0, 'rotation': -75.0, 'size': 6.0, 'colorIdx': 2},
      {'x': 100.0, 'y': -20.0, 'rotation': -40.0, 'size': 4.0, 'colorIdx': 3},
      // Top particles
      {'x': -30.0, 'y': -70.0, 'rotation': 20.0, 'size': 5.0, 'colorIdx': 0},
      {'x': 30.0, 'y': -70.0, 'rotation': -20.0, 'size': 5.0, 'colorIdx': 1},
      {'x': 0.0, 'y': -80.0, 'rotation': 0.0, 'size': 6.0, 'colorIdx': 2},
    ];

    for (final particle in confettiData) {
      final x = centerX + (particle['x'] as double) * progress;
      final y = centerY + (particle['y'] as double) * progress + 20 * progress * progress;
      final rotation = (particle['rotation'] as double) * progress * 3.14159 / 180;
      final size = (particle['size'] as double) * (0.5 + progress * 0.5);
      final colorIdx = particle['colorIdx'] as int;
      final opacity = (1.0 - progress * 0.3).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = colors[colorIdx].withAlpha((opacity * 255).toInt())
        ..style = PaintingStyle.fill;

      // Draw rectangle confetti
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: size, height: size * 1.5),
          Radius.circular(size * 0.2),
        ),
        paint,
      );

      canvas.restore();
    }

    // Draw small dots
    final dotData = [
      {'x': -40.0, 'y': -50.0, 'colorIdx': 0},
      {'x': 40.0, 'y': -50.0, 'colorIdx': 1},
      {'x': -60.0, 'y': -10.0, 'colorIdx': 2},
      {'x': 60.0, 'y': -10.0, 'colorIdx': 3},
      {'x': -30.0, 'y': 30.0, 'colorIdx': 0},
      {'x': 30.0, 'y': 30.0, 'colorIdx': 1},
    ];

    for (final dot in dotData) {
      final x = centerX + (dot['x'] as double) * progress;
      final y = centerY + (dot['y'] as double) * progress;
      final colorIdx = dot['colorIdx'] as int;
      final opacity = (1.0 - progress * 0.5).clamp(0.0, 1.0);

      canvas.drawCircle(
        Offset(x, y),
        3 * progress,
        Paint()..color = colors[colorIdx].withAlpha((opacity * 255).toInt()),
      );
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
