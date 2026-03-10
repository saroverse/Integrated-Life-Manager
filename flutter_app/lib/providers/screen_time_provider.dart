import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';

final screenTimeSummaryProvider =
    FutureProvider.family<Map<String, dynamic>, int>((ref, days) async {
  return ApiService().getScreenTimeSummary(days: days);
});
