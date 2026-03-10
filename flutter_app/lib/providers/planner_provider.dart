import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

final plannerDayProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, date) async {
  return ApiService().getPlannerDay(date);
});

final plannerWeekProvider = FutureProvider.family<List<dynamic>, String>((ref, start) async {
  return ApiService().getPlannerWeek(start);
});
