import 'package:flutter_test/flutter_test.dart';
import 'package:leadloq/features/leads/data/models/lead_model.dart';
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';
import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';

class MockDio extends Mock implements Dio {}

void main() {
  group('Callback Scheduling Tests', () {
    late MockDio mockDio;
    late LeadsRemoteDataSourceImpl dataSource;
    
    setUp(() {
      mockDio = MockDio();
      dataSource = LeadsRemoteDataSourceImpl(
        dio: mockDio,
        baseUrl: 'http://test.com',
      );
    });
    
    test('should update lead status to callbackScheduled with follow-up date', () async {
      // Arrange
      final testLead = LeadModel(
        id: 'test-id',
        businessName: 'Test Business',
        phone: '555-1234',
        industry: 'Test',
        location: 'Test City',
        source: 'test',
        hasWebsite: false,
        meetsRatingThreshold: true,
        hasRecentReviews: true,
        isCandidate: true,
        status: 'callbackScheduled',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        followUpDate: DateTime.now().add(const Duration(days: 1)),
      );
      
      when(() => mockDio.put(
        any(),
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
        data: testLead.toJson(),
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));
      
      // Act
      final result = await dataSource.updateLead(testLead);
      
      // Assert
      expect(result.status, equals('callbackScheduled'));
      expect(result.followUpDate, isNotNull);
      
      verify(() => mockDio.put(
        'http://test.com/leads/test-id',
        data: {
          'status': 'callbackScheduled',
          'follow_up_date': testLead.followUpDate!.toIso8601String(),
        },
      )).called(1);
    });
    
    test('should add timeline entry for callback scheduling', () async {
      // Arrange
      const leadId = 'test-id';
      final callbackDateTime = DateTime.now().add(const Duration(days: 1));
      final entryData = {
        'type': 'FOLLOW_UP',
        'title': 'Callback scheduled',
        'description': 'Callback scheduled for tomorrow',
        'follow_up_date': callbackDateTime.toIso8601String(),
        'metadata': {
          'scheduled_at': DateTime.now().toIso8601String(),
          'scheduled_for': callbackDateTime.toIso8601String(),
        },
      };
      
      when(() => mockDio.post(
        any(),
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
        data: {'success': true},
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));
      
      // Act
      await dataSource.addTimelineEntry(leadId, entryData);
      
      // Assert
      verify(() => mockDio.post(
        'http://test.com/leads/$leadId/timeline',
        data: entryData,
      )).called(1);
    });
    
    test('should handle callback scheduling with notes', () async {
      // Arrange
      final testLead = LeadModel(
        id: 'test-id',
        businessName: 'Test Business',
        phone: '555-1234',
        industry: 'Test',
        location: 'Test City',
        source: 'test',
        hasWebsite: false,
        meetsRatingThreshold: true,
        hasRecentReviews: true,
        isCandidate: true,
        status: 'callbackScheduled',
        notes: 'Follow up about pricing',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        followUpDate: DateTime.now().add(const Duration(days: 2)),
      );
      
      when(() => mockDio.put(
        any(),
        data: any(named: 'data'),
      )).thenAnswer((_) async => Response(
        data: testLead.toJson(),
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      ));
      
      // Act
      final result = await dataSource.updateLead(testLead);
      
      // Assert
      expect(result.status, equals('callbackScheduled'));
      expect(result.followUpDate, isNotNull);
      expect(result.notes, equals('Follow up about pricing'));
      
      verify(() => mockDio.put(
        'http://test.com/leads/test-id',
        data: {
          'status': 'callbackScheduled',
          'notes': 'Follow up about pricing',
          'follow_up_date': testLead.followUpDate!.toIso8601String(),
        },
      )).called(1);
    });
  });
}