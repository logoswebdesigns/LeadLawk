import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class EmptyState extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryButtonPressed;
  final IconData? secondaryButtonIcon;
  
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.buttonText,
    this.onButtonPressed,
    this.secondaryButtonText,
    this.onSecondaryButtonPressed,
    this.secondaryButtonIcon,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _bounceAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -_bounceAnimation.value),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.lightGray,
                          Colors.white,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.mediumGray.withValues(alpha: 0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: 50,
                      color: AppTheme.mediumGray,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              widget.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.buttonText != null && widget.onButtonPressed != null ||
                widget.secondaryButtonText != null && widget.onSecondaryButtonPressed != null) ...[
              const SizedBox(height: 24),
              Column(
                children: [
                  // Primary button (if provided)
                  if (widget.buttonText != null && widget.onButtonPressed != null) ...[
                    ElevatedButton.icon(
                      onPressed: widget.onButtonPressed,
                      icon: const Icon(Icons.add),
                      label: Text(widget.buttonText!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryIndigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                      ),
                    ),
                    if (widget.secondaryButtonText != null && widget.onSecondaryButtonPressed != null)
                      const SizedBox(height: 12),
                  ],
                  // Secondary button (if provided) - below primary button
                  if (widget.secondaryButtonText != null && widget.onSecondaryButtonPressed != null)
                    OutlinedButton.icon(
                      onPressed: widget.onSecondaryButtonPressed,
                      icon: Icon(widget.secondaryButtonIcon ?? Icons.refresh),
                      label: Text(widget.secondaryButtonText!),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGold,
                        side: const BorderSide(color: AppTheme.primaryGold),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }
}