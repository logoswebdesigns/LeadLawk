import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for Dio HTTP client
final dioProvider = Provider<Dio>((ref) {
  return createDio();
});

/// Creates and configures a Dio instance
Dio createDio() {
  final dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
    sendTimeout: Duration(seconds: 30),
  ));
  
  // Add interceptors for logging, error handling, etc.
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));
  
  return dio;
}