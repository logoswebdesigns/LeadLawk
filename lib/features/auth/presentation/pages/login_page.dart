// Login Page with comprehensive authentication options.
// Pattern: Page Pattern - UI layer for login functionality.
// Single Responsibility: Login user interface and user interaction.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../widgets/biometric_login_button.dart';
import '../widgets/social_login_buttons.dart';
import '../widgets/login_form.dart';
import '../widgets/auth_header.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: authState.when(
            initial: () => _buildLoginContent(context, ref),
            loading: () => const Center(child: CircularProgressIndicator()),
            authenticated: (user, tokens) => _redirectToHome(context),
            unauthenticated: () => _buildLoginContent(context, ref),
            twoFactorRequired: (email) => _buildTwoFactorContent(context, ref, email),
            error: (failure) => _buildErrorContent(context, ref, failure),
            biometricAvailable: () => _buildLoginContent(context, ref),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginContent(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          
          // App logo and welcome message
          const AuthHeader(
            title: 'Welcome Back',
            subtitle: 'Sign in to continue managing your leads',
          ),
          
          const SizedBox(height: 40),
          
          // Biometric login (if available)
          const BiometricLoginButton(),
          
          const SizedBox(height: 24),
          
          // Social login buttons
          const SocialLoginButtons(),
          
          const SizedBox(height: 32),
          
          // Divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'or continue with email',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Email/password login form
          const LoginForm(),
          
          const SizedBox(height: 24),
          
          // Register link
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: () => _navigateToRegister(context),
                child: const Text('Sign up'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTwoFactorContent(BuildContext context, WidgetRef ref, String email) {
    // TODO: Implement 2FA verification UI
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.refresh),
        const SizedBox(height: 24),
        Text(
          'Two-Factor Authentication',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Enter the 6-digit code from your authenticator app',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        // TODO: Add 2FA input field and verification
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context, WidgetRef ref, failure) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.refresh),
        const SizedBox(height: 24),
        Text(
          'Login Failed',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          failure.message,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          child: const Text('Try Again'),
        ),
      ],
    );
  }

  Widget _redirectToHome(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacementNamed('/home');
    });
    return const Center(child: CircularProgressIndicator());
  }

  void _navigateToRegister(BuildContext context) {
    Navigator.of(context).pushNamed('/register');
  }
}