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
import '../../../routes/app_routes.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String token;

  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hasNewPasswordInput = false;
  bool _hasConfirmPasswordInput = false;
  bool _hasAttemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onNewPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onNewPasswordChanged() {
    final hasInput = _newPasswordController.text.isNotEmpty;
    if (hasInput != _hasNewPasswordInput) {
      setState(() {
        _hasNewPasswordInput = hasInput;
      });
    }
    setState(() {});
  }

  void _onConfirmPasswordChanged() {
    final hasInput = _confirmPasswordController.text.isNotEmpty;
    if (hasInput != _hasConfirmPasswordInput) {
      setState(() {
        _hasConfirmPasswordInput = hasInput;
      });
    }
    if (_hasAttemptedSubmit) {
      setState(() {});
    }
  }

  bool get _canSubmit => _hasNewPasswordInput && _hasConfirmPasswordInput;

  String? _validateConfirmPassword(String? value) {
    return Validators.confirmPassword(value, _newPasswordController.text);
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.resetPassword(
      widget.token,
      _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      context.go(AppRoutes.resetPasswordSuccess);
    } else {
      ToastHelper.showError(
        context,
        'Failed',
        description: authProvider.errorMessage ?? 'Failed to reset password.',
      );
    }
  }

  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.pop(),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back,
            color: AppColors.primaryDark,
            size: 22,
          ),
        ),
      ),
    );
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
                  _buildBackButton(),
                  const SizedBox(height: 24),

                  // Vector Illustration
                  Center(
                    child: Image.asset(
                      AssetPaths.vecResetPassword,
                      height: 220,
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
                            Icons.vpn_key,
                            size: 100,
                            color: AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title (left-aligned)
                  Text('Create New Password', style: AppTextStyles.h3),
                  const SizedBox(height: 8),

                  // Description (left-aligned)
                  Text(
                    'Your new password must be different from previously used passwords.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // New Password Field
                  CustomTextField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    hint: 'Enter your new password',
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 12),

                  // Password requirements label
                  Text(
                    'Your password must contain:',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Password requirements
                  _buildPasswordRequirement(
                    'At least 8 characters',
                    _newPasswordController.text.length >= 8,
                  ),
                  _buildPasswordRequirement(
                    'At least 1 capital letter',
                    RegExp(r'[A-Z]').hasMatch(_newPasswordController.text),
                  ),
                  _buildPasswordRequirement(
                    'At least 1 lowercase letter',
                    RegExp(r'[a-z]').hasMatch(_newPasswordController.text),
                  ),
                  _buildPasswordRequirement(
                    'At least 1 number',
                    RegExp(r'[0-9]').hasMatch(_newPasswordController.text),
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Re-enter your new password',
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    validator: _validateConfirmPassword,
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, _) {
                      return CustomButton(
                        text: 'Reset Password',
                        onPressed: _handleSubmit,
                        isLoading: authProvider.isLoading,
                        isEnabled: _canSubmit,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: isMet ? AppColors.success : AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: isMet ? AppColors.success : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
