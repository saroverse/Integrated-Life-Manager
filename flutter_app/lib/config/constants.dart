class AppConstants {
  // Injected at build/run time via --dart-define-from-file=dart_defines.json
  // Copy dart_defines.json.example → dart_defines.json and fill in your values.
  // Build: flutter build apk --dart-define-from-file=dart_defines.json
  // Run:   flutter run --dart-define-from-file=dart_defines.json
  static const String backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String apiVersion = '/api/v1';
  static const String deviceToken = String.fromEnvironment('DEVICE_TOKEN');

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

    // Android system packages that accumulate silently
    'com.android.certinstaller',
    'com.android.chrome',                 // exclude if you track sbrowser separately — remove if Chrome is primary
    'com.android.phone',
    'com.android.server.telecom',

    // Health / wearable companion apps (not real screen time)
    'com.huami.watch.hmwatchmanager',     // Amazfit/Zepp watch manager
    'com.xiaomi.hm.health',              // Zepp / Mi Health
    'com.zepp.international',
    'com.huami.midong',

    // Developer / debug tools
    'tech.httptoolkit.android.v1',        // HTTP Toolkit
    'tech.httptoolkit.android',
  };

  // Minimum usage to report — filters out brief interactions.
  // Digital Wellbeing uses ~1 minute as its threshold.
  static const int minUsageSeconds = 60;

  // Hard cap per app per day — anything above this is almost certainly a
  // UsageStatsManager reporting bug (cumulative bleed or background audio).
  // 6 hours is a reasonable ceiling for a single app in a day.
  static const int maxUsageSecondsPerApp = 6 * 3600;
}
