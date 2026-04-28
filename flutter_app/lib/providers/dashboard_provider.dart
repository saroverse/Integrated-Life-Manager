import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

final dashboardTodayProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ApiService().getDashboardToday();
});

final latestBriefingProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ApiService().getLatestSummary('daily_briefing');
});

final tasksTodayProvider = FutureProvider<List<dynamic>>((ref) async {
  return ApiService().getTasksToday();
});
