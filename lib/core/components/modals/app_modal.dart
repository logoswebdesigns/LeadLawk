// Reusable modal component system.
// Pattern: Factory Pattern - different modal types.
// Single Responsibility: Modal display and management.

import 'package:flutter/material.dart';

enum ModalSize { small, medium, large, fullscreen }

class AppModal {
  /// Show a basic modal
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    ModalSize size = ModalSize.medium,
    bool dismissible = true,
    bool enableDrag = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: dismissible,
      enableDrag: enableDrag,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ModalContainer(
        title: title,
        size: size,
        child: child,
      ),
    );
  }
  
  /// Show a confirmation dialog
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: isDestructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
  
  /// Show an alert dialog
  static Future<void> alert({
    required BuildContext context,
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }
  
  /// Show a custom dialog
  static Future<T?> dialog<T>({
    required BuildContext context,
    required Widget child,
    bool dismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) => child,
    );
  }
}

class _ModalContainer extends StatelessWidget {
  final String? title;
  final ModalSize size;
  final Widget child;
  
  const _ModalContainer({
    required this.child,
    this.title,
    this.size = ModalSize.medium,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = _getHeight(context);
    
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          if (title != null) ...[
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
  
  double _getHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    switch (size) {
      case ModalSize.small:
        return screenHeight * 0.3;
      case ModalSize.medium:
        return screenHeight * 0.5;
      case ModalSize.large:
        return screenHeight * 0.75;
      case ModalSize.fullscreen:
        return screenHeight * 0.9;
    }
  }
}