import 'package:dio/dio.dart';
import '../config/constants.dart';
import 'local_cache.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: '${AppConstants.backendUrl}${AppConstants.apiVersion}',
      connectTimeout: AppConstants.syncTimeout,
      receiveTimeout: const Duration(seconds: 120),
      headers: {
        'X-Device-Token': AppConstants.deviceToken,
        'Content-Type': 'application/json',
      },
    ));
  }

  // ── Offline detection ──────────────────────────────────────────────────────

  static bool _isOffline(Object e) {
    if (e is DioException) {
      return e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout;
    }
    return false;
  }

  // ── Raw helpers (used by SyncService to replay queued ops) ────────────────

  Future<dynamic> rawPost(String path, dynamic body) async {
    final r = await _dio.post(path, data: body);
    return r.data;
  }

  Future<dynamic> rawPut(String path, dynamic body) async {
    final r = await _dio.put(path, data: body);
    return r.data;
  }

  Future<void> rawDelete(String path) async {
    await _dio.delete(path);
  }

  // ── Tasks ──────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getTasks({String? status}) async {
    try {
      final r = await _dio.get('/tasks',
          queryParameters: status != null ? {'status': status} : null);
      await LocalCache.saveResponse('tasks_${status ?? 'all'}', r.data);
      return r.data as List;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('tasks_${status ?? 'all'}');
        if (cached != null) return cached as List;
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getTasksToday() async {
    try {
      final r = await _dio.get('/tasks/today');
      await LocalCache.saveResponse('tasks_today', r.data);
      return r.data as List;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('tasks_today');
        if (cached != null) return cached as List;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    try {
      final r = await _dio.post('/tasks', data: data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('POST', '/tasks', body: data);
        return {'id': 'pending_${DateTime.now().millisecondsSinceEpoch}', ...data, '_pending': true};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateTask(
      String id, Map<String, dynamic> data) async {
    try {
      final r = await _dio.put('/tasks/$id', data: data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('PUT', '/tasks/$id', body: data);
        return {'_pending': true};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> completeTask(String id) async {
    try {
      final r = await _dio.post('/tasks/$id/complete');
      _updateCachedTaskStatus(id, 'completed');
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('POST', '/tasks/$id/complete');
        _updateCachedTaskStatus(id, 'completed');
        return {'_pending': true};
      }
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _dio.delete('/tasks/$id');
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('DELETE', '/tasks/$id');
        return;
      }
      rethrow;
    }
  }

  void _updateCachedTaskStatus(String id, String status) {
    for (final key in ['tasks_all', 'tasks_today', 'tasks_pending']) {
      final cached = LocalCache.getResponse(key);
      if (cached is List) {
        final updated = cached.map((t) {
          if ((t as Map)['id'] == id) return {...t, 'status': status};
          return t;
        }).toList();
        LocalCache.saveResponse(key, updated);
      }
    }
  }

  // ── Habits ─────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getHabitsToday() async {
    try {
      final r = await _dio.get('/habits/today');
      await LocalCache.saveResponse('habits_today', r.data);
      return r.data as List;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('habits_today');
        if (cached != null) return cached as List;
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getHabits() async {
    try {
      final r = await _dio.get('/habits');
      await LocalCache.saveResponse('habits', r.data);
      return r.data as List;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('habits');
        if (cached != null) return cached as List;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createHabit(Map<String, dynamic> data) async {
    try {
      final r = await _dio.post('/habits', data: data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('POST', '/habits', body: data);
        return {'id': 'pending_${DateTime.now().millisecondsSinceEpoch}', ...data, '_pending': true};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> logHabit(
      String id, Map<String, dynamic> data) async {
    try {
      final r = await _dio.post('/habits/$id/log', data: data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('POST', '/habits/$id/log', body: data);
        // Optimistically update the cached habits list so the UI reflects the toggle
        _updateCachedHabitCompletion(id, (data['completed'] as int?) == 1);
        return {'_pending': true};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateHabit(
      String id, Map<String, dynamic> data) async {
    try {
      final r = await _dio.put('/habits/$id', data: data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('PUT', '/habits/$id', body: data);
        return {'_pending': true};
      }
      rethrow;
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      await _dio.delete('/habits/$id');
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('DELETE', '/habits/$id');
        return;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getHabitStreak(String id) async {
    final r = await _dio.get('/habits/$id/streak');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHabitsStats({int days = 30}) async {
    try {
      final r =
          await _dio.get('/habits/stats', queryParameters: {'days': days});
      await LocalCache.saveResponse('habits_stats_$days', r.data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('habits_stats_$days');
        if (cached != null) return cached as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getHabitCalendar(String id,
      {String? start, String? end}) async {
    final r = await _dio.get('/habits/$id/calendar', queryParameters: {
      if (start != null) 'start': start,
      if (end != null) 'end': end,
    });
    return r.data as Map<String, dynamic>;
  }

  void _updateCachedHabitCompletion(String id, bool completed) {
    final cached = LocalCache.getResponse('habits_today');
    if (cached is List) {
      final updated = cached.map((h) {
        if ((h as Map)['id'] == id) return {...h, 'completed': completed};
        return h;
      }).toList();
      LocalCache.saveResponse('habits_today', updated);
    }
  }

  // ── Health sync ────────────────────────────────────────────────────────────

  Future<void> syncHealth(Map<String, dynamic> payload) async {
    await _dio.post('/health/sync', data: payload);
  }

  Future<Map<String, dynamic>> triggerZeppSync({int days = 3}) async {
    final r = await _dio.post('/health/zepp-sync', queryParameters: {'days': days});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHealthSummary({String? date}) async {
    try {
      final r = await _dio.get('/health/summary',
          queryParameters: date != null ? {'date': date} : null);
      await LocalCache.saveResponse('health_summary_${date ?? 'today'}', r.data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        final cached =
            LocalCache.getResponse('health_summary_${date ?? 'today'}');
        if (cached != null) return cached as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  // ── Screen time sync ───────────────────────────────────────────────────────

  Future<void> syncScreenTime(List<Map<String, dynamic>> entries) async {
    await _dio.post('/screen-time/sync', data: {'entries': entries});
  }

  Future<Map<String, dynamic>> getScreenTimeSummary({int days = 7}) async {
    try {
      final r = await _dio
          .get('/screen-time/summary', queryParameters: {'days': days});
      await LocalCache.saveResponse('screen_time_$days', r.data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('screen_time_$days');
        if (cached != null) return cached as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  // ── Summaries ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getLatestSummary(String type) async {
    try {
      final r = await _dio
          .get('/summaries/latest', queryParameters: {'type': type});
      return r.data as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>> getSummaries({String? type, int limit = 10}) async {
    final r = await _dio.get('/summaries', queryParameters: {
      if (type != null) 'type': type,
      'limit': limit,
    });
    return r.data as List;
  }

  // ── Dashboard ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardToday() async {
    try {
      final r = await _dio.get('/dashboard/today');
      await LocalCache.saveResponse('dashboard_today', r.data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('dashboard_today');
        if (cached != null) return cached as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  // ── Device token registration ──────────────────────────────────────────────

  Future<void> registerFcmToken(String token) async {
    await _dio.post('/device/register-token', data: {'fcm_token': token});
  }

  // ── Sync ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> push(Map<String, dynamic> payload) async {
    final r = await _dio.post('/sync/push', data: payload);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pull({String? since}) async {
    final r = await _dio.get('/sync/pull',
        queryParameters: since != null ? {'since': since} : null);
    return r.data as Map<String, dynamic>;
  }

  // ── Journal ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getJournalToday() async {
    try {
      final r = await _dio.get('/journal/today');
      return r.data as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createJournalEntry(
      Map<String, dynamic> data) async {
    try {
      final r = await _dio.post('/journal', data: data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('POST', '/journal', body: data);
        return {'_pending': true};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateJournalEntry(
      String id, Map<String, dynamic> data) async {
    try {
      final r = await _dio.put('/journal/$id', data: data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('PUT', '/journal/$id', body: data);
        return {'_pending': true};
      }
      rethrow;
    }
  }

  // ── Events ─────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getEvents({String? start, String? end}) async {
    final key = 'events_${start}_$end';
    try {
      final r = await _dio.get('/events', queryParameters: {
        if (start != null) 'start': start,
        if (end != null) 'end': end,
      });
      await LocalCache.saveResponse(key, r.data);
      return r.data as List;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse(key);
        if (cached != null) return cached as List;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async {
    try {
      final r = await _dio.post('/events', data: data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('POST', '/events', body: data);
        return {'id': 'pending_${DateTime.now().millisecondsSinceEpoch}', ...data, '_pending': true};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateEvent(
      String id, Map<String, dynamic> data) async {
    try {
      final r = await _dio.put('/events/$id', data: data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('PUT', '/events/$id', body: data);
        return {'_pending': true};
      }
      rethrow;
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await _dio.delete('/events/$id');
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('DELETE', '/events/$id');
        return;
      }
      rethrow;
    }
  }

  // ── Planner ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPlannerDay(String date) async {
    try {
      final r =
          await _dio.get('/planner/day', queryParameters: {'date': date});
      await LocalCache.saveResponse('planner_$date', r.data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('planner_$date');
        if (cached != null) return cached as Map<String, dynamic>;
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getPlannerWeek(String start) async {
    try {
      final r =
          await _dio.get('/planner/week', queryParameters: {'start': start});
      await LocalCache.saveResponse('planner_week_$start', r.data);
      return r.data as List;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('planner_week_$start');
        if (cached != null) return cached as List;
      }
      rethrow;
    }
  }

  // ── Chat ───────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required String sessionId,
  }) async {
    final r = await _dio.post('/chat/message', data: {
      'message': message,
      'session_id': sessionId,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getChatHistory({
    required String sessionId,
    int limit = 50,
    int offset = 0,
  }) async {
    final r = await _dio.get('/chat/history', queryParameters: {
      'session_id': sessionId,
      'limit': limit,
      'offset': offset,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> clearChatHistory(String sessionId) async {
    await _dio.delete('/chat/history',
        queryParameters: {'session_id': sessionId});
  }

  Future<Map<String, dynamic>> parseCommand(String text) async {
    final r = await _dio.post('/chat/command', data: {'text': text});
    return r.data as Map<String, dynamic>;
  }

  // ── Lists ──────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getLists() async {
    try {
      final r = await _dio.get('/lists');
      await LocalCache.saveResponse('lists', r.data);
      return r.data as List;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('lists');
        if (cached != null) return cached as List;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createList(Map<String, dynamic> data) async {
    final r = await _dio.post('/lists', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteList(String id) async {
    await _dio.delete('/lists/$id');
  }

  Future<List<dynamic>> getListItems(String listId) async {
    try {
      final r = await _dio.get('/lists/$listId/items');
      await LocalCache.saveResponse('list_items_$listId', r.data);
      return r.data as List;
    } catch (e) {
      if (_isOffline(e)) {
        final cached = LocalCache.getResponse('list_items_$listId');
        if (cached != null) return cached as List;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addListItem(
      String listId, String text) async {
    try {
      final r = await _dio.post('/lists/$listId/items', data: {'text': text});
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('POST', '/lists/$listId/items',
            body: {'text': text});
        return {'id': 'pending_${DateTime.now().millisecondsSinceEpoch}', 'text': text, 'checked': false, '_pending': true};
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateListItem(
      String listId, String itemId, Map<String, dynamic> data) async {
    try {
      final r = await _dio.put('/lists/$listId/items/$itemId', data: data);
      return r.data as Map<String, dynamic>;
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('PUT', '/lists/$listId/items/$itemId', body: data);
        return {'_pending': true};
      }
      rethrow;
    }
  }

  Future<void> deleteListItem(String listId, String itemId) async {
    try {
      await _dio.delete('/lists/$listId/items/$itemId');
    } catch (e) {
      if (_isOffline(e)) {
        await LocalCache.enqueue('DELETE', '/lists/$listId/items/$itemId');
        return;
      }
      rethrow;
    }
  }

  Future<void> clearCheckedItems(String listId) async {
    await _dio.delete('/lists/$listId/items/checked/all');
  }
}
