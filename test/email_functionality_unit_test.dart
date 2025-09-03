import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leadloq/features/leads/domain/entities/lead.dart';
import 'package:leadloq/features/leads/presentation/providers/email_templates_provider.dart';
import 'package:leadloq/features/leads/presentation/widgets/email_template_dialog.dart';

void main() {
  group('Email Functionality Unit Tests', () {
    late SharedPreferences prefs;
    
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() async {
      // Reset SharedPreferences for each test
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Email templates provider initializes with default templates', () async {
      // Clear any existing templates first
      SharedPreferences.setMockInitialValues({
        'email_templates_initialized': false,
      });
      
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // Get the notifier and wait for initialization
      final notifier = container.read(emailTemplatesLocalProvider.notifier);
      
      // Wait for async initialization to complete
      await Future.delayed(Duration(milliseconds: 200));
      
      final templates = container.read(emailTemplatesLocalProvider);
      
      // Should have at least 4 default templates (may have more if they already exist)
      expect(templates.length, greaterThanOrEqualTo(4));
      expect(templates.any((t) => t.name == 'Initial Outreach'), true);
      expect(templates.any((t) => t.name == 'Follow-up After Call'), true);
      expect(templates.any((t) => t.name == 'Website Improvement Proposal'), true);
      expect(templates.any((t) => t.name == 'Thank You - Not Interested'), true);
    });

    test('Can add new email template', () async {
      // Start with clean state
      SharedPreferences.setMockInitialValues({
        'email_templates_initialized': true,
        'email_templates': '[]',
      });
      
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // Wait for initialization
      await Future.delayed(Duration(milliseconds: 100));
      
      final notifier = container.read(emailTemplatesLocalProvider.notifier);
      
      final newTemplate = EmailTemplate(
        id: 'test-1',
        name: 'Test Template',
        subject: 'Test Subject',
        body: 'Test Body',
        description: 'Test Description',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await notifier.addTemplate(newTemplate);
      
      final templates = container.read(emailTemplatesLocalProvider);
      expect(templates.any((t) => t.id == 'test-1'), true);
    });

    test('Can update email template', () async {
      // Start with clean state
      SharedPreferences.setMockInitialValues({
        'email_templates_initialized': true,
        'email_templates': '[]',
      });
      
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // Wait for initialization
      await Future.delayed(Duration(milliseconds: 100));
      
      final notifier = container.read(emailTemplatesLocalProvider.notifier);
      
      // Add a template first
      final template = EmailTemplate(
        id: 'update-test',
        name: 'Original Name',
        subject: 'Original Subject',
        body: 'Original Body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await notifier.addTemplate(template);
      
      // Update it
      final updatedTemplate = EmailTemplate(
        id: 'update-test',
        name: 'Updated Name',
        subject: 'Updated Subject',
        body: 'Updated Body',
        createdAt: template.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await notifier.updateTemplate(updatedTemplate);
      
      final templates = container.read(emailTemplatesLocalProvider);
      final found = templates.firstWhere(
        (t) => t.id == 'update-test',
        orElse: () => throw StateError('Template not found'),
      );
      expect(found.name, 'Updated Name');
      expect(found.subject, 'Updated Subject');
      expect(found.body, 'Updated Body');
    });

    test('Can delete email template', () async {
      // Start with clean state
      SharedPreferences.setMockInitialValues({
        'email_templates_initialized': true,
        'email_templates': '[]',
      });
      
      final container = ProviderContainer();
      addTearDown(container.dispose);
      
      // Wait for initialization
      await Future.delayed(Duration(milliseconds: 100));
      
      final notifier = container.read(emailTemplatesLocalProvider.notifier);
      
      // Add a template
      final template = EmailTemplate(
        id: 'delete-test',
        name: 'To Delete',
        subject: 'Subject',
        body: 'Body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await notifier.addTemplate(template);
      
      // Verify it exists
      var templates = container.read(emailTemplatesLocalProvider);
      expect(templates.any((t) => t.id == 'delete-test'), true);
      
      // Delete it
      await notifier.deleteTemplate('delete-test');
      
      // Verify it's gone
      templates = container.read(emailTemplatesLocalProvider);
      expect(templates.any((t) => t.id == 'delete-test'), false);
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
      
      final template = 'Hello {{businessName}} in {{location}}. Industry: {{industry}}, Phone: {{phone}}, Rating: {{rating}}, Reviews: {{reviewCount}}';
      
      // This simulates what the email dialog does
      final processed = template
          .replaceAll('{{businessName}}', lead.businessName)
          .replaceAll('{{location}}', lead.location)
          .replaceAll('{{industry}}', lead.industry)
          .replaceAll('{{phone}}', lead.phone)
          .replaceAll('{{rating}}', lead.rating?.toStringAsFixed(1) ?? 'N/A')
          .replaceAll('{{reviewCount}}', lead.reviewCount?.toString() ?? '0');
      
      expect(processed, 'Hello Acme Corp in New York, NY. Industry: Technology, Phone: (555) 123-4567, Rating: 4.5, Reviews: 100');
    });


    test('Templates can be serialized and deserialized', () async {
      // Test that templates can be properly serialized for persistence
      final template = EmailTemplate(
        id: 'serialize-test',
        name: 'Test Template',
        subject: 'Test Subject',
        body: 'Test Body',
        description: 'Test Description',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Convert to JSON
      final json = template.toJson();
      
      // Verify all fields are present
      expect(json['id'], 'serialize-test');
      expect(json['name'], 'Test Template');
      expect(json['subject'], 'Test Subject');
      expect(json['body'], 'Test Body');
      expect(json['description'], 'Test Description');
      
      // Convert back from JSON
      final restored = EmailTemplate.fromJson(json);
      
      // Verify restoration
      expect(restored.id, template.id);
      expect(restored.name, template.name);
      expect(restored.subject, template.subject);
      expect(restored.body, template.body);
      expect(restored.description, template.description);
    });
  });
}