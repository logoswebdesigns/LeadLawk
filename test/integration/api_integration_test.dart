// Integration tests for API endpoints.
// Pattern: Integration Testing - API verification.

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:leadloq/features/leads/data/datasources/leads_remote_datasource.dart';
import 'package:leadloq/features/leads/data/models/lead_model.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/domain/usecases/browser_automation_usecase.dart';

@GenerateMocks([Dio])
import 'api_integration_test.mocks.dart';

void main() {
  group('Leads API Integration Tests', () {
    late LeadsRemoteDataSource dataSource;
    late MockDio mockDio;
    
    setUp(() {
      mockDio = MockDio();
      dataSource = LeadsRemoteDataSourceImpl(dio: mockDio);
    });
    
    group('GET /leads', () {
      test('successfully fetches leads list', () async {
        final responseData = {
          'leads': [
            {
              'id': '1',
              'business_name': 'Test Business',
              'phone': '123-456-7890',
              'status': 'NEW',
              'rating': 4.5,
              'review_count': 100,
              'created_at': DateTime.now().toIso8601String(),
            },
          ],
        };
        
        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenAnswer((_) async => Response(
          data: responseData,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/leads'),
        ));
        
        final leads = await dataSource.getLeads();
        
        expect(leads, isNotEmpty);
        expect(leads.first.businessName, equals('Test Business'));
        verify(mockDio.get('/leads', queryParameters: anyNamed('queryParameters'))).called(1);
      });
      
      test('handles network errors gracefully', () async {
        when(mockDio.get(
          any,
          queryParameters: anyNamed('queryParameters'),
        )).thenThrow(DioException(
          type: DioExceptionType.connectionTimeout,
          requestOptions: RequestOptions(path: '/leads'),
          message: 'Connection timeout',
        ));
        
        expect(
          () => dataSource.getLeads(),
          throwsA(isA<DioException>()),
        );
      });
      
      test('filters leads by status', () async {
        final responseData = {
          'leads': [
            {
              'id': '1',
              'business_name': 'Contacted Business',
              'phone': '123-456-7890',
              'status': 'CONTACTED',
              'created_at': DateTime.now().toIso8601String(),
            },
          ],
        };
        
        when(mockDio.get(
          any,
          queryParameters: argThat(
            containsPair('status', 'CONTACTED'),
            named: 'queryParameters',
          ),
        )).thenAnswer((_) async => Response(
          data: responseData,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/leads'),
        ));
        
        final leads = await dataSource.getLeads(status: 'CONTACTED');
        
        expect(leads.every((l) => l.status == LeadStatus.called), isTrue);
      });
    });
    
    group('GET /leads/:id', () {
      test('fetches single lead by ID', () async {
        const leadId = 'test-lead-123';
        final responseData = {
          'id': leadId,
          'business_name': 'Single Business',
          'phone': '987-654-3210',
          'status': 'NEW',
          'created_at': DateTime.now().toIso8601String(),
        };
        
        when(mockDio.get('/leads/$leadId')).thenAnswer(
          (_) async => Response(
            data: responseData,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/leads/$leadId'),
          ),
        );
        
        final lead = await dataSource.getLead(leadId);
        
        expect(lead.id, equals(leadId));
        expect(lead.businessName, equals('Single Business'));
      });
      
      test('handles 404 for non-existent lead', () async {
        const leadId = 'non-existent';
        
        when(mockDio.get('/leads/$leadId')).thenThrow(
          DioException(
            response: Response(
              statusCode: 404,
              requestOptions: RequestOptions(path: '/leads/$leadId'),
            ),
            requestOptions: RequestOptions(path: '/leads/$leadId'),
          ),
        );
        
        expect(
          () => dataSource.getLead(leadId),
          throwsA(isA<DioException>()),
        );
      });
    });
    
    group('PUT /leads/:id', () {
      test('updates lead successfully', () async {
        final lead = LeadModel(
          id: 'update-test',
          businessName: 'Updated Business',
          phone: '555-0100',
          status: 'CALLED',
          industry: 'Test Industry',
          location: 'Test Location',
          source: 'test',
          hasWebsite: false,
          meetsRatingThreshold: false,
          hasRecentReviews: false,
          isCandidate: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        when(mockDio.put(
          '/leads/${lead.id}',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: lead.toJson(),
          statusCode: 200,
          requestOptions: RequestOptions(path: '/leads/${lead.id}'),
        ));
        
        final updated = await dataSource.updateLead(lead);
        
        expect(updated.businessName, equals('Updated Business'));
        expect(updated.status, equals('CALLED'));
      });
    });
    
    group('POST /automation/start', () {
      test('starts automation job', () async {
        final params = BrowserAutomationParams(
          industry: 'restaurants',
          location: 'New York, NY',
          minRating: 4.0,
          minReviews: 10,
          limit: 100,
          recentDays: 30,
        );
        
        const jobId = 'job-123-abc';
        
        when(mockDio.post(
          '/automation/start',
          data: anyNamed('data'),
        )).thenAnswer((_) async => Response(
          data: {'job_id': jobId},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/automation/start'),
        ));
        
        final result = await dataSource.startAutomation(params);
        
        expect(result, equals(jobId));
      });
      
      test('handles automation start errors', () async {
        final params = BrowserAutomationParams(
          industry: 'test',
          location: 'test',
          limit: 50,
          minRating: 3.0,
          minReviews: 5,
          recentDays: 30,
        );
        
        when(mockDio.post(
          '/automation/start',
          data: anyNamed('data'),
        )).thenThrow(DioException(
          response: Response(
            data: {'error': 'Selenium service unavailable'},
            statusCode: 503,
            requestOptions: RequestOptions(path: '/automation/start'),
          ),
          requestOptions: RequestOptions(path: '/automation/start'),
        ));
        
        expect(
          () => dataSource.startAutomation(params),
          throwsA(isA<DioException>()),
        );
      });
    });
    
    group('DELETE /leads/:id', () {
      test('deletes lead successfully', () async {
        const leadId = 'delete-test';
        
        when(mockDio.delete('/leads/$leadId')).thenAnswer(
          (_) async => Response(
            statusCode: 204,
            requestOptions: RequestOptions(path: '/leads/$leadId'),
          ),
        );
        
        await dataSource.deleteLead(leadId);
        
        verify(mockDio.delete('/leads/$leadId')).called(1);
      });
    });
    
    group('POST /leads/bulk-delete', () {
      test('deletes multiple leads', () async {
        final leadIds = ['lead1', 'lead2', 'lead3'];
        
        when(mockDio.post(
          '/leads/bulk-delete',
          data: argThat(
            containsPair('ids', leadIds),
            named: 'data',
          ),
        )).thenAnswer((_) async => Response(
          data: {'deleted': 3},
          statusCode: 200,
          requestOptions: RequestOptions(path: '/leads/bulk-delete'),
        ));
        
        await dataSource.deleteLeads(leadIds);
        
        verify(mockDio.post(
          '/leads/bulk-delete',
          data: argThat(
            containsPair('ids', leadIds),
            named: 'data',
          ),
        )).called(1);
      });
    });
  });
}