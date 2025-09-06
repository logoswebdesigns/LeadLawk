import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/domain/usecases/validate_lead_data.dart';

void main() {
  late ValidateLeadData validateLeadData;
  
  setUp(() {
    validateLeadData = ValidateLeadData();
  });
  
  group('Phone Validation', () {
    test('should format valid 10-digit phone number', () {
      final result = validateLeadData.validatePhone('5551234567');
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (phone) {
          expect(phone, equals('(555) 123-4567'));
        },
      );
    });
    
    test('should format valid 11-digit phone with country code', () {
      final result = validateLeadData.validatePhone('15551234567');
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (phone) {
          expect(phone, equals('(555) 123-4567'));
        },
      );
    });
    
    test('should handle phone with formatting characters', () {
      final result = validateLeadData.validatePhone('(555) 123-4567');
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (phone) {
          expect(phone, equals('(555) 123-4567'));
        },
      );
    });
    
    test('should reject invalid phone number', () {
      final result = validateLeadData.validatePhone('123');
      
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure.message, contains('Invalid phone number'));
        },
        (_) => fail('Should fail'),
      );
    });
  });
  
  group('Email Validation', () {
    test('should validate correct email format', () {
      final result = validateLeadData.validateEmail('test@example.com');
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (email) {
          expect(email, equals('test@example.com'));
        },
      );
    });
    
    test('should normalize email to lowercase', () {
      final result = validateLeadData.validateEmail('Test@EXAMPLE.COM');
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (email) {
          expect(email, equals('test@example.com'));
        },
      );
    });
    
    test('should reject invalid email format', () {
      final result = validateLeadData.validateEmail('invalid-email');
      
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure.message, contains('Invalid email'));
        },
        (_) => fail('Should fail'),
      );
    });
  });
  
  group('Website Validation', () {
    test('should add https protocol if missing', () {
      final result = validateLeadData.validateWebsite('example.com');
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (url) {
          expect(url, equals('https://example.com'));
        },
      );
    });
    
    test('should accept valid URL with protocol', () {
      final result = validateLeadData.validateWebsite('https://example.com');
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (url) {
          expect(url, equals('https://example.com'));
        },
      );
    });
    
    test('should reject invalid URL', () {
      final result = validateLeadData.validateWebsite('');
      
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure.message, contains('Invalid website'));
        },
        (_) => fail('Should fail'),
      );
    });
  });
  
  group('Business Name Validation', () {
    test('should accept valid business name', () {
      final result = validateLeadData.validateBusinessName('ABC Company');
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (name) {
          expect(name, equals('ABC Company'));
        },
      );
    });
    
    test('should trim whitespace', () {
      final result = validateLeadData.validateBusinessName('  ABC Company  ');
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (name) {
          expect(name, equals('ABC Company'));
        },
      );
    });
    
    test('should reject empty name', () {
      final result = validateLeadData.validateBusinessName('');
      
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure.message, contains('required'));
        },
        (_) => fail('Should fail'),
      );
    });
    
    test('should reject name with only numbers', () {
      final result = validateLeadData.validateBusinessName('12345');
      
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure.message, contains('cannot be only numbers'));
        },
        (_) => fail('Should fail'),
      );
    });
  });
  
  group('Complete Lead Data Validation', () {
    test('should validate complete lead data', () {
      final data = {
        'businessName': 'Test Company',
        'phone': '5551234567',
        'email': 'test@example.com',
        'websiteUrl': 'example.com',
      };
      
      final result = validateLeadData.validateLeadData(data);
      
      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Should not fail'),
        (validated) {
          expect(validated['businessName'], equals('Test Company'));
          expect(validated['phone'], equals('(555) 123-4567'));
          expect(validated['email'], equals('test@example.com'));
          expect(validated['websiteUrl'], equals('https://example.com'));
        },
      );
    });
    
    test('should collect multiple validation errors', () {
      final data = {
        'businessName': '',
        'phone': '123',
        'email': 'invalid',
      };
      
      final result = validateLeadData.validateLeadData(data);
      
      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure.message, contains('Business Name'));
          expect(failure.message, contains('Phone'));
          expect(failure.message, contains('Email'));
        },
        (_) => fail('Should fail'),
      );
    });
  });
}