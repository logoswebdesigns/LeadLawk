// Base component for all UI components.
// Pattern: Template Method Pattern - defines component structure.
// Single Responsibility: Common component behavior.

import 'package:flutter/material.dart';

/// Base class for all components
abstract class BaseComponent extends StatelessWidget {
  final Key? componentKey;
  final String? semanticLabel;
  final bool enabled;
  
  const BaseComponent({
    super.key,
    this.componentKey,
    this.semanticLabel,
    this.enabled = true,
  });
  
  /// Build the component's main widget
  Widget buildComponent(BuildContext context);
  
  /// Wrap component with common features
  Widget wrapComponent(BuildContext context, Widget child) {
    Widget result = child;
    
    // Add semantics if provided
    if (semanticLabel != null) {
      result = Semantics(
        label: semanticLabel,
        child: result,
      );
    }
    
    // Add disabled state
    if (!enabled) {
      result = Opacity(
        opacity: 0.5,
        child: IgnorePointer(
          child: result,
        ),
      );
    }
    
    return result;
  }
  
  @override
  Widget build(BuildContext context) {
    return wrapComponent(
      context,
      buildComponent(context),
    );
  }
}