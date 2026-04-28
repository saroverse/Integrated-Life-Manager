import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../config/constants.dart';

/// Reads per-app screen time using Android UsageEvents (MOVE_TO_FOREGROUND /
/// MOVE_TO_BACKGROUND). This matches what Digital Wellbeing reports — it
/// excludes background audio and PiP time that queryUsageStats() over-counts.
class ScreenTimeService {
  static final ScreenTimeService _instance = ScreenTimeService._internal();
  factory ScreenTimeService() => _instance;
  ScreenTimeService._internal();

  static const _channel = MethodChannel('saroverse.lifemanager/usage_stats');

  Future<bool> hasPermission() async {
    try {
      return await _channel.invokeMethod<bool>('checkPermission') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openSettings() async {
    await _channel.invokeMethod('openSettings');
  }

  final _dateFmt = DateFormat('yyyy-MM-dd');
  final _isoFmt = DateFormat("yyyy-MM-dd'T'HH:mm:ss");

  /// Read screen time for [date] using event-based foreground tracking.
  Future<List<Map<String, dynamic>>> readScreenTime(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    // Don't query past now — avoids inflating in-progress day
    final end = date.day == DateTime.now().day &&
            date.month == DateTime.now().month &&
            date.year == DateTime.now().year
        ? DateTime.now()
        : start.add(const Duration(days: 1));

    try {
      final raw = await _channel.invokeMethod<Map>('queryUsageEvents', {
        'start_ms': start.millisecondsSinceEpoch,
        'end_ms': end.millisecondsSinceEpoch,
      });
      if (raw == null) return [];

      final dateStr = _dateFmt.format(date);

      final entries = <Map<String, dynamic>>[];
      for (final entry in raw.entries) {
        final pkg = entry.key as String;
        final seconds = (entry.value as num).toInt();

        if (seconds < AppConstants.minUsageSeconds) continue;
        if (AppConstants.excludedPackages.contains(pkg)) continue;

        final capped = seconds.clamp(0, AppConstants.maxUsageSecondsPerApp);
        entries.add({
          'id': '${pkg}_$dateStr',
          'date': dateStr,
          'app_package': pkg,
          'app_name': _nameFromPackage(pkg),
          'app_category': _categorize(pkg),
          'duration_seconds': capped,
          'launch_count': 0,
          'first_used': _isoFmt.format(start),
          'last_used': _isoFmt.format(end),
        });
      }

      entries.sort((a, b) =>
          (b['duration_seconds'] as int).compareTo(a['duration_seconds'] as int));
      return entries;
    } catch (e) {
      return [];
    }
  }

  /// Read today and yesterday.
  Future<List<Map<String, dynamic>>> readRecentScreenTime() async {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final todayEntries = await readScreenTime(today);
    final yesterdayEntries = await readScreenTime(yesterday);
    return [...todayEntries, ...yesterdayEntries];
  }

  String _nameFromPackage(String pkg) {
    // Common well-known packages
    const known = {
      'com.google.android.youtube': 'YouTube',
      'com.instagram.android': 'Instagram',
      'com.snapchat.android': 'Snapchat',
      'com.whatsapp': 'WhatsApp',
      'com.spotify.music': 'Spotify',
      'com.netflix.mediaclient': 'Netflix',
      'com.google.android.apps.maps': 'Maps',
      'com.sec.android.app.sbrowser': 'Samsung Browser',
      'com.android.chrome': 'Chrome',
      'com.twitter.android': 'Twitter',
      'com.facebook.katana': 'Facebook',
      'com.reddit.frontpage': 'Reddit',
      'com.discord': 'Discord',
      'com.supercell.clashroyale': 'Clash Royale',
      'com.chess': 'Chess',
      'com.sec.android.app.myfiles': 'My Files',
    };
    if (known.containsKey(pkg)) return known[pkg]!;

    // Derive from package: com.example.myapp → Myapp
    final parts = pkg.split('.');
    const skip = {'com', 'org', 'net', 'de', 'at', 'io', 'co', 'uk', 'android', 'app', 'google'};
    final candidate = parts.lastWhere(
      (p) => p.length > 2 && !skip.contains(p),
      orElse: () => parts.last,
    );
    return candidate[0].toUpperCase() + candidate.substring(1);
  }

  String? _categorize(String pkg) {
    final p = pkg.toLowerCase();
    if (_has(p, ['instagram', 'tiktok', 'snapchat', 'twitter', 'x.com',
        'facebook', 'reddit', 'pinterest', 'linkedin', 'discord', 'telegram', 'whatsapp'])) return 'social';
    if (_has(p, ['youtube', 'netflix', 'spotify', 'twitch', 'hulu',
        'primevideo', 'disneyplus', 'viaplay'])) return 'entertainment';
    if (_has(p, ['chrome', 'firefox', 'sbrowser', 'samsung.internet', 'opera', 'brave', 'kiwi'])) return 'browser';
    if (_has(p, ['maps', 'uber', 'bolt', 'waze', 'transit', 'navigation'])) return 'navigation';
    if (_has(p, ['gmail', 'outlook', 'calendar', 'docs', 'sheets',
        'notion', 'todoist', 'slack', 'teams', 'zoom', 'office'])) return 'productivity';
    if (_has(p, ['games', 'pubg', 'roblox', 'minecraft', 'supercell',
        'clashroyale', 'clashofclans', 'brawlstars', 'fortnite', 'callofduty',
        'mobilelegends', 'freefire', 'tipico', 'chess'])) return 'gaming';
    if (_has(p, ['health', 'fitness', 'zepp', 'strava', 'shealth', 'amazfit', 'huami'])) return 'health';
    return 'other';
  }

  bool _has(String pkg, List<String> keywords) => keywords.any(pkg.contains);
}
