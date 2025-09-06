// Social Authentication Data Source.
// Pattern: Data Source Pattern - handles social login providers.
// Single Responsibility: Social authentication integration.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/auth_models.dart';
import '../../domain/entities/auth_failure.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

abstract class SocialAuthDataSource {
  Future<SocialAuthInfo> signInWithGoogle();
  Future<SocialAuthInfo> signInWithApple();
  Future<SocialAuthInfo> signInWithMicrosoft();
  Future<SocialAuthInfo> signInWithGitHub();
  Future<void> signOut();
}

class SocialAuthDataSourceImpl implements SocialAuthDataSource {
  final GoogleSignIn _googleSignIn;

  SocialAuthDataSourceImpl()
    : _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId: kIsWeb 
          ? null 
          : Platform.isIOS 
            ? null 
            : null,
      );

  @override
  Future<SocialAuthInfo> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      
      if (account == null) {
        throw AuthFailure.socialLoginFailed(SocialAuthProvider.google, 'Sign in cancelled');
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      
      return SocialAuthInfo(
        provider: SocialAuthProvider.google,
        providerId: account.id,
        accessToken: auth.accessToken,
        refreshToken: auth.idToken,
        metadata: {
          'email': account.email,
          'display_name': account.displayName,
          'photo_url': account.photoUrl,
        },
      );
    } catch (e) {
      throw AuthFailure.socialLoginFailed(SocialAuthProvider.google);
    }
  }

  @override
  Future<SocialAuthInfo> signInWithApple() async {
    try {
      // Apple Sign-In is only available on iOS, macOS and Web
      if (!Platform.isIOS && !Platform.isMacOS && !kIsWeb) {
        throw AuthFailure.operationNotAllowed('Apple Sign-In not available on this platform');
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: kIsWeb 
          ? WebAuthenticationOptions(
              clientId: 'com.leadlawk.web',
              redirectUri: Uri.parse('https://leadlawk.com/auth/callback'),
            )
          : null,
      );

      return SocialAuthInfo(
        provider: SocialAuthProvider.apple,
        providerId: credential.userIdentifier ?? '',
        accessToken: credential.identityToken,
        metadata: {
          'email': credential.email,
          'given_name': credential.givenName,
          'family_name': credential.familyName,
          'authorization_code': credential.authorizationCode,
        },
      );
    } catch (e) {
      throw AuthFailure.socialLoginFailed(SocialAuthProvider.apple);
    }
  }

  @override
  Future<SocialAuthInfo> signInWithMicrosoft() async {
    try {
      // Microsoft OAuth2 implementation would go here
      // For now, throwing not implemented
      throw AuthFailure.operationNotAllowed('Microsoft Sign-In not yet implemented');
    } catch (e) {
      throw AuthFailure.socialLoginFailed(SocialAuthProvider.microsoft);
    }
  }

  @override
  Future<SocialAuthInfo> signInWithGitHub() async {
    try {
      // GitHub OAuth2 implementation would go here
      // For now, throwing not implemented
      throw AuthFailure.operationNotAllowed('GitHub Sign-In not yet implemented');
    } catch (e) {
      throw AuthFailure.socialLoginFailed(SocialAuthProvider.github);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      // Sign out from other providers as needed
    } catch (e) {
      // Log error but don't throw - sign out should be best effort
    }
  }
}