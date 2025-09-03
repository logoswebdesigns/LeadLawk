import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/email_template_dialog.dart';
import 'email_templates_api_provider.dart';

// Provider for managing email templates - now uses API
final emailTemplatesProvider = Provider<List<EmailTemplate>>((ref) {
  final asyncTemplates = ref.watch(emailTemplatesApiProvider);
  return asyncTemplates.maybeWhen(
    data: (templates) => templates,
    orElse: () => [],
  );
});

// Local storage provider for testing purposes only
final emailTemplatesLocalProvider = StateNotifierProvider<EmailTemplatesNotifier, List<EmailTemplate>>((ref) {
  return EmailTemplatesNotifier();
});

class EmailTemplatesNotifier extends StateNotifier<List<EmailTemplate>> {
  static const String _storageKey = 'email_templates';
  
  EmailTemplatesNotifier() : super([]) {
    _loadTemplates();
    _initializeDefaultTemplates();
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = prefs.getString(_storageKey);
    
    if (templatesJson != null) {
      final List<dynamic> decoded = json.decode(templatesJson);
      state = decoded.map((e) => EmailTemplate.fromJson(e)).toList();
    }
  }

  Future<void> _initializeDefaultTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final hasInitialized = prefs.getBool('email_templates_initialized') ?? false;
    
    if (!hasInitialized && state.isEmpty) {
      // Add default templates
      final defaultTemplates = [
        EmailTemplate(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Initial Outreach',
          subject: 'Improve Your Online Presence - {{businessName}}',
          body: '''Hi {{businessName}} Team,

I noticed your business in {{location}} and wanted to reach out about your online presence.

As a {{industry}} business with {{rating}} stars and {{reviewCount}} reviews, you're clearly doing great work. I'd love to discuss how we can help you attract even more customers online.

Would you be interested in a quick 10-minute call to discuss how we can help grow your business?

Best regards,
[Your Name]
[Your Company]''',
          description: 'First contact email for businesses without websites',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        EmailTemplate(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          name: 'Follow-up After Call',
          subject: 'Following Up - {{businessName}}',
          body: '''Hi {{businessName}} Team,

Thank you for taking the time to speak with me today. As discussed, I'm sending over some information about our services.

Key points from our conversation:
- [Add specific points discussed]
- [Add value propositions mentioned]

I've attached more details about how we can help {{businessName}} grow its online presence.

Let me know if you have any questions or would like to move forward.

Best regards,
[Your Name]
[Your Company]''',
          description: 'Send after initial phone conversation',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        EmailTemplate(
          id: (DateTime.now().millisecondsSinceEpoch + 2).toString(),
          name: 'Website Improvement Proposal',
          subject: 'Website Optimization for {{businessName}}',
          body: '''Hi {{businessName}} Team,

Following our conversation about your current website, I wanted to share some specific improvements we could implement:

1. **Mobile Optimization**: Ensure your site works perfectly on all devices
2. **Local SEO**: Help more customers in {{location}} find you
3. **Speed Improvements**: Faster loading times mean happier customers
4. **Modern Design**: Update the look to match your excellent {{rating}}-star reputation

With {{reviewCount}} reviews, you clearly have happy customers. Let's make sure new customers can find you easily online.

Would you like to schedule a brief call to discuss next steps?

Best regards,
[Your Name]
[Your Company]''',
          description: 'For businesses with existing websites that need improvement',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        EmailTemplate(
          id: (DateTime.now().millisecondsSinceEpoch + 3).toString(),
          name: 'Thank You - Not Interested',
          subject: 'Thank You - {{businessName}}',
          body: '''Hi {{businessName}} Team,

Thank you for taking the time to speak with me. I understand that now isn't the right time for you to invest in your online presence.

If anything changes in the future, please don't hesitate to reach out. We're always here to help {{industry}} businesses in {{location}} grow their online presence.

Wishing you continued success!

Best regards,
[Your Name]
[Your Company]''',
          description: 'Polite follow-up for leads that aren\'t interested',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      
      for (final template in defaultTemplates) {
        await addTemplate(template);
      }
      
      await prefs.setBool('email_templates_initialized', true);
    }
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final templatesJson = json.encode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, templatesJson);
  }

  Future<void> addTemplate(EmailTemplate template) async {
    state = [...state, template];
    await _saveTemplates();
  }

  Future<void> updateTemplate(EmailTemplate template) async {
    state = state.map((t) => t.id == template.id ? template : t).toList();
    await _saveTemplates();
  }

  Future<void> deleteTemplate(String templateId) async {
    state = state.where((t) => t.id != templateId).toList();
    await _saveTemplates();
  }

  Future<void> reorderTemplates(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final List<EmailTemplate> newList = [...state];
    final EmailTemplate item = newList.removeAt(oldIndex);
    newList.insert(newIndex, item);
    state = newList;
    await _saveTemplates();
  }
}