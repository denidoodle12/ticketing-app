import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class ToastHelper {
  /// Show success toast
  static void showSuccess(
    BuildContext context,
    String title, {
    String? description,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.minimal,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      description: description != null
          ? Text(
              description,
              style: const TextStyle(
                fontSize: 12,
              ),
            )
          : null,
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.topCenter,
      animationDuration: const Duration(milliseconds: 700),
      showProgressBar: false,
      closeOnClick: true,
      pauseOnHover: true,
    );
  }

  /// Show error toast
  static void showError(
    BuildContext context,
    String title, {
    String? description,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.minimal,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      description: description != null
          ? Text(
              description,
              style: const TextStyle(
                fontSize: 12,
              ),
            )
          : null,
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.topCenter,
      animationDuration: const Duration(milliseconds: 700),
      showProgressBar: false,
      closeOnClick: true,
      pauseOnHover: true,
    );
  }

  /// Show info toast
  static void showInfo(
    BuildContext context,
    String title, {
    String? description,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.minimal,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      description: description != null
          ? Text(
              description,
              style: const TextStyle(
                fontSize: 12,
              ),
            )
          : null,
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.topCenter,
      animationDuration: const Duration(milliseconds: 700),
      showProgressBar: false,
      closeOnClick: true,
      pauseOnHover: true,
    );
  }

  /// Show warning toast
  static void showWarning(
    BuildContext context,
    String title, {
    String? description,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.warning,
      style: ToastificationStyle.minimal,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      description: description != null
          ? Text(
              description,
              style: const TextStyle(
                fontSize: 12,
              ),
            )
          : null,
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.topCenter,
      animationDuration: const Duration(milliseconds: 700),
      showProgressBar: false,
      closeOnClick: true,
      pauseOnHover: true,
    );
  }
}
