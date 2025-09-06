// Authentication User Entity.
// Pattern: Entity Pattern - core business object for authenticated user.
// Single Responsibility: User authentication data representation.
// File size: <100 lines as per CLAUDE.md requirements.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_user.freezed.dart';
part 'auth_user.g.dart';

@freezed
class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String id,
    required String email,
    required String fullName,
    required bool isActive,
    required bool isAdmin,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(false) bool emailVerified,
    @Default(false) bool twoFactorEnabled,
    String? profileImageUrl,
    String? phoneNumber,
    DateTime? lastLoginAt,
  }) = _AuthUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) => _$AuthUserFromJson(json);
}

enum AuthProvider {
  email,
  google,
  apple,
  microsoft,
  github,
}