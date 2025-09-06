// Reusable button component with variants.
// Pattern: Strategy Pattern - different button styles.
// Single Responsibility: Button rendering and interaction.

import 'package:flutter/material.dart';
import '../base/base_component.dart';

enum ButtonVariant { primary, secondary, tertiary, danger, ghost }
enum ButtonSize { small, medium, large }

class AppButton extends BaseComponent {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final ButtonSize size;
  final IconData? icon;
  final bool loading;
  final double? width;
  
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.loading = false,
    this.width,
    super.semanticLabel,
    super.enabled = true,
  });
  
  @override
  Widget buildComponent(BuildContext context) {
    final theme = Theme.of(context);
    final style = _getButtonStyle(theme);
    final child = _buildContent(theme);
    
    if (width != null) {
      return SizedBox(
        width: width,
        child: _buildButton(style, child),
      );
    }
    
    return _buildButton(style, child);
  }
  
  Widget _buildButton(ButtonStyle style, Widget child) {
    if (icon != null && label.isNotEmpty) {
      return ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        style: style,
        icon: Icon(icon, size: _getIconSize()),
        label: child,
      );
    }
    
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: child,
    );
  }
  
  Widget _buildContent(ThemeData theme) {
    if (loading) {
      return SizedBox(
        height: _getContentHeight(),
        width: _getContentHeight(),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.white,
          ),
        ),
      );
    }
    
    return Text(
      label,
      style: TextStyle(fontSize: _getFontSize()),
    );
  }
  
  ButtonStyle _getButtonStyle(ThemeData theme) {
    final padding = _getPadding();
    
    switch (variant) {
      case ButtonVariant.primary:
        return ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          padding: padding,
        );
      case ButtonVariant.secondary:
        return ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: theme.colorScheme.onSecondary,
          padding: padding,
        );
      case ButtonVariant.tertiary:
        return ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.tertiary,
          foregroundColor: theme.colorScheme.onTertiary,
          padding: padding,
        );
      case ButtonVariant.danger:
        return ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
          padding: padding,
        );
      case ButtonVariant.ghost:
        return ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: theme.colorScheme.primary,
          elevation: 0,
          padding: padding,
        );
    }
  }
  
  EdgeInsets _getPadding() {
    switch (size) {
      case ButtonSize.small:
        return EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case ButtonSize.medium:
        return EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case ButtonSize.large:
        return EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }
  
  double _getFontSize() {
    switch (size) {
      case ButtonSize.small:
        return 12;
      case ButtonSize.medium:
        return 14;
      case ButtonSize.large:
        return 16;
    }
  }
  
  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 20;
      case ButtonSize.large:
        return 24;
    }
  }
  
  double _getContentHeight() {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 20;
      case ButtonSize.large:
        return 24;
    }
  }
  
  Color _getLoadingColor(ThemeData theme) {
    switch (variant) {
      case ButtonVariant.primary:
        return theme.colorScheme.onPrimary;
      case ButtonVariant.secondary:
        return theme.colorScheme.onSecondary;
      case ButtonVariant.tertiary:
        return theme.colorScheme.onTertiary;
      case ButtonVariant.danger:
        return theme.colorScheme.onError;
      case ButtonVariant.ghost:
        return theme.colorScheme.primary;
    }
  }
}