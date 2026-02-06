import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
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
import '../../../shared/widgets/form_card.dart';
import '../../../shared/widgets/section_label.dart';
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
      await dio.download(imageUrl, tempPath);
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

  Future<void> _saveProfile() async {
    setState(() => _hasAttemptedSubmit = true);
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
        ToastHelper.showSuccess(
          context,
          'Success',
          description: 'Profile updated successfully',
        );
        Navigator.pop(context);
      } else {
        ToastHelper.showError(
          context,
          'Update Failed',
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary600, AppColors.primary500],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom AppBar
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
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Avatar Section
            _buildAvatarSection(user, isLoading),
            const SizedBox(height: 24),
            // Curved bottom
            Container(
              height: 24,
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarSection(user, bool isLoading) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white.withAlpha(76), width: 3),
          ),
          child: ProfileAvatar(
            imageUrl: user?.profilePicture != null
                ? '${ApiConfig.baseUrl}${user!.profilePicture}'
                : null,
            name: user?.fullName ?? 'User',
            size: 110,
            showEditIcon: true,
            onTap: isLoading ? null : _pickImage,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap avatar to change photo',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.white.withAlpha(204),
          ),
        ),
        if (user?.profilePicture != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: isLoading ? null : _downloadProfilePicture,
            icon: Icon(
              Icons.download_rounded,
              size: 18,
              color: AppColors.white.withAlpha(230),
            ),
            label: Text(
              'Download Photo',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.white.withAlpha(230),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

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
            color: AppColors.white.withAlpha(51),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.white, size: 22),
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
          FormCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _buildReadOnlyField(
                  label: 'Email',
                  value: user?.email ?? '',
                  icon: Icons.email_outlined,
                  isFirst: true,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _buildReadOnlyField(
                  label: 'Username',
                  value: '@${user?.username ?? ''}',
                  icon: Icons.alternate_email,
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Personal Info (Editable)
          const SectionLabel(label: 'Personal Information'),
          const SizedBox(height: 12),
          FormCard(
            child: Form(
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
                    prefixIcon: const Icon(Icons.person_outline),
                    enabled: !isLoading,
                    validator: Validators.profileFirstName,
                  ),
                  const SizedBox(height: 20),
                  _buildFieldLabel('Last Name'),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _lastNameController,
                    hint: 'Enter your last name',
                    prefixIcon: const Icon(Icons.person_outline),
                    enabled: !isLoading,
                    validator: Validators.profileLastName,
                  ),
                  const SizedBox(height: 20),
                  _buildFieldLabel('Phone Number'),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _phoneController,
                    hint: 'Enter your phone number',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    keyboardType: TextInputType.phone,
                    enabled: !isLoading,
                    maxLength: AppConstants.maxPhoneNumberLength,
                    validator: Validators.profilePhoneNumber,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : _discardChanges,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Discard',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: (isLoading || !_hasChanges) ? null : _saveProfile,
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
                  child: Text(
                    'Save Changes',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: (isLoading || !_hasChanges)
                          ? AppColors.textDisabled
                          : AppColors.white,
                      fontWeight: FontWeight.w600,
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
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary500, size: 20),
          ),
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
