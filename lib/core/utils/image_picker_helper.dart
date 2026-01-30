import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../themes/app_colors.dart';
import '../constants/app_constants.dart';

/// Result class for image picking with validation
class ImagePickResult {
  final File? file;
  final String? error;

  ImagePickResult({this.file, this.error});

  bool get isSuccess => file != null && error == null;
  bool get hasError => error != null;
}

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Pick image from camera or gallery with optional cropping
  /// Returns ImagePickResult with file or error message
  static Future<ImagePickResult> pickAndCropImageWithValidation({
    required BuildContext context,
    required ImageSource source,
    bool cropCircle = true,
    int? maxFileSizeMB,
  }) async {
    try {
      // Pick image without compression first to check original size
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
      );

      if (pickedFile == null) {
        return ImagePickResult(); // User cancelled
      }

      // Validate file size before processing
      final file = File(pickedFile.path);
      final fileSize = await file.length();
      final maxSize = maxFileSizeMB ?? AppConstants.maxProfilePictureSizeMB;
      final maxSizeBytes = maxSize * 1024 * 1024;

      if (fileSize > maxSizeBytes) {
        final fileSizeMB = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        return ImagePickResult(
          error: 'File size ($fileSizeMB MB) exceeds maximum limit (${maxSize}MB)',
        );
      }

      // Validate file type
      final extension = pickedFile.path.split('.').last.toLowerCase();
      final allowedTypes = ['jpg', 'jpeg', 'png'];
      if (!allowedTypes.contains(extension)) {
        return ImagePickResult(
          error: 'Only JPG, JPEG, and PNG files are allowed',
        );
      }

      // Check if context is still valid before cropping
      if (!context.mounted) {
        return ImagePickResult();
      }

      // Crop the image
      final croppedFile = await _cropImage(
        context: context,
        sourcePath: pickedFile.path,
        cropCircle: cropCircle,
      );

      if (croppedFile == null) {
        return ImagePickResult(); // User cancelled cropping
      }

      return ImagePickResult(file: croppedFile);
    } catch (e) {
      debugPrint('Error picking image: $e');
      return ImagePickResult(error: 'Failed to pick image');
    }
  }

  /// Pick image from camera or gallery with optional cropping (legacy method)
  static Future<File?> pickAndCropImage({
    required BuildContext context,
    required ImageSource source,
    bool cropCircle = true,
    int maxWidth = 512,
    int maxHeight = 512,
    int imageQuality = 80,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: imageQuality,
      );

      if (pickedFile == null) return null;

      // Check if context is still valid before cropping
      if (!context.mounted) return null;

      // Crop the image
      final croppedFile = await _cropImage(
        context: context,
        sourcePath: pickedFile.path,
        cropCircle: cropCircle,
      );

      return croppedFile;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Crop image using image_cropper
  static Future<File?> _cropImage({
    required BuildContext context,
    required String sourcePath,
    bool cropCircle = true,
  }) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primary500,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.primary500,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
            cropStyle: cropCircle ? CropStyle.circle : CropStyle.rectangle,
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: cropCircle ? CropStyle.circle : CropStyle.rectangle,
          ),
        ],
      );

      if (croppedFile != null) {
        return File(croppedFile.path);
      }
      return null;
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return null;
    }
  }

  /// Show bottom sheet to choose image source
  static Future<ImageSource?> showImageSourceSheet(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_camera,
                    color: AppColors.primary500,
                  ),
                ),
                title: const Text('Take Photo'),
                subtitle: const Text('Use camera to take a new photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library,
                    color: AppColors.primary500,
                  ),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select an existing photo'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
