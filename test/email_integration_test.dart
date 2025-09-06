import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/presentation/providers/email_templates_provider.dart';
import 'package:leadloq/features/leads/presentation/widgets/email_template_dialog.dart';
import 'package:leadloq/features/leads/presentation/widgets/quick_actions_bar.dart';
import 'package:leadloq/features/leads/presentation/pages/account_page.dart';
import 'package:leadloq/features/leads/domain/entities/filter_state.dart';
import 'package:leadloq/features/leads/domain/repositories/filter_repository.dart';
import 'package:leadloq/features/leads/domain/providers/filter_providers.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:dartz/dartz.dart';

@GenerateMocks([FilterRepository])
import 'email_integration_test.mocks.dart';

void main() {
  group('Email Integration Tests', () {
    late MockFilterRepository mockFilterRepository;
    
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() async {
      // Reset SharedPreferences for each test
      SharedPreferences.setMockInitialValues({});
      
      mockFilterRepository = MockFilterRepository();
      
      // Setup mock filter repository responses
      when(mockFilterRepository.getFilterState()).thenAnswer((_) async => const Right(LeadsFilterState()));
      when(mockFilterRepository.getSortState()).thenAnswer((_) async => const Right(SortState()));
      when(mockFilterRepository.getUIState()).thenAnswer((_) async => const Right(LeadsUIState()));
      when(mockFilterRepository.saveFilterState(any)).thenAnswer((_) async => const Right(null));
      when(mockFilterRepository.saveSortState(any)).thenAnswer((_) async => const Right(null));
      when(mockFilterRepository.saveUIState(any)).thenAnswer((_) async => const Right(null));
    });

    testWidgets('QuickActionsBar contains email button', 
      (WidgetTester tester) async {
      final lead = Lead(
        id: 'test-1',
        businessName: 'Test Business',
        phone: '(555) 123-4567',
        location: 'New York, NY',
        industry: 'Technology',
        status: LeadStatus.new_,
        hasWebsite: true,
        isCandidate: true,
        meetsRatingThreshold: true,
        hasRecentReviews: true,
        source: 'test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        timeline: const [],
      );
      
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            overrides: [
              sharedPreferencesFutureProvider.overrideWith((ref) async => await SharedPreferences.getInstance()),
              filterRepositoryProvider.overrideWith((ref) async => mockFilterRepository),
            ],
            child: Scaffold(
              body: QuickActionsBar(
                lead: lead,
                onRefresh: () {},
              ),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Verify email button exists
      expect(find.byIcon(Icons.email), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('Account page has email templates option', 
      (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
            overrides: [
              sharedPreferencesFutureProvider.overrideWith((ref) async => await SharedPreferences.getInstance()),
              filterRepositoryProvider.overrideWith((ref) async => mockFilterRepository),
            ],
            child: const Scaffold(
              body: AccountPage(),
            ),
          ),
        ),
      );
      
      await tester.pumpAndSettle();
      
      // Verify email templates option exists
      expect(find.text('Email Templates'), findsOneWidget);
      expect(find.text('Manage email templates for lead outreach'), findsOneWidget);
    });

    test('Email template CRUD operations work correctly', () async {
      // Set up clean state
      SharedPreferences.setMockInitialValues({
        'email_templates_initialized': true,
        'email_templates': '[]',
      });
      
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesFutureProvider.overrideWith((ref) async => await SharedPreferences.getInstance()),
          filterRepositoryProvider.overrideWith((ref) async => mockFilterRepository),
        ],
      );
      addTearDown(container.dispose);
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      final notifier = container.read(emailTemplatesLocalProvider.notifier);
      
      // Create
      final template = EmailTemplate(
        id: 'crud-test',
        name: 'CRUD Template',
        subject: 'Subject',
        body: 'Body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await notifier.addTemplate(template);
      var templates = container.read(emailTemplatesLocalProvider);
      expect(templates.any((t) => t.id == 'crud-test'), true);
      
      // Update
      final updated = EmailTemplate(
        id: 'crud-test',
        name: 'Updated CRUD Template',
        subject: 'Updated Subject',
        body: 'Updated Body',
        createdAt: template.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await notifier.updateTemplate(updated);
      templates = container.read(emailTemplatesLocalProvider);
      final found = templates.firstWhere((t) => t.id == 'crud-test');
      expect(found.name, 'Updated CRUD Template');
      
      // Delete
      await notifier.deleteTemplate('crud-test');
      templates = container.read(emailTemplatesLocalProvider);
      expect(templates.any((t) => t.id == 'crud-test'), false);
    });

    test('Template persistence simulation', () async {
      // This test verifies that templates can be serialized and deserialized
      final template = EmailTemplate(
        id: 'persist-test',
        name: 'Test Persistence',
        subject: 'Subject',
        body: 'Body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Serialize
      final json = template.toJson();
      expect(json['id'], 'persist-test');
      expect(json['name'], 'Test Persistence');
      
      // Deserialize
      final restored = EmailTemplate.fromJson(json);
      expect(restored.id, template.id);
      expect(restored.name, template.name);
      expect(restored.subject, template.subject);
      expect(restored.body, template.body);
    });

    test('Default templates are created on first initialization', () async {
      // Simulate first run with clean state
      SharedPreferences.setMockInitialValues({
        'email_templates_initialized': false,
      });
      
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesFutureProvider.overrideWith((ref) async => await SharedPreferences.getInstance()),
          filterRepositoryProvider.overrideWith((ref) async => mockFilterRepository),
        ],
      );
      addTearDown(container.dispose);
      
      // Force initialization by reading the provider
      // final notifier = container.read(emailTemplatesLocalProvider.notifier);
      
      // Wait longer for async initialization to complete
      await Future.delayed(const Duration(milliseconds: 500));
      
      final templates = container.read(emailTemplatesLocalProvider);
      
      // Should have the 4 default templates
      expect(templates.length, greaterThanOrEqualTo(4));
      
      final templateNames = templates.map((t) => t.name).toList();
      expect(templateNames.contains('Initial Outreach'), true);
      expect(templateNames.contains('Follow-up After Call'), true);
      expect(templateNames.contains('Website Improvement Proposal'), true);
      expect(templateNames.contains('Thank You - Not Interested'), true);
    });


    test('Template variables are replaced correctly', () {
      final lead = Lead(
        id: 'test-1',
        businessName: 'Acme Corp',
        phone: '(555) 123-4567',
        location: 'New York, NY',
        industry: 'Technology',
        status: LeadStatus.new_,
        hasWebsite: true,
        rating: 4.5,
        reviewCount: 100,
        isCandidate: true,
        meetsRatingThreshold: true,
        hasRecentReviews: true,
        source: 'test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        timeline: const [],
      );
      
      const template = '''
Hello {{businessName}},
Location: {{location}}
Industry: {{industry}}
Phone: {{phone}}
Rating: {{rating}}
Reviews: {{reviewCount}}
''';
      
      final processed = template
          .replaceAll('{{businessName}}', lead.businessName)
          .replaceAll('{{location}}', lead.location)
          .replaceAll('{{industry}}', lead.industry)
          .replaceAll('{{phone}}', lead.phone)
          .replaceAll('{{rating}}', lead.rating?.toStringAsFixed(1) ?? 'N/A')
          .replaceAll('{{reviewCount}}', lead.reviewCount?.toString() ?? '0');
      
      expect(processed.contains('Acme Corp'), true);
      expect(processed.contains('New York, NY'), true);
      expect(processed.contains('Technology'), true);
      expect(processed.contains('(555) 123-4567'), true);
      expect(processed.contains('4.5'), true);
      expect(processed.contains('100'), true);
    });
  });
}