import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';
import 'health_service.dart';
import 'screen_time_service.dart';

const syncTaskName = 'ilm_background_sync';

/// Called by WorkManager in the background every 2 hours.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == syncTaskName) {
      await SyncService().syncAll();
    }
    return Future.value(true);
  });
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _api = ApiService();
  final _health = HealthService();
  final _screenTime = ScreenTimeService();

  static const _lastSyncKey = 'last_health_sync';

  /// Register the background sync task with WorkManager.
  static Future<void> register() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskName,
      frequency: const Duration(hours: 2),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  /// Sync all data: health + screen time. Call on app open and in background.
  Future<SyncResult> syncAll() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);
    final lastSync = lastSyncStr != null
        ? DateTime.parse(lastSyncStr)
        : DateTime.now().subtract(const Duration(days: 7));

    final now = DateTime.now();
    int healthMetrics = 0;
    int screenTimeEntries = 0;
    String? error;

    try {
      // Health data: from last sync to now
      final healthPayload = await _health.readHealthData(
        startTime: lastSync,
        endTime: now,
      );
      await _api.syncHealth(healthPayload);
      healthMetrics = (healthPayload['metrics'] as List).length +
          (healthPayload['sleep_sessions'] as List).length +
          (healthPayload['workouts'] as List).length;

      // Screen time: today and yesterday
      final screenEntries = await _screenTime.readRecentScreenTime();
      if (screenEntries.isNotEmpty) {
        await _api.syncScreenTime(screenEntries);
        screenTimeEntries = screenEntries.length;
      }

      // Update last sync timestamp
      await prefs.setString(_lastSyncKey, now.toIso8601String());
    } catch (e) {
      error = e.toString();
    }

    return SyncResult(
      healthMetrics: healthMetrics,
      screenTimeEntries: screenTimeEntries,
      syncedAt: now,
      error: error,
    );
  }
}

class SyncResult {
  final int healthMetrics;
  final int screenTimeEntries;
  final DateTime syncedAt;
  final String? error;

  SyncResult({
    required this.healthMetrics,
    required this.screenTimeEntries,
    required this.syncedAt,
    this.error,
  });

  bool get hasError => error != null;

  @override
  String toString() =>
      'SyncResult(health: $healthMetrics, screenTime: $screenTimeEntries, error: $error)';
}
