import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/habit_provider.dart';
import '../../services/api_service.dart';

final _tasksProvider = FutureProvider<List<dynamic>>((ref) async {
  return ApiService().getTasks();
});

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(habitsStatsProvider(30));
    final tasksAsync = ref.watch(_tasksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1117),
        title: const Text('Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(habitsStatsProvider(30));
              ref.invalidate(_tasksProvider);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(habitsStatsProvider(30));
          ref.invalidate(_tasksProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // ── Habits ──────────────────────────────────────────────────────
            _SectionTitle(icon: Icons.repeat, label: 'Habits'),
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('$e', style: const TextStyle(color: Colors.red)),
              ),
              data: (stats) => _HabitsSection(stats: stats, ref: ref),
            ),

            const SizedBox(height: 8),

            // ── Tasks ────────────────────────────────────────────────────────
            _SectionTitle(icon: Icons.task_alt, label: 'Tasks'),
            tasksAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('$e', style: const TextStyle(color: Colors.red)),
              ),
              data: (tasks) => _TasksSection(tasks: List<Map<String, dynamic>>.from(tasks)),
            ),

            const SizedBox(height: 8),

            // ── Patterns ────────────────────────────────────────────────────
            _SectionTitle(icon: Icons.insights, label: 'Patterns'),
            statsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (stats) => _PatternsSection(stats: stats),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Habits Section ───────────────────────────────────────────────────────────

class _HabitsSection extends StatelessWidget {
  final Map<String, dynamic> stats;
  final WidgetRef ref;

  const _HabitsSection({required this.stats, required this.ref});

