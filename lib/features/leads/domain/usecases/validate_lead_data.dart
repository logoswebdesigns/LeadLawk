// Validate Lead Data Use Case
// Pattern: Use Case Pattern (Clean Architecture)
// SOLID: Single Responsibility - only validates lead data
library;

import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

class ValidateLeadData {
  /// Validate phone number format
  Either<Failure, String> validatePhone(String phone) {
    // Remove all non-digits
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    
    // Check length (US phone numbers)
    if (cleaned.length == 10) {
      // Format as (XXX) XXX-XXXX
      return Right(
        '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}'
      );
    } else if (cleaned.length == 11 && cleaned.startsWith('1')) {
      // Remove country code and format
      final number = cleaned.substring(1);
      return Right(
        '(${number.substring(0, 3)}) ${number.substring(3, 6)}-${number.substring(6)}'
      );
    }
    
    return const Left(ValidationFailure('Invalid phone number format'));
  }
  
  /// Validate email format
  Either<Failure, String> validateEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    );
    
    if (emailRegex.hasMatch(email.trim())) {
      return Right(email.trim().toLowerCase());
    }
    
    return const Left(ValidationFailure('Invalid email format'));
  }
  
  /// Validate website URL
  Either<Failure, String> validateWebsite(String url) {
    String normalized = url.trim().toLowerCase();
    
    // Add protocol if missing
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    
    // Basic URL validation
    try {
      final uri = Uri.parse(normalized);
      if (uri.host.isNotEmpty) {
        return Right(normalized);
      }
    } catch (_) {
      // Invalid URL
    }
    
    return const Left(ValidationFailure('Invalid website URL'));
  }
  
  /// Validate business name
  Either<Failure, String> validateBusinessName(String name) {
    final trimmed = name.trim();
    
    if (trimmed.isEmpty) {
      return const Left(ValidationFailure('Business name is required'));
    }
    
    if (trimmed.length < 2) {
      return const Left(ValidationFailure('Business name too short'));
    }
    
    if (trimmed.length > 200) {
      return const Left(ValidationFailure('Business name too long'));
    }
    
    // Check for suspicious patterns
    if (RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
      return const Left(ValidationFailure('Business name cannot be only numbers'));
    }
    
    return Right(trimmed);
  }
  
  /// Validate complete lead data
  Either<Failure, Map<String, dynamic>> validateLeadData(Map<String, dynamic> data) {
    final validated = <String, dynamic>{};
    final errors = <String>[];
    
    // Validate business name (required)
    if (data['businessName'] != null) {
      final result = validateBusinessName(data['businessName']);
      result.fold(
        (failure) => errors.add('Business Name: ${failure.message}'),
        (value) => validated['businessName'] = value,
      );
    }
    
    // Validate phone (optional)
    if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
      final result = validatePhone(data['phone']);
      result.fold(
        (failure) => errors.add('Phone: ${failure.message}'),
        (value) => validated['phone'] = value,
      );
    }
    
    // Validate email (optional)
    if (data['email'] != null && data['email'].toString().isNotEmpty) {
      final result = validateEmail(data['email']);
      result.fold(
        (failure) => errors.add('Email: ${failure.message}'),
        (value) => validated['email'] = value,
      );
    }
    
    // Validate website (optional)
    if (data['websiteUrl'] != null && data['websiteUrl'].toString().isNotEmpty) {
      final result = validateWebsite(data['websiteUrl']);
      result.fold(
        (failure) => errors.add('Website: ${failure.message}'),
        (value) => validated['websiteUrl'] = value,
      );
    }
    
    // Copy other fields as-is
    for (final key in data.keys) {
      if (!validated.containsKey(key)) {
        validated[key] = data[key];
      }
    }
    
    if (errors.isNotEmpty) {
      return Left(ValidationFailure(errors.join(', ')));
    }
    
    return Right(validated);
  }
}