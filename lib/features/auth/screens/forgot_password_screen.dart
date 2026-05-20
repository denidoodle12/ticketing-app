import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/circle_icon_button.dart';
import '../../../routes/app_routes.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _hasEmailInput = false;
  bool _hasAttemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_onEmailChanged);
    _emailController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    final hasInput = _emailController.text.isNotEmpty;
    if (hasInput != _hasEmailInput) {
      setState(() {
        _hasEmailInput = hasInput;
      });
    }
    if (_hasAttemptedSubmit) {
      setState(() {});
    }
  }

  bool get _canSubmit => _hasEmailInput;

  Future<void> _handleSubmit() async {
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final success = await authProvider.requestPasswordReset(email);

    if (!mounted) return;

    if (success) {
      context.push(AppRoutes.verificationCode, extra: email);
    } else {
      ToastHelper.showError(
        context,
        'Failed',
        description: authProvider.errorMessage ?? 'Failed to send reset code.',
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              autovalidateMode: _hasAttemptedSubmit
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button
                  CircleIconButton.back(context),
                  const SizedBox(height: 24),

                  // Vector Illustration
                  Center(
                    child: Image.asset(
                      AssetPaths.vecForgotPassword,
                      height: 270,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 250,
                          width: 250,
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_reset,
                            size: 100,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title (left-aligned)
                  Text('Forgot Password?', style: AppTextStyles.h3),
                  const SizedBox(height: 8),

                  // Description (left-aligned)
                  Text(
                    'Enter your registered email address to receive a password reset code.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email Input
                  CustomTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'Enter your email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return CustomButton(
                        text: 'Send Reset Code',
                        onPressed: _handleSubmit,
                        isLoading: authProvider.isLoading,
                        isEnabled: _canSubmit,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
