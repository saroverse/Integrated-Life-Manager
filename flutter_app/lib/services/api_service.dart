import 'package:dio/dio.dart';
import '../config/constants.dart';

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

  // Tasks
  Future<List<dynamic>> getTasks({String? status}) async {
    final r = await _dio.get('/tasks', queryParameters: status != null ? {'status': status} : null);
    return r.data as List;
  }

  Future<List<dynamic>> getTasksToday() async {
    final r = await _dio.get('/tasks/today');
    return r.data as List;
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    final r = await _dio.post('/tasks', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTask(String id, Map<String, dynamic> data) async {
    final r = await _dio.put('/tasks/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> completeTask(String id) async {
    final r = await _dio.post('/tasks/$id/complete');
    return r.data as Map<String, dynamic>;
  }

  Future<void> deleteTask(String id) async {
    await _dio.delete('/tasks/$id');
  }

  // Habits
  Future<List<dynamic>> getHabitsToday() async {
    final r = await _dio.get('/habits/today');
    return r.data as List;
  }

  Future<List<dynamic>> getHabits() async {
    final r = await _dio.get('/habits');
    return r.data as List;
  }

  Future<Map<String, dynamic>> createHabit(Map<String, dynamic> data) async {
    final r = await _dio.post('/habits', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> logHabit(String id, Map<String, dynamic> data) async {
    final r = await _dio.post('/habits/$id/log', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getHabitStreak(String id) async {
    final r = await _dio.get('/habits/$id/streak');
    return r.data as Map<String, dynamic>;
  }

  // Health sync
  Future<void> syncHealth(Map<String, dynamic> payload) async {
    await _dio.post('/health/sync', data: payload);
  }

  Future<Map<String, dynamic>> getHealthSummary({String? date}) async {
    final r = await _dio.get('/health/summary', queryParameters: date != null ? {'date': date} : null);
    return r.data as Map<String, dynamic>;
  }

  // Screen time sync
  Future<void> syncScreenTime(List<Map<String, dynamic>> entries) async {
    await _dio.post('/screen-time/sync', data: {'entries': entries});
  }

  // Summaries
  Future<Map<String, dynamic>?> getLatestSummary(String type) async {
    try {
      final r = await _dio.get('/summaries/latest', queryParameters: {'type': type});
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

  // Dashboard
  Future<Map<String, dynamic>> getDashboardToday() async {
    final r = await _dio.get('/dashboard/today');
    return r.data as Map<String, dynamic>;
  }

  // Device token registration
  Future<void> registerFcmToken(String token) async {
    await _dio.post('/device/register-token', data: {'fcm_token': token});
  }

  // Sync
  Future<Map<String, dynamic>> push(Map<String, dynamic> payload) async {
    final r = await _dio.post('/sync/push', data: payload);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pull({String? since}) async {
    final r = await _dio.get('/sync/pull', queryParameters: since != null ? {'since': since} : null);
    return r.data as Map<String, dynamic>;
  }

  // Journal
  Future<Map<String, dynamic>?> getJournalToday() async {
    try {
      final r = await _dio.get('/journal/today');
      return r.data as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> createJournalEntry(Map<String, dynamic> data) async {
    final r = await _dio.post('/journal', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateJournalEntry(String id, Map<String, dynamic> data) async {
    final r = await _dio.put('/journal/$id', data: data);
    return r.data as Map<String, dynamic>;
  }

  // Chat
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
    await _dio.delete('/chat/history', queryParameters: {'session_id': sessionId});
  }
}
