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
  /// Health Connect does not work with sideloaded APKs — returns false gracefully.
  Future<bool> requestPermissions() async {
    try {
      final permissions = _types.map((_) => HealthDataAccess.READ).toList();
      return await _health.requestAuthorization(_types, permissions: permissions);
    } catch (_) {
      return false;
    }
  }

  /// Check if permissions are already granted.
  Future<bool> hasPermissions() async {
    try {
      return await _health.hasPermissions(_types) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Health Connect is disabled in V2 — health data comes from Zepp cloud via backend.
  /// Returns empty payload so callers don't break.
  Future<Map<String, dynamic>> readHealthData({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    return {
      'metrics': <Map<String, dynamic>>[],
      'sleep_sessions': <Map<String, dynamic>>[],
      'workouts': <Map<String, dynamic>>[],
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
