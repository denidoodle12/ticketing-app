import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../../../data/datasources/local/local_storage.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/constants/api_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../core/utils/image_picker_helper.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/loading_overlay.dart';

import '../../../shared/widgets/section_label.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/image_preview_dialog.dart';
import '../../../shared/widgets/profile_picture_viewer.dart';

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
  bool _hasAttemptedSubmit = false;

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
      final hasChanges =
          _nameController.text != user.name ||
          _lastNameController.text != (user.lastName ?? '') ||
          _phoneController.text != (user.phoneNumber ?? '');

      if (hasChanges != _hasChanges) {
        setState(() => _hasChanges = hasChanges);
      }
      if (_hasAttemptedSubmit) setState(() {});
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
    final source = await ImagePickerHelper.showImageSourceSheet(context);
    if (source == null || !mounted) return;

    final result = await ImagePickerHelper.pickAndCropImageWithValidation(
      context: context,
      source: source,
      cropCircle: true,
      maxFileSizeMB: AppConstants.maxProfilePictureSizeMB,
    );

    if (!mounted) return;

    if (result.hasError) {
      ToastHelper.showError(
        context,
        'Upload Failed',
        description: result.error!,
      );
      return;
    }

    if (result.file == null) return;

    final shouldUpload = await ImagePreviewDialog.show(
      context: context,
      imageFile: result.file!,
    );

    if (shouldUpload == true && mounted) {
      _uploadImage(result.file!);
    } else if (shouldUpload == false && mounted) {
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
        ToastHelper.showSuccess(
          context,
          'Success',
          description: 'Profile picture updated successfully',
        );
      } else {
        ToastHelper.showError(
          context,
          'Upload Failed',
          description:
              profileProvider.errorMessage ?? 'Failed to upload picture',
        );
      }
    }
  }

  Future<void> _downloadProfilePicture() async {
    final user = context.read<ProfileProvider>().user;
    if (user?.profilePicture == null) {
      ToastHelper.showError(
        context,
        'Download Failed',
        description: 'No profile picture to download',
      );
      return;
    }

    setState(() {
      _isUploadingImage = true;
      _uploadMessage = 'Downloading photo...';
    });

    try {
      if (Platform.isAndroid) {
        final hasAccess = await Gal.hasAccess(toAlbum: true);
        if (!hasAccess) {
          final granted = await Gal.requestAccess(toAlbum: true);
          if (!granted && mounted) {
            setState(() {
              _isUploadingImage = false;
              _uploadMessage = null;
            });
            ToastHelper.showError(
              context,
              'Permission Denied',
              description: 'Gallery permission is required to save photo',
            );
            return;
          }
        }
      }

      final imageUrl = '${ApiConfig.baseUrl}${user!.profilePicture}';
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'profile_${user.username}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempPath = '${tempDir.path}/$fileName';

      final dio = Dio();

      // Read fresh token for auth header
      if (!mounted) return;
      final localStorage = context.read<LocalStorage>();
      final token = await localStorage.getAccessToken();
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      await dio.download(imageUrl, tempPath, options: Options(headers: headers));
      await Gal.putImage(tempPath, album: 'Ticketing App');

      final tempFile = File(tempPath);
      if (await tempFile.exists()) await tempFile.delete();

      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _uploadMessage = null;
        });
        ToastHelper.showSuccess(
          context,
          'Success',
          description: 'Photo saved to Gallery > Ticketing App',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          _uploadMessage = null;
        });
        ToastHelper.showError(
          context,
          'Download Failed',
          description: 'Failed to download photo. Please try again.',
        );
      }
    }
  }

  void _viewProfilePicture() {
    final user = context.read<ProfileProvider>().user;
    if (user?.profilePicture == null) return;

    ProfilePictureViewer.show(
      context: context,
      imageUrl: '${ApiConfig.baseUrl}${user!.profilePicture}',
      userName: user.fullName,
      heroTag: 'edit_profile_avatar',
    );
  }

  Future<void> _deleteProfilePicture() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.error500.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error500,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Photo'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your profile picture? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Delete',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isUploadingImage = true;
      _uploadMessage = 'Deleting photo...';
    });

    final profileProvider = context.read<ProfileProvider>();
    final authProvider = context.read<AuthProvider>();
    final success = await profileProvider.deleteProfilePicture();

    if (mounted) {
      setState(() {
        _isUploadingImage = false;
        _uploadMessage = null;
      });

      if (success && profileProvider.user != null) {
        authProvider.updateCurrentUser(profileProvider.user!);
        ToastHelper.showSuccess(
          context,
          'Success',
          description: 'Profile picture deleted successfully',
        );
      } else {
        ToastHelper.showError(
          context,
          'Delete Failed',
          description:
              profileProvider.errorMessage ?? 'Failed to delete picture',
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _hasAttemptedSubmit = true);
    if (!_formKey.currentState!.validate()) return;

    final profileProvider = context.read<ProfileProvider>();
    final authProvider = context.read<AuthProvider>();

    // Check connectivity before saving
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      if (mounted) {
        ToastHelper.showError(
          context,
          'Failed to Update Profile',
          description: 'No internet connection. Please check your network.',
        );
      }
      return;
    }

    final success = await profileProvider.updateProfile(
      name: _nameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
    );

    if (mounted) {
      if (success && profileProvider.user != null) {
        authProvider.updateCurrentUser(profileProvider.user!);
        ToastHelper.showSuccess(
          context,
          'Success',
          description: 'Profile updated successfully',
        );
        Navigator.pop(context);
      } else {
        ToastHelper.showError(
          context,
          'Failed to Update Profile',
          description:
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Discard Changes?',
            style: AppTextStyles.h5.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'You have unsaved changes. Are you sure you want to discard them?',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Keep Editing',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                'Discard',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error500,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
            backgroundColor: AppColors.white,
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(user, isLoading)),
                SliverToBoxAdapter(child: _buildFormContent(user, isLoading)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(user, bool isLoading) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom AppBar - flat white, matching ticket detail style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildActionButton(
                    icon: Icons.arrow_back,
                    onTap: isLoading ? null : _discardChanges,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Edit Profile',
                        style: AppTextStyles.h5.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Avatar Section
            _buildAvatarSection(user, isLoading),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(user, bool isLoading) {
    final hasPhoto = user?.profilePicture != null;
    final imageUrl = hasPhoto
        ? '${ApiConfig.baseUrl}${user!.profilePicture}'
        : null;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryDark, width: 2),
          ),
          child: ProfileAvatar(
            imageUrl: imageUrl,
            name: user?.fullName ?? 'User',
            size: 100,
            showEditIcon: true,
            heroTag: 'edit_profile_avatar',
            onTap: isLoading ? null : _pickImage,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap avatar to change photo',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (hasPhoto) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // View Photo
              TextButton.icon(
                onPressed: isLoading ? null : _viewProfilePicture,
                icon: const Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
                label: Text(
                  'View',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Download Photo
              TextButton.icon(
                onPressed: isLoading ? null : _downloadProfilePicture,
                icon: const Icon(
                  Icons.download_rounded,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
                label: Text(
                  'Save',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Delete Photo
              TextButton.icon(
                onPressed: isLoading ? null : _deleteProfilePicture,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.error500,
                ),
                label: Text(
                  'Delete',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Back button matching ticket detail screen style
  Widget _buildActionButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
          child: Icon(icon, color: AppColors.primaryDark, size: 22),
        ),
      ),
    );
  }

  Widget _buildFormContent(user, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account Info (Read-only)
          const SectionLabel(label: 'Account Information'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withAlpha(12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildReadOnlyField(
                  label: 'Email',
                  value: user?.email ?? '',
                  icon: Icons.email_outlined,
                ),
                const Divider(height: 16, thickness: 0.5),
                _buildReadOnlyField(
                  label: 'Username',
                  value: '@${user?.username ?? ''}',
                  icon: Icons.alternate_email,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Personal Info (Editable)
          const SectionLabel(label: 'Personal Information'),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            autovalidateMode: _hasAttemptedSubmit
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldLabel('First Name', isRequired: true),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _nameController,
                  hint: 'Enter your first name',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: AppColors.primaryDark,
                  ),
                  enabled: !isLoading,
                  validator: Validators.profileFirstName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Last Name'),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _lastNameController,
                  hint: 'Enter your last name',
                  prefixIcon: const Icon(
                    Icons.person_outline,
                    color: AppColors.primaryDark,
                  ),
                  enabled: !isLoading,
                  validator: Validators.profileLastName,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Phone Number'),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _phoneController,
                  hint: 'Enter your phone number',
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                    color: AppColors.primaryDark,
                  ),
                  keyboardType: TextInputType.phone,
                  enabled: !isLoading,
                  maxLength: AppConstants.maxPhoneNumberLength,
                  validator: Validators.profilePhoneNumber,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              // Discard button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : _discardChanges,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      side: const BorderSide(color: AppColors.grey300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Save Changes button
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: (isLoading || !_hasChanges)
                          ? null
                          : const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                AppColors.primary600,
                                AppColors.primary500,
                              ],
                            ),
                      color: (isLoading || !_hasChanges)
                          ? AppColors.grey300
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: (isLoading || !_hasChanges)
                          ? null
                          : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: AppColors.textDisabled,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Save Changes',
                                  style: AppTextStyles.buttonSmall.copyWith(
                                    color: (isLoading || !_hasChanges)
                                        ? AppColors.textDisabled
                                        : AppColors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.save_rounded,
                                  color: (isLoading || !_hasChanges)
                                      ? AppColors.textDisabled
                                      : AppColors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.error500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.grey100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 12,
                  color: AppColors.textDisabled,
                ),
                const SizedBox(width: 4),
                Text(
                  'Fixed',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textDisabled,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
