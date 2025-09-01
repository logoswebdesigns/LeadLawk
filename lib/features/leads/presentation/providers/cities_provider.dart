import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/cities_datasource.dart';

final citiesDataSourceProvider = Provider<CitiesDataSource>((ref) {
  return CitiesDataSourceImpl(dio: Dio());
});

final citiesForStateProvider = FutureProvider.family<List<String>, String>((ref, state) async {
  final dataSource = ref.watch(citiesDataSourceProvider);
  return await dataSource.getCitiesForState(state);
});