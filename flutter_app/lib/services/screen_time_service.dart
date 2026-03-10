import 'package:app_usage/app_usage.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';

/// Reads per-app screen time from Android UsageStatsManager.
/// Requires: Settings > Apps > Special App Access > Usage Access → grant to this app.
class ScreenTimeService {
  static final ScreenTimeService _instance = ScreenTimeService._internal();
  factory ScreenTimeService() => _instance;
  ScreenTimeService._internal();

  static const _channel = MethodChannel('saroverse.lifemanager/usage_stats');

  /// Returns true if the PACKAGE_USAGE_STATS permission has been granted.
  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('checkPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens Android's Usage Access settings screen so the user can grant permission.
  Future<void> openSettings() async {
    await _channel.invokeMethod('openSettings');
  }

  final fmt = DateFormat('yyyy-MM-dd');
  final isoFmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  /// Read screen time for [date]. Returns list of entries for POST /screen-time/sync.
  Future<List<Map<String, dynamic>>> readScreenTime(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    try {
      final usageList = await AppUsage().getAppUsage(start, end);
      final dateStr = fmt.format(date);

      return usageList
          .where((u) =>
              u.usage.inSeconds >= AppConstants.minUsageSeconds &&
              !AppConstants.excludedPackages.contains(u.packageName))
          .map((u) => {
                'id': '${u.packageName}_$dateStr',
                'date': dateStr,
                'app_package': u.packageName,
                'app_name': _cleanAppName(u.appName, u.packageName),
                'app_category': _categorize(u.packageName),
                'duration_seconds': u.usage.inSeconds,
                'launch_count': 0,
                'first_used': isoFmt.format(start),
                'last_used': isoFmt.format(end),
              })
          .toList();
    } catch (e) {
      // UsageStatsManager permission not granted or error
      return [];
    }
  }

  /// Read both today and yesterday (to ensure yesterday's full data is captured).
  Future<List<Map<String, dynamic>>> readRecentScreenTime() async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));

    final todayEntries = await readScreenTime(today);
    final yesterdayEntries = await readScreenTime(yesterday);

    return [...todayEntries, ...yesterdayEntries];
  }

  String? _categorize(String packageName) {
    final lower = packageName.toLowerCase();
    if (_matches(lower, ['instagram', 'tiktok', 'snapchat', 'twitter', 'x.com',
        'facebook', 'reddit', 'pinterest', 'linkedin', 'discord', 'telegram', 'whatsapp'])) {
      return 'social';
    }
    if (_matches(lower, ['youtube', 'netflix', 'spotify', 'twitch', 'hulu',
        'primevideo', 'disneyplus', 'viaplay'])) {
      return 'entertainment';
    }
    if (_matches(lower, ['chrome', 'firefox', 'sbrowser', 'samsung.internet', 'opera', 'brave', 'kiwi'])) {
      return 'browser';
    }
    if (_matches(lower, ['maps', 'uber', 'bolt', 'waze', 'transit', 'navigation', 'gearhead'])) {
      return 'navigation';
    }
    if (_matches(lower, ['gmail', 'outlook', 'calendar', 'docs', 'sheets',
        'notion', 'todoist', 'slack', 'teams', 'zoom', 'office', 'word', 'excel'])) {
      return 'productivity';
    }
    if (_matches(lower, ['games', 'gaming', 'pubg', 'roblox', 'minecraft',
        'supercell', 'clashroyale', 'clashofclans', 'brawlstars', 'royale',
        'fortnite', 'callofduty', 'mobilelegends', 'freefire', 'tipico',
        'askus', 'spond'])) {
      return 'gaming';
    }
    if (_matches(lower, ['health', 'fitness', 'zepp', 'strava', 'training',
        'shealth', 'simplehealth', 'amazfit', 'huami', 'hmwatchmanager'])) {
      return 'health';
    }
    return 'other';
  }

  bool _matches(String pkg, List<String> keywords) =>
      keywords.any((kw) => pkg.contains(kw));

  /// The `app_usage` package derives app names from the package name, which gives
  /// misleading results like "android" for "com.instagram.android".
  /// Fall back to the last meaningful segment of the package name.
  String _cleanAppName(String appName, String packageName) {
    // If the returned name is just a generic word, derive from the package instead
    const generic = {'android', 'app', 'main', 'mobile', 'client', 'lite'};
    if (generic.contains(appName.toLowerCase())) {
      // e.g. com.instagram.android → Instagram
      final parts = packageName.split('.');
      // Find the most meaningful part (skip 'com', 'org', 'de', 'at', etc.)
      final skip = {'com', 'org', 'net', 'de', 'at', 'io', 'co', 'uk', 'android', 'app'};
      final candidate = parts.lastWhere(
        (p) => p.length > 2 && !skip.contains(p),
        orElse: () => parts.last,
      );
      return candidate[0].toUpperCase() + candidate.substring(1);
    }
    return appName;
  }
}
