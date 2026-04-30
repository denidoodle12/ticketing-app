import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../core/utils/app_info.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _hasIdentifierInput = false;
  bool _hasPasswordInput = false;

  // Track if form has been submitted at least once
  bool _hasAttemptedSubmit = false;

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(_onIdentifierChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _identifierController.removeListener(_onIdentifierChanged);
    _passwordController.removeListener(_onPasswordChanged);
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onIdentifierChanged() {
    final hasInput = _identifierController.text.isNotEmpty;
    if (hasInput != _hasIdentifierInput) {
      setState(() {
        _hasIdentifierInput = hasInput;
      });
    }
    // Trigger rebuild for real-time validation after first submit attempt
    if (_hasAttemptedSubmit) {
      setState(() {});
    }
  }

  void _onPasswordChanged() {
    final hasInput = _passwordController.text.isNotEmpty;
    if (hasInput != _hasPasswordInput) {
      setState(() {
        _hasPasswordInput = hasInput;
      });
    }
    // Trigger rebuild for real-time validation after first submit attempt
    if (_hasAttemptedSubmit) {
      setState(() {});
    }
  }

  bool get _canSubmit => _hasIdentifierInput && _hasPasswordInput;

  Future<void> _handleLogin() async {
    // Mark that user has attempted to submit
    setState(() {
      _hasAttemptedSubmit = true;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      _identifierController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Check if first login - redirect to change password without toast
      if (authProvider.isFirstLogin) {
        context.go(AppRoutes.changePassword, extra: true);
      } else {
        // Normal login - show toast and go to home
        ToastHelper.showSuccess(
          context,
          'Success',
          description: 'Login successful!',
        );
        context.go(AppRoutes.home);
      }
    } else {
      ToastHelper.showError(
        context,
        'Error',
        description:
            authProvider.errorMessage ?? 'Failed to login, please try again.',
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 48,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      // Enable real-time validation only after first submit attempt
                      autovalidateMode: _hasAttemptedSubmit
                          ? AutovalidateMode.onUserInteraction
                          : AutovalidateMode.disabled,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 48),

                          // App Logo
                          Center(
                            child: Image.asset(
                              AssetPaths.tixcoraColor,
                              width: 100,
                              height: 100,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Title
                          Text('Welcome!', style: AppTextStyles.h2),
                          const SizedBox(height: 8),
                          Text(
                            'Log in to report an IT ticket.',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Email/Username Field
                          CustomTextField(
                            controller: _identifierController,
                            label: 'Email/Username',
                            hint: 'Enter your email or username',
                            keyboardType: TextInputType.text,
                            prefixIcon: const Icon(
                              Icons.account_circle_outlined,
                            ),
                            validator: Validators.emailOrUsername,
                          ),
                          const SizedBox(height: 16),

                          // Password Field
                          CustomTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: 'Enter your password',
                            obscureText: true,
                            prefixIcon: const Icon(Icons.lock_outline),
                            validator: Validators.password,
                          ),
                          const SizedBox(height: 12),

                          // Forgot Password Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () =>
                                  context.push(AppRoutes.forgotPassword),
                              child: Text(
                                'Forgot Password?',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login Button
                          Consumer<AuthProvider>(
                            builder: (context, authProvider, _) {
                              return CustomButton(
                                text: 'Login',
                                onPressed: _handleLogin,
                                isLoading: authProvider.isLoading,
                                isEnabled: _canSubmit,
                              );
                            },
                          ),

                          // Spacer to push AppVersion to center between button and bottom
                          const Spacer(),

                          // App Version (dynamic from pubspec.yaml)
                          Center(
                            child: Text(
                              'v${AppInfo.version}',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),

                          // Another spacer for equal spacing below
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
