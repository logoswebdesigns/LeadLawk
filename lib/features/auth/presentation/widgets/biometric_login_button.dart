// Biometric authentication button widget.
// Pattern: Widget Pattern - Conditional biometric login UI component.
// Single Responsibility: Handle biometric authentication UI.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class BiometricLoginButton extends ConsumerWidget {
  const BiometricLoginButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    
    return authState.maybeWhen(
      biometricAvailable: () => _buildBiometricButton(context, ref),
      orElse: () => SizedBox.shrink(),
    );
  }

  Widget _buildBiometricButton(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextButton.icon(
        onPressed: () => _handleBiometricLogin(ref),
        icon: Icon(Icons.fingerprint),
        label: const Text(
          'Use Biometric Authentication',
          style: TextStyle(fontSize: 16),
        ),
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  void _handleBiometricLogin(WidgetRef ref) {
    // TODO: Implement biometric authentication
    ref.read(authNotifierProvider.notifier).loginWithBiometric();
  }
}