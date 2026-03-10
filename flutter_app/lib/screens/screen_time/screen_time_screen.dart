import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/screen_time_provider.dart';
import '../../services/api_service.dart';
import '../../services/screen_time_service.dart';

class ScreenTimeScreen extends ConsumerStatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  ConsumerState<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends ConsumerState<ScreenTimeScreen> {
  int _days = 7;
  bool _syncing = false;
  String? _syncMessage;
  bool? _hasPermission;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await ScreenTimeService().hasPermission();
    if (mounted) setState(() => _hasPermission = granted);
  }

  Future<void> _sync() async {
    final service = ScreenTimeService();
    final granted = await service.hasPermission();
    setState(() => _hasPermission = granted);
    if (!granted) {
      if (!mounted) return;
      _showPermissionDialog();
      return;
    }
    setState(() { _syncing = true; _syncMessage = null; });
    try {
      final entries = await service.readRecentScreenTime();
      if (entries.isNotEmpty) {
        await ApiService().syncScreenTime(entries);
        setState(() => _syncMessage = 'Synced ${entries.length} app entries');
      } else {
        setState(() => _syncMessage = 'No usage data returned — check permission');
      }
      ref.invalidate(screenTimeSummaryProvider(_days));
    } catch (e) {
      setState(() => _syncMessage = 'Sync error: $e');
    } finally {
      setState(() => _syncing = false);
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        title: const Text('Usage Access Required', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Life Manager needs "Usage Access" permission to read screen time — '
          'the same data shown in Digitales Wohlbefinden.\n\n'
          'Tap Open Settings, find "Life Manager" in the list, and enable the toggle.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ScreenTimeService().openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(screenTimeSummaryProvider(_days));

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1117),
        title: const Text('Screen Time', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Sync from phone',
              onPressed: _sync,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_hasPermission == false)
            _PermissionBanner(onGrant: _showPermissionDialog),
          if (_syncMessage != null)
            _MessageBanner(message: _syncMessage!),
          Expanded(
            child: summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('Failed to load: $e', style: const TextStyle(color: Colors.red)),
              ),
              data: (data) => _Body(data: data, days: _days, onDaysChanged: (d) => setState(() => _days = d)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onGrant;
  const _PermissionBanner({required this.onGrant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFE67E22).withAlpha(40),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Color(0xFFE67E22), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Usage Access not granted — tap Sync to enable',
              style: TextStyle(color: Color(0xFFE67E22), fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onGrant,
            child: const Text('Fix', style: TextStyle(color: Color(0xFFE67E22))),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  const _MessageBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final isError = message.contains('error') || message.contains('Error');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: (isError ? Colors.red : Colors.green).withAlpha(30),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red : Colors.green, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13, color: isError ? Colors.red : Colors.green)),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Map<String, dynamic> data;
  final int days;
  final ValueChanged<int> onDaysChanged;

  const _Body({required this.data, required this.days, required this.onDaysChanged});

  @override
  Widget build(BuildContext context) {
    final today = data['today'] as Map<String, dynamic>;
    final todayHours = (today['total_hours'] as num).toDouble();
    final yesterdayHours = (data['yesterday_hours'] as num).toDouble();
    final currentAvg = (data['current_avg_hours'] as num).toDouble();
    final previousAvg = (data['previous_avg_hours'] as num).toDouble();
    final daily = (data['daily'] as List<dynamic>).cast<Map<String, dynamic>>();
    final categories = (data['categories'] as List<dynamic>).cast<Map<String, dynamic>>();
    final apps = (today['apps'] as List<dynamic>).cast<Map<String, dynamic>>().take(10).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PeriodSelector(days: days, onChanged: onDaysChanged),
        const SizedBox(height: 16),
        _SummaryCard(
          todayHours: todayHours,
          yesterdayHours: yesterdayHours,
          currentAvg: currentAvg,
          previousAvg: previousAvg,
          days: days,
        ),
        const SizedBox(height: 16),
        if (daily.isNotEmpty) ...[
          _SectionHeader(title: '$days-Day Trend'),
          const SizedBox(height: 8),
          _TrendChart(daily: daily),
          const SizedBox(height: 24),
        ],
        if (categories.isNotEmpty) ...[
          _SectionHeader(title: 'By Category'),
          const SizedBox(height: 8),
          _CategoryBreakdown(categories: categories),
          const SizedBox(height: 24),
        ],
        if (apps.isNotEmpty) ...[
          _SectionHeader(title: 'Top Apps Today'),
          const SizedBox(height: 8),
          _AppsList(apps: apps),
          const SizedBox(height: 24),
        ],
        if (apps.isEmpty && daily.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'No screen time data yet.\n\nTap the sync button (↻) in the top-right to pull data from your phone.\nIf you see a permission warning, tap Fix first.',
                style: TextStyle(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Period selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;

  const _PeriodSelector({required this.days, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [7, 14, 30].map((d) {
        final selected = d == days;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(d),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF4F6EF7) : const Color(0xFF1A1D27),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$d days',
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double todayHours;
  final double yesterdayHours;
  final double currentAvg;
  final double previousAvg;
  final int days;

  const _SummaryCard({
    required this.todayHours,
    required this.yesterdayHours,
    required this.currentAvg,
    required this.previousAvg,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    final deltaToday = todayHours - yesterdayHours;
    final deltaAvg = currentAvg - previousAvg;
    final pctChange = previousAvg > 0 ? ((deltaAvg / previousAvg) * 100).abs().round() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatHours(todayHours),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'today',
                  style: TextStyle(color: Colors.white.withAlpha(128), fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DeltaBadge(
            label: 'vs yesterday',
            delta: deltaToday,
            formatValue: _formatHours,
          ),
          const SizedBox(height: 8),
          if (previousAvg > 0)
            _DeltaBadge(
              label: 'avg vs prev ${days}d ($pctChange%)',
              delta: deltaAvg,
              formatValue: _formatHours,
            ),
        ],
      ),
    );
  }

  String _formatHours(double h) {
    final totalMin = (h * 60).round();
    final hrs = totalMin ~/ 60;
    final mins = totalMin % 60;
    if (hrs == 0) return '${mins}m';
    if (mins == 0) return '${hrs}h';
    return '${hrs}h ${mins}m';
  }
}

class _DeltaBadge extends StatelessWidget {
  final String label;
  final double delta;
  final String Function(double) formatValue;

  const _DeltaBadge({required this.label, required this.delta, required this.formatValue});

  @override
  Widget build(BuildContext context) {
    // Less screen time = improvement (green), more = worse (red)
    final isImprovement = delta < 0;
    final color = isImprovement ? const Color(0xFF27AE60) : const Color(0xFFE74C3C);
    final icon = isImprovement ? '▼' : '▲';
    final absHours = delta.abs();

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(38),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$icon ${formatValue(absHours)}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}

// ── Trend chart ───────────────────────────────────────────────────────────────

class _TrendChart extends StatefulWidget {
  final List<Map<String, dynamic>> daily;

  const _TrendChart({required this.daily});

  @override
  State<_TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<_TrendChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final maxHours = widget.daily.map((d) => (d['total_hours'] as num).toDouble()).fold(0.0, (a, b) => a > b ? a : b);
    final yMax = (maxHours * 1.2).ceilToDouble().clamp(1.0, double.infinity);

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          maxY: yMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final h = rod.toY;
                final totalMin = (h * 60).round();
                final hrs = totalMin ~/ 60;
                final mins = totalMin % 60;
                final label = hrs > 0 ? '${hrs}h ${mins}m' : '${mins}m';
                return BarTooltipItem(label, const TextStyle(color: Colors.white, fontWeight: FontWeight.bold));
              },
            ),
            touchCallback: (event, response) {
              setState(() {
                _touchedIndex = response?.spot?.touchedBarGroupIndex;
              });
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= widget.daily.length) return const SizedBox.shrink();
                  final dateStr = widget.daily[idx]['date'] as String;
                  final parts = dateStr.split('-');
                  final label = parts.length == 3 ? '${parts[1]}/${parts[2]}' : dateStr;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text('${value.toInt()}h', style: const TextStyle(color: Colors.white38, fontSize: 10));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF2A2D3A), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(widget.daily.length, (i) {
            final hours = (widget.daily[i]['total_hours'] as num).toDouble();
            final isTouched = _touchedIndex == i;
            final color = hours < 3
                ? const Color(0xFF27AE60)
                : hours < 5
                    ? const Color(0xFFE67E22)
                    : const Color(0xFFE74C3C);
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: hours,
                  color: isTouched ? Colors.white : color,
                  width: isTouched ? 14 : 12,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ── Category breakdown ────────────────────────────────────────────────────────

class _CategoryBreakdown extends StatelessWidget {
  final List<Map<String, dynamic>> categories;

  const _CategoryBreakdown({required this.categories});

  static const _colors = {
    'social': Color(0xFF9B59B6),
    'entertainment': Color(0xFFE74C3C),
    'productivity': Color(0xFF3498DB),
    'gaming': Color(0xFFE67E22),
    'health': Color(0xFF27AE60),
    'browser': Color(0xFF16A085),
    'navigation': Color(0xFFF39C12),
    'other': Color(0xFF7F8C8D),
  };

  static const _icons = {
    'social': Icons.people,
    'entertainment': Icons.play_circle,
    'productivity': Icons.work,
    'gaming': Icons.sports_esports,
    'health': Icons.favorite,
    'browser': Icons.language,
    'navigation': Icons.map,
    'other': Icons.apps,
  };

  @override
  Widget build(BuildContext context) {
    final totalSeconds = categories.fold<int>(0, (sum, c) => sum + (c['total_seconds'] as int));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: categories.map((cat) {
          final name = cat['name'] as String;
          final seconds = cat['total_seconds'] as int;
          final pct = totalSeconds > 0 ? seconds / totalSeconds : 0.0;
          final color = _colors[name] ?? const Color(0xFF7F8C8D);
          final icon = _icons[name] ?? Icons.apps;
          final totalMin = (seconds / 60).round();
          final hrs = totalMin ~/ 60;
          final mins = totalMin % 60;
          final label = hrs > 0 ? '${hrs}h ${mins}m' : '${mins}m';

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: Text(
                    name[0].toUpperCase() + name.substring(1),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: const Color(0xFF2A2D3A),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 52,
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Top apps list ─────────────────────────────────────────────────────────────

class _AppsList extends StatelessWidget {
  final List<Map<String, dynamic>> apps;

  const _AppsList({required this.apps});

  static const _categoryColors = {
    'social': Color(0xFF9B59B6),
    'entertainment': Color(0xFFE74C3C),
    'productivity': Color(0xFF3498DB),
    'gaming': Color(0xFFE67E22),
    'health': Color(0xFF27AE60),
    'browser': Color(0xFF16A085),
    'navigation': Color(0xFFF39C12),
    'other': Color(0xFF7F8C8D),
  };

  @override
  Widget build(BuildContext context) {
    final maxSeconds = apps.isEmpty ? 1 : (apps.first['duration_seconds'] as int);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: List.generate(apps.length, (i) {
          final app = apps[i];
          final name = app['app_name'] as String;
          final category = (app['app_category'] as String?) ?? 'other';
          final seconds = app['duration_seconds'] as int;
          final launches = app['launch_count'] as int;
          final pct = maxSeconds > 0 ? seconds / maxSeconds : 0.0;
          final color = _categoryColors[category] ?? const Color(0xFF7F8C8D);
          final totalMin = (seconds / 60).round();
          final hrs = totalMin ~/ 60;
          final mins = totalMin % 60;
          final durationLabel = hrs > 0 ? '${hrs}h ${mins}m' : '${mins}m';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(51),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  category,
                                  style: TextStyle(color: color, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: const Color(0xFF2A2D3A),
                              valueColor: AlwaysStoppedAnimation<Color>(color.withAlpha(153)),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(durationLabel, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('$launches opens', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < apps.length - 1) const Divider(height: 1, color: Color(0xFF2A2D3A)),
            ],
          );
        }),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
