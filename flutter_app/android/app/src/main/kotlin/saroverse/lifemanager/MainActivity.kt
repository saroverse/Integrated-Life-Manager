package saroverse.lifemanager

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "saroverse.lifemanager/usage_stats"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> result.success(hasUsageStatsPermission())
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "queryUsageEvents" -> {
                    val startMs = (call.argument<Number>("start_ms"))?.toLong()
                    val endMs = (call.argument<Number>("end_ms"))?.toLong()
                    if (startMs == null || endMs == null) {
                        result.error("INVALID_ARGS", "start_ms and end_ms required", null)
                        return@setMethodCallHandler
                    }
                    result.success(queryUsageEvents(startMs, endMs))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * Returns per-package foreground duration in seconds, computed from
     * MOVE_TO_FOREGROUND / MOVE_TO_BACKGROUND events only.
     * This matches what Digital Wellbeing shows — it excludes background
     * audio/PiP time that queryUsageStats() over-counts.
     */
    private fun queryUsageEvents(startMs: Long, endMs: Long): Map<String, Long> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(startMs, endMs)
        val event = UsageEvents.Event()

        // package -> timestamp when it moved to foreground (null = not in foreground)
        val foregroundStart = mutableMapOf<String, Long>()
        val durations = mutableMapOf<String, Long>()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    foregroundStart[pkg] = event.timeStamp
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val start = foregroundStart.remove(pkg) ?: continue
                    val dur = event.timeStamp - start
                    if (dur > 0) durations[pkg] = (durations[pkg] ?: 0L) + dur
                }
            }
        }

        // Handle apps still in foreground at query end
        for ((pkg, start) in foregroundStart) {
            val dur = endMs - start
            if (dur > 0) durations[pkg] = (durations[pkg] ?: 0L) + dur
        }

        // Convert ms → seconds
        return durations.mapValues { it.value / 1000L }
    }
}
