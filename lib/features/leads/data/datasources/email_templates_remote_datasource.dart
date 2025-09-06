import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../presentation/widgets/email_template_dialog.dart';

// Provider for the remote data source
final emailTemplatesRemoteDataSourceProvider = Provider<EmailTemplatesRemoteDataSource>((ref) {
  final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 10),
  ));
  return EmailTemplatesRemoteDataSource(dio);
});

class EmailTemplatesRemoteDataSource {
  final Dio _dio;

  EmailTemplatesRemoteDataSource(this._dio);

  Future<List<EmailTemplate>> getTemplates({bool activeOnly = false}) async {
    try {
      final response = await _dio.get(
        '/email-templates',
        queryParameters: {'active_only': activeOnly},
      );
      
      final List<dynamic> data = response.data;
      return data.map((json) => EmailTemplate.fromApiJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch email templates: $e');
    }
  }

  Future<EmailTemplate> getTemplate(String id) async {
    try {
      final response = await _dio.get('/email-templates/$id');
      return EmailTemplate.fromApiJson(response.data);
    } catch (e) {
      throw Exception('Failed to fetch email template: $e');
    }
  }

  Future<EmailTemplate> createTemplate(EmailTemplate template) async {
    try {
      final response = await _dio.post(
        '/email-templates',
        data: {
          'name': template.name,
          'subject': template.subject,
          'body': template.body,
          'description': template.description,
          'is_active': true,
        },
      );
      return EmailTemplate.fromApiJson(response.data);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 400) {
        throw Exception('Template with this name already exists');
      }
      throw Exception('Failed to create email template: $e');
    }
  }

  Future<EmailTemplate> updateTemplate(String id, EmailTemplate template) async {
    try {
      final response = await _dio.put(
        '/email-templates/$id',
        data: {
          'name': template.name,
          'subject': template.subject,
          'body': template.body,
          'description': template.description,
          'is_active': true,
        },
      );
      return EmailTemplate.fromApiJson(response.data);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 400) {
        throw Exception('Template with this name already exists');
      }
      throw Exception('Failed to update email template: $e');
    }
  }

  Future<void> deleteTemplate(String id) async {
    try {
      await _dio.delete('/email-templates/$id');
    } catch (e) {
      throw Exception('Failed to delete email template: $e');
    }
  }

  Future<Map<String, dynamic>> initializeDefaults() async {
    try {
      final response = await _dio.post('/email-templates/initialize-defaults');
      return response.data;
    } catch (e) {
      throw Exception('Failed to initialize default templates: $e');
    }
  }
}