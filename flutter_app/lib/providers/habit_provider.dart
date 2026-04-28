import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'dashboard_provider.dart';

final habitsTodayProvider = FutureProvider<List<dynamic>>((ref) async {
  return ApiService().getHabitsToday();
});

final habitsStatsProvider = FutureProvider.family<Map<String, dynamic>, int>((ref, days) async {
  return ApiService().getHabitsStats(days: days);
});

final habitCalendarProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ApiService().getHabitCalendar(id);
});

final habitLogProvider = NotifierProvider<HabitLogNotifier, void>(HabitLogNotifier.new);

class HabitLogNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> toggle(String habitId, bool completed) async {
    if (completed) HapticFeedback.lightImpact();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await ApiService().logHabit(habitId, {
      'date': today,
      'completed': completed ? 1 : 0,
    });
    ref.invalidate(habitsTodayProvider);
    ref.invalidate(dashboardTodayProvider);
  }
}
