// Reusable loading component with animations.
// Pattern: State Pattern - different loading states.
// Single Responsibility: Loading indicator rendering.

import 'package:flutter/material.dart';
import '../base/base_component.dart';

enum LoadingSize { small, medium, large }
enum LoadingVariant { circular, linear, dots, skeleton }

class AppLoading extends BaseComponent {
  final LoadingVariant variant;
  final LoadingSize size;
  final String? message;
  final Color? color;
  
  const AppLoading({
    super.key,
    this.variant = LoadingVariant.circular,
    this.size = LoadingSize.medium,
    this.message,
    this.color,
    super.semanticLabel,
  });
  
  @override
  Widget buildComponent(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    
    Widget loader = _buildLoader(effectiveColor);
    
    if (message != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          loader,
          const SizedBox(height: 16),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    
    return loader;
  }
  
  Widget _buildLoader(Color color) {
    switch (variant) {
      case LoadingVariant.circular:
        return SizedBox(
          width: _getSize(),
          height: _getSize(),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(color),
            strokeWidth: _getStrokeWidth(),
          ),
        );
        
      case LoadingVariant.linear:
        return SizedBox(
          width: _getSize() * 3,
          child: LinearProgressIndicator(
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: _getStrokeWidth(),
          ),
        );
        
      case LoadingVariant.dots:
        return _buildDotLoader(color);
        
      case LoadingVariant.skeleton:
        return _buildSkeletonLoader();
    }
  }
  
  Widget _buildDotLoader(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 600 + (index * 200)),
          builder: (context, value, child) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 4),
              width: _getSize() / 3,
              height: _getSize() / 3,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3 + (value * 0.7)),
                shape: BoxShape.circle,
              ),
            );
          },
          onEnd: () {
            // Loop animation
          },
        );
      }),
    );
  }
  
  Widget _buildSkeletonLoader() {
    return Container(
      width: _getSize() * 5,
      height: _getSize(),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade300,
            Colors.grey.shade100,
            Colors.grey.shade300,
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: const Alignment(-1.0, 0.0),
          end: const Alignment(1.0, 0.0),
        ),
      ),
    );
  }
  
  double _getSize() {
    switch (size) {
      case LoadingSize.small:
        return 16;
      case LoadingSize.medium:
        return 32;
      case LoadingSize.large:
        return 48;
    }
  }
  
  double _getStrokeWidth() {
    switch (size) {
      case LoadingSize.small:
        return 2;
      case LoadingSize.medium:
        return 3;
      case LoadingSize.large:
        return 4;
    }
  }
}

/// Full screen loading overlay
class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  
  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: AppLoading(
                    message: message,
                    size: LoadingSize.large,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}