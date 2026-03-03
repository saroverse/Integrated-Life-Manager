class AppConstants {
  // Backend URL — set to your Mac's local IP address on your home WiFi
  // Find it with: ifconfig | grep "inet " | grep -v 127.0.0.1
  // Or use Tailscale address if running remotely
  static const String backendUrl = 'http://192.168.2.124:8000';

  static const String apiVersion = '/api/v1';
  static const String deviceToken = '***REMOVED***';

  static const Duration syncInterval = Duration(hours: 2);
  static const Duration syncTimeout = Duration(seconds: 30);

  // Health Connect — metric types to read from Amazfit (via Zepp → Health Connect)
  static const List<String> healthMetricTypes = [
    'STEPS',
    'HEART_RATE',
    'RESTING_HEART_RATE',
    'HEART_RATE_VARIABILITY_SDNN',
    'SLEEP_SESSION',
    'SLEEP_DEEP',
    'SLEEP_REM',
    'SLEEP_LIGHT',
    'WEIGHT',
    'BLOOD_OXYGEN',
    'WORKOUT',
  ];

  // Screen time — packages to exclude from tracking (system UI etc.)
  static const Set<String> excludedPackages = {
    'com.android.systemui',
    'com.android.launcher',
    'com.android.launcher3',
    'com.samsung.android.launcher',
    'com.sec.android.app.launcher',
  };
}