  @override
  Widget build(BuildContext context) {
    final summary = stats['summary'] as Map<String, dynamic>? ?? {};
    final habits = List<Map<String, dynamic>>.from(stats['habits'] ?? []);
    final dailyTotals = List<Map<String, dynamic>>.from(stats['daily_totals'] ?? []);

    final todayCompleted = summary['today_completed'] as int? ?? 0;
    final todayTotal = summary['today_total'] as int? ?? 0;
    final weekRate = (summary['week_rate'] as num?)?.toDouble() ?? 0.0;
    final monthRate = (summary['month_rate'] as num?)?.toDouble() ?? 0.0;
    final totalActive = summary['total_active'] as int? ?? 0;

    // Last 7 days from daily_totals
    final last7 = dailyTotals.length >= 7
        ? dailyTotals.sublist(dailyTotals.length - 7)
        : dailyTotals;

    // Top 5 by current streak
    final topStreaks = List<Map<String, dynamic>>.from(habits)
      ..sort((a, b) => (b['current_streak'] as int? ?? 0).compareTo(a['current_streak'] as int? ?? 0));
    final top5 = topStreaks.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _StatCard(
                label: 'Today',
                value: '$todayCompleted/$todayTotal',
                color: todayTotal > 0 && todayCompleted == todayTotal
                    ? const Color(0xFF2ECC71)
                    : const Color(0xFF4F6EF7),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'This Week',
                value: '${(weekRate * 100).round()}%',
                color: weekRate >= 0.8
                    ? const Color(0xFF2ECC71)
                    : weekRate >= 0.5
                        ? const Color(0xFF4F6EF7)
                        : const Color(0xFFF39C12),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'This Month',
                value: '${(monthRate * 100).round()}%',
                color: const Color(0xFF9B59B6),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Active',
                value: '$totalActive',
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 7-day chart
        if (last7.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SevenDayChart(days: last7),
          ),
          const SizedBox(height: 16),
        ],

        // Streak leaderboard
        if (top5.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Top Streaks',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
          ...top5.map((h) {
            final streak = h['current_streak'] as int? ?? 0;
            final rate = (h['completion_rate'] as num?)?.toDouble() ?? 0.0;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              color: const Color(0xFF1A1D27),
              child: ListTile(
                dense: true,
                leading: Text(h['icon'] as String? ?? '⭐', style: const TextStyle(fontSize: 20)),
                title: Text(h['name'] as String? ?? '', style: const TextStyle(fontSize: 14)),
                subtitle: Text('${(rate * 100).round()}% completion rate',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                trailing: streak > 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text('$streak', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      )
                    : const Text('—', style: TextStyle(color: Colors.grey)),
                onTap: () => context.push('/habits/${h['id']}'),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// ─── Tasks Section ────────────────────────────────────────────────────────────

class _TasksSection extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;

  const _TasksSection({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final weekAgo = now.subtract(const Duration(days: 7));

    final overdue = tasks.where((t) {
      final status = t['status'] as String?;
      final due = t['due_date'] as String?;
      return status != 'done' && due != null && due.compareTo(todayStr) < 0;
    }).length;

    final completedThisWeek = tasks.where((t) {
      final status = t['status'] as String?;
      final completedAt = t['completed_at'] as String?;
      if (status != 'done' || completedAt == null) return false;
      try {
        final d = DateTime.parse(completedAt);
        return d.isAfter(weekAgo);
      } catch (_) {
        return false;
      }
    }).length;

    final dueToday = tasks.where((t) {
      final status = t['status'] as String?;
      final due = t['due_date'] as String?;
      return status != 'done' && due == todayStr;
    }).length;

    // Priority breakdown (pending tasks)
    final pending = tasks.where((t) => t['status'] != 'done').toList();
    final priorities = {'low': 0, 'medium': 0, 'high': 0, 'urgent': 0};
    for (final t in pending) {
      final p = t['priority'] as String? ?? 'medium';
      priorities[p] = (priorities[p] ?? 0) + 1;
    }
    final total = pending.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatCard(
                label: 'Done this week',
                value: '$completedThisWeek',
                color: const Color(0xFF2ECC71),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Due today',
                value: '$dueToday',
                color: const Color(0xFF4F6EF7),
              ),
              const SizedBox(width: 10),
              _StatCard(
                label: 'Overdue',
                value: '$overdue',
                color: overdue > 0 ? const Color(0xFFE74C3C) : Colors.grey.shade600,
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 16),
            Text('Priority breakdown  ($total pending)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 10),
            _PriorityBreakdown(priorities: priorities, total: total),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PriorityBreakdown extends StatelessWidget {
  final Map<String, int> priorities;
  final int total;

  const _PriorityBreakdown({required this.priorities, required this.total});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('urgent', 'Urgent', Color(0xFFE74C3C)),
      ('high', 'High', Color(0xFFF39C12)),
      ('medium', 'Medium', Color(0xFF4F6EF7)),
      ('low', 'Low', Color(0xFF7F8C8D)),
    ];

    return Column(
      children: items.map((item) {
        final (key, label, color) = item;
        final count = priorities[key] ?? 0;
        final frac = total > 0 ? count / total : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 8,
                    backgroundColor: const Color(0xFF2A2D3A),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text('$count',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Patterns Section ─────────────────────────────────────────────────────────

class _PatternsSection extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _PatternsSection({required this.stats});

  @override
  Widget build(BuildContext context) {
    final dailyTotals = List<Map<String, dynamic>>.from(stats['daily_totals'] ?? []);

    // Compute per-weekday completion rates from daily_totals
    final weekdayCompleted = List<double>.filled(7, 0);
    final weekdayScheduled = List<double>.filled(7, 0);

    for (final d in dailyTotals) {
      try {
        final dateStr = d['date'] as String;
        final date = DateTime.parse(dateStr);
        final wd = (date.weekday - 1) % 7; // 0=Mon, 6=Sun
        weekdayCompleted[wd] += (d['completed'] as num?)?.toDouble() ?? 0;
        weekdayScheduled[wd] += (d['scheduled'] as num?)?.toDouble() ?? 0;
      } catch (_) {}
    }

    final weekdayRates = List.generate(7, (i) {
      final s = weekdayScheduled[i];
      return s > 0 ? weekdayCompleted[i] / s : 0.0;
    });

    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now();
    final todayWd = (today.weekday - 1) % 7;

    // Best day
    int bestDayIdx = 0;
    double bestRate = 0;
    for (int i = 0; i < 7; i++) {
      if (weekdayRates[i] > bestRate && weekdayScheduled[i] > 0) {
        bestRate = weekdayRates[i];
        bestDayIdx = i;
      }
    }
    const fullDayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bestRate > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF4F6EF7).withOpacity(0.15),
                    const Color(0xFF4F6EF7).withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4F6EF7).withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFF39C12), size: 22),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Best day', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      Text(
                        '${fullDayNames[bestDayIdx]}  ${(bestRate * 100).round()}%',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          Text('Completion by weekday',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          const SizedBox(height: 12),

          // Weekday bars
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final rate = weekdayRates[i];
                final isToday = i == todayWd;
                final color = isToday
                    ? const Color(0xFF4F6EF7)
                    : rate >= 0.8
                        ? const Color(0xFF2ECC71)
                        : rate >= 0.5
                            ? const Color(0xFF4F6EF7).withOpacity(0.6)
                            : Colors.grey.shade700;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 6 ? 5 : 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (weekdayScheduled[i] > 0)
                          Text(
                            '${(rate * 100).round()}%',
                            style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                          ),
                        const SizedBox(height: 2),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: double.infinity,
                              height: weekdayScheduled[i] > 0 ? (rate * 70).clamp(4, 70) : 4,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(dayLabels[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: isToday ? const Color(0xFF4F6EF7) : Colors.grey,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            )),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 7-Day Chart ──────────────────────────────────────────────────────────────

class _SevenDayChart extends StatelessWidget {
  final List<Map<String, dynamic>> days;

  const _SevenDayChart({required this.days});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Last 7 days',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((d) {
              final rate = (d['rate'] as num?)?.toDouble() ?? 0.0;
              final dateStr = d['date'] as String? ?? '';
              final label = dateStr.isNotEmpty ? _dayLabel(dateStr) : '';
              final color = rate >= 0.8
                  ? const Color(0xFF2ECC71)
                  : rate >= 0.5
                      ? const Color(0xFF4F6EF7)
                      : Colors.grey.shade700;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            height: (rate * 54).clamp(4, 54),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _dayLabel(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return labels[(d.weekday - 1) % 7];
    } catch (_) {
      return '';
    }
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF4F6EF7)),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4F6EF7),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: const Color(0xFF2A2D3A))),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
