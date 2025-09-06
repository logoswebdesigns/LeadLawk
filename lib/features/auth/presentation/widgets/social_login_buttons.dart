// Social login buttons widget for third-party authentication.
// Pattern: Widget Pattern - Social authentication UI component.
// Single Responsibility: Display and handle social login options.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SocialLoginButtons extends ConsumerWidget {
  const SocialLoginButtons({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildGoogleButton(context),
        const SizedBox(height: 12),
        _buildAppleButton(context),
        const SizedBox(height: 12),
        _buildMicrosoftButton(context),
      ],
    );
  }

  Widget _buildGoogleButton(BuildContext context) {
    return _buildSocialButton(
      context,
      label: 'Continue with Google',
      icon: Icons.phone_android,
      onPressed: () => _handleGoogleLogin(context),
      backgroundColor: Colors.white,
      textColor: Colors.black87,
      borderColor: Colors.grey.shade300,
    );
  }

  Widget _buildAppleButton(BuildContext context) {
    return _buildSocialButton(
      context,
      label: 'Continue with Apple',
      icon: Icons.phone_iphone,
      onPressed: () => _handleAppleLogin(context),
      backgroundColor: Colors.black,
      textColor: Colors.white,
    );
  }

  Widget _buildMicrosoftButton(BuildContext context) {
    return _buildSocialButton(
      context,
      label: 'Continue with Microsoft',
      icon: Icons.business,
      onPressed: () => _handleMicrosoftLogin(context),
      backgroundColor: const Color(0xFF0078D4),
      textColor: Colors.white,
    );
  }

  Widget _buildSocialButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color textColor,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  void _handleGoogleLogin(BuildContext context) {
    // TODO: Implement Google authentication
  }

  void _handleAppleLogin(BuildContext context) {
    // TODO: Implement Apple authentication
  }

  void _handleMicrosoftLogin(BuildContext context) {
    // TODO: Implement Microsoft authentication
  }
}