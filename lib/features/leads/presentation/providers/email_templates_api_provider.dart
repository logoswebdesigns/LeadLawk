import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/email_templates_remote_datasource.dart';
import '../widgets/email_template_dialog.dart';

// API-based provider for managing email templates
final emailTemplatesApiProvider = StateNotifierProvider<EmailTemplatesApiNotifier, AsyncValue<List<EmailTemplate>>>((ref) {
  final dataSource = ref.watch(emailTemplatesRemoteDataSourceProvider);
  return EmailTemplatesApiNotifier(dataSource);
});

class EmailTemplatesApiNotifier extends StateNotifier<AsyncValue<List<EmailTemplate>>> {
  final EmailTemplatesRemoteDataSource _dataSource;
  
  EmailTemplatesApiNotifier(this._dataSource) : super(const AsyncValue.loading()) {
    loadTemplates();
  }

  Future<void> loadTemplates() async {
    state = const AsyncValue.loading();
    try {
      // First try to initialize defaults if needed
      await _dataSource.initializeDefaults();
      
      // Then fetch all templates
      final templates = await _dataSource.getTemplates();
      state = AsyncValue.data(templates);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> addTemplate(EmailTemplate template) async {
    try {
      final newTemplate = await _dataSource.createTemplate(template);
      
      // Update state with new template
      state.whenData((templates) {
        state = AsyncValue.data([...templates, newTemplate]);
      });
    } catch (e) {
      // Handle error but don't change the main state
      throw e;
    }
  }

  Future<void> updateTemplate(EmailTemplate template) async {
    try {
      final updatedTemplate = await _dataSource.updateTemplate(template.id, template);
      
      // Update state with updated template
      state.whenData((templates) {
        state = AsyncValue.data(
          templates.map((t) => t.id == template.id ? updatedTemplate : t).toList(),
        );
      });
    } catch (e) {
      // Handle error but don't change the main state
      throw e;
    }
  }

  Future<void> deleteTemplate(String templateId) async {
    try {
      await _dataSource.deleteTemplate(templateId);
      
      // Update state by removing the template
      state.whenData((templates) {
        state = AsyncValue.data(
          templates.where((t) => t.id != templateId).toList(),
        );
      });
    } catch (e) {
      // Handle error but don't change the main state
      throw e;
    }
  }

  Future<void> refreshTemplates() async {
    await loadTemplates();
  }
}