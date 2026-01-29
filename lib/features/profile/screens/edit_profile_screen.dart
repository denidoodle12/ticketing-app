import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../core/utils/image_picker_helper.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/image_preview_dialog.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _hasChanges = false;
  bool _isUploadingImage = false;
  String? _uploadMessage;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    final user = context.read<ProfileProvider>().user;
    if (user != null) {
      _nameController.text = user.name;
      _lastNameController.text = user.lastName ?? '';
      _phoneController.text = user.phoneNumber ?? '';
    }

    _nameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    final user = context.read<ProfileProvider>().user;
    if (user != null) {
      final hasChanges = _nameController.text != user.name ||
          _lastNameController.text != (user.lastName ?? '') ||
          _phoneController.text != (user.phoneNumber ?? '');

      if (hasChanges != _hasChanges) {
        setState(() {
          _hasChanges = hasChanges;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Show source selection bottom sheet
    final source = await ImagePickerHelper.showImageSourceSheet(context);
    if (source == null || !mounted) return;

    // Pick and crop image
    final croppedFile = await ImagePickerHelper.pickAndCropImage(
      context: context,
      source: source,
      cropCircle: true,
    );

    if (croppedFile == null || !mounted) return;

    // Show preview dialog
    final shouldUpload = await ImagePreviewDialog.show(
      context: context,
      imageFile: croppedFile,
    );

    if (shouldUpload == true && mounted) {
      _uploadImage(croppedFile);
    } else if (shouldUpload == false && mounted) {
      // User wants to retake - show picker again
      _pickImage();
    }
  }

  Future<void> _uploadImage(File file) async {
    setState(() {
      _isUploadingImage = true;
      _uploadMessage = 'Uploading photo...';
    });

    final profileProvider = context.read<ProfileProvider>();
    final authProvider = context.read<AuthProvider>();
    final success = await profileProvider.uploadProfilePicture(file.path);

    if (mounted) {
      setState(() {
        _isUploadingImage = false;
        _uploadMessage = null;
      });

      if (success && profileProvider.user != null) {
        authProvider.updateCurrentUser(profileProvider.user!);
        ToastHelper.showSuccess(context, 'Profile picture updated');
      } else {
        ToastHelper.showError(
          context,
          profileProvider.errorMessage ?? 'Failed to upload picture',
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profileProvider = context.read<ProfileProvider>();
    final authProvider = context.read<AuthProvider>();

    final success = await profileProvider.updateProfile(
      name: _nameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );

    if (mounted) {
      if (success && profileProvider.user != null) {
        authProvider.updateCurrentUser(profileProvider.user!);
        ToastHelper.showSuccess(context, 'Profile updated successfully');
        Navigator.pop(context);
      } else {
        ToastHelper.showError(
          context,
          profileProvider.errorMessage ?? 'Failed to update profile',
        );
      }
    }
  }

  void _discardChanges() {
    if (_hasChanges) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard Changes?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error500,
              ),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, profileProvider, child) {
        final user = profileProvider.user;
        final isLoading = _isUploadingImage || profileProvider.isUpdating;

        return LoadingOverlay(
          isLoading: isLoading,
          message: _uploadMessage ?? 'Saving...',
          child: Scaffold(
            backgroundColor: AppColors.scaffoldBackground,
            appBar: AppBar(
              title: const Text('Edit Profile'),
              backgroundColor: AppColors.white,
              surfaceTintColor: AppColors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: isLoading ? null : _discardChanges,
              ),
            ),
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // Avatar Section
                  Container(
                    width: double.infinity,
                    color: AppColors.white,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        ProfileAvatar(
                          imageUrl: user?.profilePicture != null
                              ? '${ApiConfig.baseUrl}${user!.profilePicture}'
                              : null,
                          name: user?.fullName ?? 'User',
                          size: 100,
                          showEditIcon: true,
                          onTap: isLoading ? null : _pickImage,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tap to change photo',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Form Section
                  Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email (Read-only)
                          _buildReadOnlyField(
                            label: 'Email',
                            value: user?.email ?? '',
                            icon: Icons.email_outlined,
                          ),
                          const SizedBox(height: 16),

                          // Username (Read-only)
                          _buildReadOnlyField(
                            label: 'Username',
                            value: user?.username ?? '',
                            icon: Icons.alternate_email,
                          ),
                          const SizedBox(height: 16),

                          // Name
                          CustomTextField(
                            controller: _nameController,
                            label: 'First Name',
                            hint: 'Enter your first name',
                            prefixIcon: const Icon(Icons.person_outline),
                            enabled: !isLoading,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'First name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Last Name
                          CustomTextField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            hint: 'Enter your last name',
                            prefixIcon: const Icon(Icons.person_outline),
                            enabled: !isLoading,
                          ),
                          const SizedBox(height: 16),

                          // Phone Number
                          CustomTextField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            hint: 'Enter your phone number',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            keyboardType: TextInputType.phone,
                            enabled: !isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isLoading ? null : _discardChanges,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Discard'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (isLoading || !_hasChanges)
                                ? null
                                : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.grey100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Icon(
                Icons.lock_outline,
                color: AppColors.textDisabled,
                size: 16,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
