import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/presentation/providers/email_templates_provider.dart';
import 'package:leadloq/features/leads/presentation/widgets/email_template_dialog.dart';
import 'package:leadloq/features/leads/presentation/widgets/quick_actions_bar.dart';
import 'package:leadloq/features/leads/presentation/pages/account_page.dart';

void main() {
  group('Email Integration Tests', () {
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() async {
      // Reset SharedPreferences for each test
      SharedPreferences.setMockInitialValues({});
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
        timeline: [],
      );
      
      await tester.pumpWidget(
        MaterialApp(
          home: ProviderScope(
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
            child: Scaffold(
              body: const AccountPage(),
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
      
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      await Future.delayed(Duration(milliseconds: 100));
      
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
      
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // Force initialization by reading the provider
      final notifier = container.read(emailTemplatesLocalProvider.notifier);
      
      // Wait longer for async initialization to complete
      await Future.delayed(Duration(milliseconds: 500));
      
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
        timeline: [],
      );
      
      final template = '''
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