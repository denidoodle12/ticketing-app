import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/gradient_header.dart';
import '../../../shared/widgets/form_card.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../routes/app_routes.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/password_requirements.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isFirstLogin;

  const ChangePasswordScreen({super.key, this.isFirstLogin = false});

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
      setState(() => _hasOldPasswordInput = hasInput);
    }
    if (_hasAttemptedSubmit) setState(() {});
  }

  void _onNewPasswordChanged() {
    final hasInput = _newPasswordController.text.isNotEmpty;
    if (hasInput != _hasNewPasswordInput) {
      setState(() => _hasNewPasswordInput = hasInput);
    }
    setState(() {});
  }

  void _onConfirmPasswordChanged() {
    final hasInput = _confirmPasswordController.text.isNotEmpty;
    if (hasInput != _hasConfirmPasswordInput) {
      setState(() => _hasConfirmPasswordInput = hasInput);
    }
    if (_hasAttemptedSubmit) setState(() {});
  }

  bool get _canSubmit =>
      _hasOldPasswordInput && _hasNewPasswordInput && _hasConfirmPasswordInput;

  String? _validateNewPassword(String? value) {
    final passwordError = Validators.password(value);
    if (passwordError != null) return passwordError;
    if (value == _oldPasswordController.text) {
      return 'New password must be different from old password';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    return Validators.confirmPassword(value, _newPasswordController.text);
  }

  Future<void> _handleChangePassword() async {
    setState(() => _hasAttemptedSubmit = true);
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();

    // Check connectivity before changing password
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      if (mounted) {
        ToastHelper.showError(
          context,
          'Failed to Change Password',
          description: 'No internet connection. Please check your network.',
        );
      }
      return;
    }

    final success = await authProvider.changePassword(
      _oldPasswordController.text,
      _newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      ToastHelper.showSuccess(
        context,
        'Success',
        description: 'Password changed successfully.',
      );
      if (widget.isFirstLogin) {
        context.go(AppRoutes.home);
      } else {
        context.pop();
      }
    } else {
      ToastHelper.showError(
        context,
        'Failed to Change Password',
        description: authProvider.errorMessage ?? 'Failed to change password.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: GradientHeader(
                title: widget.isFirstLogin
                    ? 'Create Password'
                    : 'Change Password',
                subtitle: widget.isFirstLogin
                    ? 'Create a strong password to keep your account safe'
                    : 'Enter your current password and create a new one',
                icon: Icons.lock_outline,
                showBackButton: !widget.isFirstLogin,
                backgroundColor: AppColors.white,
              ),
            ),
            SliverToBoxAdapter(child: _buildFormContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Form(
        key: _formKey,
        autovalidateMode: _hasAttemptedSubmit
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First login logo
            if (widget.isFirstLogin) ...[
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow.withAlpha(20),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(AssetPaths.appLogo, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Current Password Section
            const SectionLabel(label: 'Current Password'),
            const SizedBox(height: 12),
            FormCard(
              child: CustomTextField(
                controller: _oldPasswordController,
                hint: 'Enter your current password',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline),
                validator: Validators.oldPasswordRequired,
              ),
            ),

            const SizedBox(height: 24),

            // New Password Section
            const SectionLabel(label: 'New Password'),
            const SizedBox(height: 12),
            FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    controller: _newPasswordController,
                    hint: 'Enter your new password',
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    validator: _validateNewPassword,
                  ),
                  if (_newPasswordController.text.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    PasswordStrengthIndicator(
                      password: _newPasswordController.text,
                    ),
                  ],
                  const SizedBox(height: 16),
                  PasswordRequirements(password: _newPasswordController.text),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Confirm Password Section
            const SectionLabel(label: 'Confirm Password'),
            const SizedBox(height: 12),
            FormCard(
              child: CustomTextField(
                controller: _confirmPasswordController,
                hint: 'Re-enter your new password',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline),
                validator: _validateConfirmPassword,
              ),
            ),

            const SizedBox(height: 32),

            // Change Password Button
            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_canSubmit && !authProvider.isLoading)
                        ? _handleChangePassword
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor: AppColors.grey300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Change Password',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: _canSubmit
                                  ? AppColors.white
                                  : AppColors.textDisabled,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
