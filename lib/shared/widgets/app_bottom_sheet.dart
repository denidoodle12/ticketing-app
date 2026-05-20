import 'package:flutter/material.dart';
import '../../core/themes/app_colors.dart';

/// Standardised bottom sheet helper.
///
/// Every `showModalBottomSheet` in the app was repeating the same setup —
/// rounded top corners, scroll-controlled, white background, anti-aliased
/// clipping. This helper bakes that recipe in so consumers focus on the
/// content widget.
///
/// Use [isFullHeight] when the sheet content is itself a `DraggableScrollableSheet`
/// or needs to occupy the entire available height (e.g. the article picker
/// or large filter sheets).
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isFullHeight = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  double topRadius = 24,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor ?? AppColors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
    ),
    constraints: isFullHeight
        ? BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.95,
          )
        : null,
    builder: builder,
  );
}
