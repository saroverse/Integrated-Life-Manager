import 'package:health/health.dart';
import 'package:intl/intl.dart';

/// Reads health data from Health Connect (Android).
/// Zepp app syncs Amazfit Heliostrap data → Health Connect → this service reads it.
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();

  final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.WEIGHT,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WORKOUT,
  ];

  /// Request all required Health Connect permissions.
  Future<bool> requestPermissions() async {
    final permissions = _types.map((_) => HealthDataAccess.READ).toList();
    return _health.requestAuthorization(_types, permissions: permissions);
  }

  /// Check if permissions are already granted.
  Future<bool> hasPermissions() async {
    return await _health.hasPermissions(_types) ?? false;
  }

  /// Read all health data from [startTime] to [endTime].
  /// Returns a payload suitable for POST /health/sync.
  Future<Map<String, dynamic>> readHealthData({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final points = await _health.getHealthDataFromTypes(
      startTime: startTime,
      endTime: endTime,
      types: _types,
    );

    final metrics = <Map<String, dynamic>>[];
    final sleepSessions = <Map<String, dynamic>>[];
    final workouts = <Map<String, dynamic>>[];

    final fmt = DateFormat('yyyy-MM-dd');
    final isoFmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

    for (final point in points) {
      final date = fmt.format(point.dateFrom);
      final id = '${point.type.name}_${point.dateFrom.millisecondsSinceEpoch}';

      if (point.type == HealthDataType.SLEEP_SESSION) {
        sleepSessions.add({
          'id': id,
          'date': fmt.format(point.dateTo), // date of wake-up
          'bedtime': isoFmt.format(point.dateFrom),
          'wake_time': isoFmt.format(point.dateTo),
          'total_duration': point.dateTo.difference(point.dateFrom).inMinutes / 60.0,
          'source': 'health_connect',
        });
        continue;
      }

      if (point.type == HealthDataType.WORKOUT) {
        final val = point.value as WorkoutHealthValue?;
        workouts.add({
          'id': id,
          'workout_type': val?.workoutActivityType.name ?? 'unknown',
          'start_time': isoFmt.format(point.dateFrom),
          'end_time': isoFmt.format(point.dateTo),
          'duration': point.dateTo.difference(point.dateFrom).inMinutes.toDouble(),
          'date': date,
          'source': 'health_connect',
        });
        continue;
      }

      final numericValue = _extractNumericValue(point.value);
      if (numericValue == null) continue;

      metrics.add({
        'id': id,
        'metric_type': _metricTypeName(point.type),
        'value': numericValue,
        'unit': _metricUnit(point.type),
        'recorded_at': isoFmt.format(point.dateFrom),
        'date': date,
        'source': 'health_connect',
      });
    }

    return {
      'metrics': metrics,
      'sleep_sessions': sleepSessions,
      'workouts': workouts,
    };
  }

  double? _extractNumericValue(HealthValue value) {
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    return null;
  }

  String _metricTypeName(HealthDataType type) {
    return switch (type) {
      HealthDataType.STEPS => 'steps',
      HealthDataType.HEART_RATE => 'heart_rate',
      HealthDataType.RESTING_HEART_RATE => 'resting_heart_rate',
      HealthDataType.HEART_RATE_VARIABILITY_SDNN => 'heart_rate_variability_sdnn',
      HealthDataType.SLEEP_DEEP => 'sleep_deep',
      HealthDataType.SLEEP_REM => 'sleep_rem',
      HealthDataType.SLEEP_LIGHT => 'sleep_light',
      HealthDataType.SLEEP_AWAKE => 'sleep_awake',
      HealthDataType.WEIGHT => 'weight',
      HealthDataType.BLOOD_OXYGEN => 'blood_oxygen',
      _ => type.name.toLowerCase(),
    };
  }

  String _metricUnit(HealthDataType type) {
    return switch (type) {
      HealthDataType.STEPS => 'steps',
      HealthDataType.HEART_RATE => 'bpm',
      HealthDataType.RESTING_HEART_RATE => 'bpm',
      HealthDataType.HEART_RATE_VARIABILITY_SDNN => 'ms',
      HealthDataType.SLEEP_DEEP ||
      HealthDataType.SLEEP_REM ||
      HealthDataType.SLEEP_LIGHT ||
      HealthDataType.SLEEP_AWAKE => 'hours',
      HealthDataType.WEIGHT => 'kg',
      HealthDataType.BLOOD_OXYGEN => '%',
      _ => 'unknown',
    };
  }
}
