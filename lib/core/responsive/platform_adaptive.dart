// Platform-specific adaptations.
// Pattern: Adapter Pattern - adapts UI to platform conventions.
// Single Responsibility: Platform-specific UI adaptations.

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Platform-aware widget that shows different implementations
class PlatformAdaptive extends StatelessWidget {
  final Widget Function(BuildContext context) androidBuilder;
  final Widget Function(BuildContext context) iosBuilder;
  final Widget Function(BuildContext context)? webBuilder;
  final Widget Function(BuildContext context)? desktopBuilder;
  
  const PlatformAdaptive({
    super.key,
    required this.androidBuilder,
    required this.iosBuilder,
    this.webBuilder,
    this.desktopBuilder,
  });
  
  @override
  Widget build(BuildContext context) {
    if (kIsWeb && webBuilder != null) {
      return webBuilder!(context);
    }
    
    switch (Theme.of(context).platform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return androidBuilder(context);
        
      case TargetPlatform.iOS:
        return iosBuilder(context);
        
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        if (desktopBuilder != null) {
          return desktopBuilder!(context);
        }
        return androidBuilder(context);
    }
  }
}

/// Adaptive button that uses platform conventions
class AdaptiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  final Widget? icon;
  
  const AdaptiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.filled = false,
    this.icon,
  });
  
  @override
  Widget build(BuildContext context) {
    return PlatformAdaptive(
      androidBuilder: (context) => _buildMaterialButton(context),
      iosBuilder: (context) => _buildCupertinoButton(context),
    );
  }
  
  Widget _buildMaterialButton(BuildContext context) {
    if (icon != null) {
      if (filled) {
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: icon!,
          label: Text(label),
        );
      } else {
        return TextButton.icon(
          onPressed: onPressed,
          icon: icon!,
          label: Text(label),
        );
      }
    }
    
    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      );
    } else {
      return TextButton(
        onPressed: onPressed,
        child: Text(label),
      );
    }
  }
  
  Widget _buildCupertinoButton(BuildContext context) {
    if (filled) {
      return CupertinoButton.filled(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      );
    } else {
      return CupertinoButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              icon!,
              const SizedBox(width: 8),
            ],
            Text(label),
          ],
        ),
      );
    }
  }
}

/// Adaptive dialog that uses platform conventions
class AdaptiveDialog extends StatelessWidget {
  final String title;
  final String? content;
  final List<AdaptiveDialogAction> actions;
  
  const AdaptiveDialog({
    super.key,
    required this.title,
    this.content,
    required this.actions,
  });
  
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? content,
    required List<AdaptiveDialogAction> actions,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => AdaptiveDialog(
        title: title,
        content: content,
        actions: actions,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return PlatformAdaptive(
      androidBuilder: (context) => _buildMaterialDialog(context),
      iosBuilder: (context) => _buildCupertinoDialog(context),
    );
  }
  
  Widget _buildMaterialDialog(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: content != null ? Text(content!) : null,
      actions: actions.map((action) {
        return TextButton(
          onPressed: action.onPressed,
          child: Text(
            action.label,
            style: action.isDestructive
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : null,
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildCupertinoDialog(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(title),
      content: content != null ? Text(content!) : null,
      actions: actions.map((action) {
        return CupertinoDialogAction(
          onPressed: action.onPressed,
          isDestructiveAction: action.isDestructive,
          isDefaultAction: action.isDefault,
          child: Text(action.label),
        );
      }).toList(),
    );
  }
}

/// Dialog action for adaptive dialogs
class AdaptiveDialogAction {
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;
  final bool isDefault;
  
  const AdaptiveDialogAction({
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
    this.isDefault = false,
  });
}

/// Adaptive loading indicator
class AdaptiveLoadingIndicator extends StatelessWidget {
  final double? size;
  final Color? color;
  
  const AdaptiveLoadingIndicator({
    super.key,
    this.size,
    this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return PlatformAdaptive(
      androidBuilder: (context) => SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          valueColor: color != null 
            ? AlwaysStoppedAnimation(color!) 
            : null,
        ),
      ),
      iosBuilder: (context) => CupertinoActivityIndicator(
        radius: (size ?? 20) / 2,
        color: color,
      ),
    );
  }
}

/// Adaptive switch
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  
  const AdaptiveSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return PlatformAdaptive(
      androidBuilder: (context) => Switch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
      ),
      iosBuilder: (context) => CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeColor: activeColor,
      ),
    );
  }
}

/// Adaptive slider
class AdaptiveSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  
  const AdaptiveSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
  });
  
  @override
  Widget build(BuildContext context) {
    return PlatformAdaptive(
      androidBuilder: (context) => Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
      ),
      iosBuilder: (context) => CupertinoSlider(
        value: value,
        onChanged: onChanged ?? (_) {},
        min: min,
        max: max,
        divisions: divisions,
      ),
    );
  }
}