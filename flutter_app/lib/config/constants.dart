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

  // Screen time — packages to exclude from tracking.
  // Matches Digital Wellbeing's behaviour: system services, Samsung UI, Google services,
  // and this app itself are excluded.
  static const Set<String> excludedPackages = {
    // This app
    'saroverse.lifemanager',

    // Android system
    'com.android.systemui',
    'com.android.launcher',
    'com.android.launcher3',
    'com.android.settings',
    'com.android.settings.intelligence',
    'com.android.vending',           // Play Store
    'com.android.packageinstaller',
    'android',

    // Samsung launcher & UI
    'com.samsung.android.launcher',
    'com.sec.android.app.launcher',
    'com.samsung.android.forest',          // Digital Wellbeing
    'com.samsung.android.lool',            // Digital Wellbeing tools
    'com.samsung.android.app.galaxyfinder',// Bixby / search
    'com.samsung.android.incallui',        // Call UI overlay
    'com.samsung.android.dialer',
    'com.samsung.android.app.telephonyui',
    'com.samsung.android.messaging',
    'com.samsung.android.mtp',
    'com.samsung.android.accessibility.talkback',
    'com.samsung.android.app.routines',
    'com.samsung.android.app.spage',       // Edge panel
    'com.samsung.android.voc',
    'com.samsung.android.oneconnect',
    'com.osp.app.signin',                  // Samsung account
    'com.sec.android.daemonapp',
    'com.sec.android.app.clockpackage',

    // Google system services
    'com.google.android.gms',             // Play Services
    'com.google.android.apps.healthdata', // Health Connect
    'com.google.android.permissioncontroller',
    'com.google.android.googlequicksearchbox',
    'com.google.android.packageinstaller',
    'com.google.android.apps.tachyon',    // Google Meet (background)
    'com.google.android.projection.gearhead', // Android Auto
  };

  // Minimum usage to report — filters out brief system interactions (<30 s).
  // Digital Wellbeing only shows apps used meaningfully.
  static const int minUsageSeconds = 30;
}
