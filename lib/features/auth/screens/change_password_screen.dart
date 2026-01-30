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

class ChangePasswordScreen extends StatefulWidget {
  final bool isFirstLogin;

  const ChangePasswordScreen({
    super.key,
    this.isFirstLogin = false,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _hasOldPasswordInput = false;
  bool _hasNewPasswordInput = false;
  bool _hasConfirmPasswordInput = false;

  // Track if form has been submitted at least once
  bool _hasAttemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    _oldPasswordController.addListener(_onOldPasswordChanged);
    _newPasswordController.addListener(_onNewPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  @override
  void dispose() {
    _oldPasswordController.removeListener(_onOldPasswordChanged);
    _newPasswordController.removeListener(_onNewPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onOldPasswordChanged() {
    final hasInput = _oldPasswordController.text.isNotEmpty;
    if (hasInput != _hasOldPasswordInput) {
      setState(() {
        _hasOldPasswordInput = hasInput;
      });
    }
    // Trigger rebuild for real-time validation after first submit attempt
    if (_hasAttemptedSubmit) {
      setState(() {});
    }
  }

  void _onNewPasswordChanged() {
    final hasInput = _newPasswordController.text.isNotEmpty;
    if (hasInput != _hasNewPasswordInput) {
      setState(() {
        _hasNewPasswordInput = hasInput;
      });
    }
    // Always rebuild to update password requirements indicator
    setState(() {});
  }

  void _onConfirmPasswordChanged() {
    final hasInput = _confirmPasswordController.text.isNotEmpty;
    if (hasInput != _hasConfirmPasswordInput) {
      setState(() {
        _hasConfirmPasswordInput = hasInput;
      });
    }
    // Trigger rebuild for real-time validation after first submit attempt
    if (_hasAttemptedSubmit) {
      setState(() {});
    }
  }

  bool get _canSubmit =>
      _hasOldPasswordInput && _hasNewPasswordInput && _hasConfirmPasswordInput;

  String? _validateNewPassword(String? value) {
    final passwordError = Validators.password(value);
    if (passwordError != null) {
      return passwordError;
    }

    if (value == _oldPasswordController.text) {
      return 'New password must be different from old password';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    return Validators.confirmPassword(value, _newPasswordController.text);
  }

  Future<void> _handleChangePassword() async {
    // Mark that user has attempted to submit
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.changePassword(
      _oldPasswordController.text,
      _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Show success toast and go back
      ToastHelper.showSuccess(
        context,
        'Success',
        description: 'Password changed successfully.',
      );

      // For first login, navigate to home
      if (widget.isFirstLogin) {
        context.go(AppRoutes.home);
      } else {
        // Go back to previous screen
        context.pop();
      }
    } else {
      ToastHelper.showError(
        context,
        'Failed',
        description: authProvider.errorMessage ?? 'Failed to change password.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: widget.isFirstLogin
          ? null
          : AppBar(
              backgroundColor: AppColors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
              title: Text(
                'Change Password',
                style: AppTextStyles.h5,
              ),
            ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
            key: _formKey,
            // Enable real-time validation only after first submit attempt
            autovalidateMode: _hasAttemptedSubmit
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isFirstLogin) ...[
                  const SizedBox(height: 32),

                  // App Logo
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        AssetPaths.appLogo,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Title
                Text(
                  widget.isFirstLogin
                      ? 'Create New Password'
                      : 'Change Your Password',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  widget.isFirstLogin
                      ? 'For security reasons, please change your password before continuing.'
                      : 'Enter your current password and create a new password.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Old Password Field
                CustomTextField(
                  controller: _oldPasswordController,
                  label: 'Current Password',
                  hint: 'Enter your current password',
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline),
                  validator: Validators.oldPasswordRequired,
                ),
                const SizedBox(height: 16),

                // New Password Field
                CustomTextField(
                  controller: _newPasswordController,
                  label: 'New Password',
                  hint: 'Enter your new password',
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline),
                  validator: _validateNewPassword,
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
                  label: 'Confirm New Password',
                  hint: 'Re-enter your new password',
                  obscureText: true,
                  prefixIcon: const Icon(Icons.lock_outline),
                  validator: _validateConfirmPassword,
                ),
                const SizedBox(height: 32),

                // Change Password Button
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return CustomButton(
                      text: 'Change Password',
                      onPressed: _handleChangePassword,
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
