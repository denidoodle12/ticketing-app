import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/themes/text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/toast_helper.dart';
import '../../../providers/ticket_provider.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _selectedCategoryId;
  String _selectedPriority = 'low';
  File? _attachmentFile;
  String? _attachmentFileName;

  final List<Map<String, dynamic>> _priorityOptions = [
    {'value': 'low', 'label': 'Low', 'color': AppColors.success500},
    {'value': 'medium', 'label': 'Medium', 'color': AppColors.warning500},
    {'value': 'high', 'label': 'High', 'color': AppColors.priorityHigh},
    {'value': 'critical', 'label': 'Critical', 'color': AppColors.error500},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TicketProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.primaryDark),
                title: Text(
                  'Choose from Gallery',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (pickedFile != null) {
                    await _processPickedImageFile(pickedFile);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primaryDark),
                title: Text(
                  'Take a Photo',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (pickedFile != null) {
                    await _processPickedImageFile(pickedFile);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file, color: AppColors.primaryDark),
                title: Text(
                  'Upload Files',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  'pdf, doc, docx, txt, zip, gif',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickFile();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      await _processPickedFile(file, fileName);
    }
  }

  Future<void> _processPickedImageFile(XFile pickedFile) async {
    final file = File(pickedFile.path);
    await _processPickedFile(file, pickedFile.name);
  }

  Future<void> _processPickedFile(File file, String fileName) async {
    // Validate file type
    final typeError = Validators.fileType(fileName);
    if (typeError != null) {
      if (!mounted) return;
      ToastHelper.showError(
        context,
        'Attachment Error',
        description: typeError,
      );
      return;
    }

    // Validate file size (max 5MB)
    final fileSize = await file.length();
    final sizeError = Validators.fileSize(fileSize, maxSizeInMB: 5);

    if (sizeError != null) {
      if (!mounted) return;
      ToastHelper.showError(
        context,
        'Attachment Error',
        description: sizeError,
      );
      return;
    }

    setState(() {
      _attachmentFile = file;
      _attachmentFileName = fileName;
    });
  }

  void _removeAttachment() {
    setState(() {
      _attachmentFile = null;
      _attachmentFileName = null;
    });
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ToastHelper.showError(context, 'Please select a category');
      return;
    }

    // Validate file size before submit (double check)
    if (_attachmentFile != null) {
      final fileSize = await _attachmentFile!.length();
      final validationError = Validators.fileSize(fileSize, maxSizeInMB: 5);
      if (!mounted) return;
      if (validationError != null) {
        ToastHelper.showError(
          context,
          'Attachment Error',
          description: validationError,
        );
        return;
      }
    }

    if (!mounted) return;
    final ticketProvider = context.read<TicketProvider>();
    final ticket = await ticketProvider.createTicket(
      subject: _subjectController.text.trim(),
      description: _descriptionController.text.trim(),
      categoryId: _selectedCategoryId!,
      priority: _selectedPriority,
      attachmentPath: _attachmentFile?.path,
    );

    if (!mounted) return;

    if (ticket != null) {
      ToastHelper.showSuccess(
        context,
        'Success',
        description: 'Ticket created successfully',
      );
      Navigator.pop(context, ticket);
    } else {
      ToastHelper.showError(
        context,
        'Error',
        description: ticketProvider.errorMessage ?? 'Failed to create ticket',
      );
    }
  }

  /// Check if form has any data
  bool _hasFormData() {
    return _subjectController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _selectedCategoryId != null ||
        _selectedPriority != 'low' ||
        _attachmentFile != null;
  }

  /// Handle back action with confirmation if form has data
  Future<void> _handleBackAction() async {
    if (_hasFormData()) {
      final shouldDiscard = await showDialog<bool>(
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
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep Editing',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
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

      if (shouldDiscard == true && mounted) {
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackAction();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: _buildAppBar(),
        body: _buildBody(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        onPressed: _handleBackAction,
        icon: const Icon(
          Icons.chevron_left,
          color: AppColors.textPrimary,
          size: 28,
        ),
      ),
      title: Text(
        'Create Ticket',
        style: AppTextStyles.h5.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.grey200, height: 1),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<TicketProvider>(
      builder: (context, ticketProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject field
                _buildSectionLabel('Subject'),
                const SizedBox(height: 8),
                _buildSubjectField(),
                const SizedBox(height: 20),

                // Category dropdown
                _buildSectionLabel('Category'),
                const SizedBox(height: 8),
                _buildCategoryDropdown(ticketProvider),
                const SizedBox(height: 20),

                // Priority chips
                _buildSectionLabel('Priority'),
                const SizedBox(height: 8),
                _buildPriorityChips(),
                const SizedBox(height: 20),

                // Description field
                _buildSectionLabel('Describe your case'),
                const SizedBox(height: 8),
                _buildDescriptionField(),
                const SizedBox(height: 20),

                // Attachment
                _buildSectionLabel('Attachment (Optional)'),
                const SizedBox(height: 8),
                _buildAttachmentPicker(),
                const SizedBox(height: 32),

                // Bottom buttons
                _buildBottomButtons(ticketProvider),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSubjectField() {
    return TextFormField(
      controller: _subjectController,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Enter ticket subject',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textDisabled,
        ),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error500),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      validator: Validators.ticketSubject,
    );
  }

  Widget _buildCategoryDropdown(TicketProvider ticketProvider) {
    if (ticketProvider.isCategoriesLoading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Find selected category name
    String? selectedCategoryName;
    if (_selectedCategoryId != null) {
      final selectedCategory = ticketProvider.categories
          .where((c) => c.id == _selectedCategoryId)
          .firstOrNull;
      selectedCategoryName = selectedCategory?.name;
    }

    return GestureDetector(
      onTap: () => _showCategoryBottomSheet(ticketProvider),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Prefix icon
            Icon(
              Icons.grid_view_rounded,
              color: AppColors.primaryDark,
              size: 20,
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Text(
                selectedCategoryName ?? 'Select Category',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selectedCategoryName != null
                      ? AppColors.textPrimary
                      : AppColors.textDisabled,
                ),
              ),
            ),
            // Suffix icons
            if (selectedCategoryName != null) ...[
              const Icon(
                Icons.check_circle,
                color: AppColors.success500,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.primaryDark,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryBottomSheet(TicketProvider ticketProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Category',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1),
            // Category list
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ticketProvider.categories.length,
                itemBuilder: (context, index) {
                  final category = ticketProvider.categories[index];
                  final isSelected = _selectedCategoryId == category.id;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = category.id;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              category.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.success500,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            // Safe area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChips() {
    return Row(
      children: _priorityOptions.map((priority) {
        final isSelected = _selectedPriority == priority['value'];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedPriority = priority['value'];
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryDark : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primaryDark : AppColors.border,
                  width: 1,
                ),
              ),
              child: Text(
                priority['label'],
                style: AppTextStyles.bodySmall.copyWith(
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 5,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Please provide as much details as possible',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textDisabled,
        ),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryDark, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error500),
        ),
        contentPadding: const EdgeInsets.all(16),
      ),
      validator: Validators.ticketDescription,
    );
  }

  Widget _buildAttachmentPicker() {
    if (_attachmentFile != null) {
      final isImage = Validators.isImageFile(_attachmentFileName);

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.grey50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // File preview
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isImage
                  ? Image.file(
                      _attachmentFile!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getFileIcon(_attachmentFileName),
                        size: 28,
                        color: AppColors.primaryDark,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _attachmentFileName ?? 'Attachment',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to change',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _removeAttachment,
              icon: const Icon(
                Icons.close,
                color: AppColors.error500,
                size: 20,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pickAttachment,
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: AppColors.grey300,
          strokeWidth: 1.5,
          dashWidth: 6,
          dashSpace: 4,
          borderRadius: 12,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 24,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tap to upload file',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Max 5MB file upload',
                style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String? fileName) {
    if (fileName == null) return Icons.insert_drive_file;

    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
        return Icons.folder_zip;
      case 'gif':
        return Icons.gif;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildBottomButtons(TicketProvider ticketProvider) {
    return Row(
      children: [
        // Cancel button
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: _handleBackAction,
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
        // Submit button
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: ticketProvider.isCreatingTicket ? null : _submitTicket,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.grey300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: ticketProvider.isCreatingTicket
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
                          'Submit Ticket',
                          style: AppTextStyles.buttonSmall.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_circle_up,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for dashed border
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

    final dashPath = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}
