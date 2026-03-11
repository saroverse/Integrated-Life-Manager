import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../providers/habit_provider.dart';
import 'habit_detail_screen.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        backgroundColor: const Color(0xFF0F1117),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4F6EF7),
          labelColor: const Color(0xFF4F6EF7),
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: 'Today'), Tab(text: 'Stats')],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (_, __) => _tabController.index == 0
            ? FloatingActionButton(
                onPressed: () => _showAddHabitSheet(context, ref),
                backgroundColor: const Color(0xFF4F6EF7),
                child: const Icon(Icons.add),
              )
            : const SizedBox.shrink(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TodayTab(),
          _StatsTab(),
        ],
      ),
    );
  }

  Future<void> _showAddHabitSheet(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    String frequency = 'daily';
    String? selectedColor;
    const colors = ['#4F6EF7', '#2ECC71', '#E74C3C', '#F39C12', '#9B59B6', '#1ABC9C'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Habit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: iconCtrl,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(hintText: '🏋️', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'Habit name...', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: frequency,
                decoration: const InputDecoration(labelText: 'Frequency', border: OutlineInputBorder()),
                items: ['daily', 'weekdays', 'weekly']
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => frequency = v!),
              ),
              const SizedBox(height: 12),
              const Text('Color', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: colors.map((c) {
                  final color = Color(int.parse('FF${c.substring(1)}', radix: 16));
                  final selected = selectedColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => selectedColor = c),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected ? Border.all(color: Colors.white, width: 2) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.isEmpty) return;
                    await ApiService().createHabit({
                      'name': nameCtrl.text,
                      'frequency': frequency,
                      if (iconCtrl.text.isNotEmpty) 'icon': iconCtrl.text,
                      if (selectedColor != null) 'color': selectedColor,
                    });
                    ref.invalidate(habitsTodayProvider);
                    ref.invalidate(habitsStatsProvider(30));
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Create Habit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Today Tab ───────────────────────────────────────────────────────────────

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsTodayProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(habitsTodayProvider),
      child: habitsAsync.when(
        data: (habits) {
          final done = habits.where((h) => h['completed'] == true).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (habits.isNotEmpty) ...[
                _ProgressHeader(done: done, total: habits.length),
                const SizedBox(height: 16),
              ],
              ...habits.map((h) => _HabitCard(habit: h)),
              if (habits.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Text('No habits yet.\nTap + to create one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              const SizedBox(height: 80),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressHeader({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    final color = pct == 1.0
        ? const Color(0xFF2ECC71)
        : pct >= 0.5
            ? const Color(0xFF4F6EF7)
            : const Color(0xFFF39C12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Today: $done / $total',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text('${(pct * 100).round()}%',
                style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: const Color(0xFF2A2D3A),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _HabitCard extends ConsumerWidget {
  final Map<String, dynamic> habit;
  const _HabitCard({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = habit['completed'] as bool? ?? false;
    final accentHex = habit['color'] as String? ?? '#4F6EF7';
    final accent = Color(int.parse('FF${accentHex.substring(1)}', radix: 16));
    final streak = habit['current_streak'] as int? ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: habit['id'] as String),
          ),
        ),
        child: Row(
          children: [
            // Color accent bar
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Toggle circle
            GestureDetector(
              onTap: () => ref.read(habitLogProvider.notifier).toggle(
                    habit['id'] as String,
                    !completed,
                  ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: completed ? accent : const Color(0xFF1A1D27),
                  border: Border.all(
                    color: completed ? accent : const Color(0xFF2A2D3A),
                    width: 2,
                  ),
                ),
                child: completed
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Center(
                        child: Text(
                          habit['icon'] as String? ?? '○',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Name + category
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit['name'] as String,
                      style: TextStyle(
                        decoration: completed ? TextDecoration.lineThrough : null,
                        color: completed ? Colors.grey : Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (habit['category'] != null)
                      Text(habit['category'] as String,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            // Streak badge
            if (streak >= 1)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2D3A),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 2),
                      Text('$streak',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Tab ────────────────────────────────────────────────────────────────

class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(habitsStatsProvider(30));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(habitsStatsProvider(30)),
      child: statsAsync.when(
        data: (stats) {
          final summary = stats['summary'] as Map<String, dynamic>;
          final habits = stats['habits'] as List<dynamic>;
          final dailyTotals = stats['daily_totals'] as List<dynamic>;
          final last7 = dailyTotals.length >= 7
              ? dailyTotals.sublist(dailyTotals.length - 7)
              : dailyTotals;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCards(summary: summary),
              const SizedBox(height: 20),
              _WeekBarChart(days: last7),
              const SizedBox(height: 20),
              _HabitStreakList(habits: habits),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final todayDone = summary['today_completed'] as int? ?? 0;
    final todayTotal = summary['today_total'] as int? ?? 0;
    final weekRate = (summary['week_rate'] as num?)?.toDouble() ?? 0.0;
    final monthRate = (summary['month_rate'] as num?)?.toDouble() ?? 0.0;

    return Row(
      children: [
        _StatCard(
          label: 'Today',
          value: '$todayDone/$todayTotal',
          sub: 'habits done',
          color: todayTotal > 0 && todayDone == todayTotal
              ? const Color(0xFF2ECC71)
              : const Color(0xFF4F6EF7),
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'This Week',
          value: '${(weekRate * 100).round()}%',
          sub: 'completion',
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
          sub: 'completion',
          color: monthRate >= 0.8
              ? const Color(0xFF2ECC71)
              : monthRate >= 0.5
                  ? const Color(0xFF4F6EF7)
                  : const Color(0xFFF39C12),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(sub, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _WeekBarChart extends StatelessWidget {
  final List<dynamic> days;
  const _WeekBarChart({required this.days});

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LAST 7 DAYS',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                if (i >= days.length) {
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(height: 4, margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2D3A),
                              borderRadius: BorderRadius.circular(3),
                            )),
                        const SizedBox(height: 6),
                        Text(dayLabels[i], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  );
                }
                final day = days[i] as Map<String, dynamic>;
                final rate = (day['rate'] as num?)?.toDouble() ?? 0.0;
                final dateStr = day['date'] as String;
                final d = DateTime.tryParse(dateStr);
                final label = d != null ? dayLabels[d.weekday - 1] : '?';
                final barH = 4 + rate * 60;
                final isToday = dateStr == DateFormat('yyyy-MM-dd').format(DateTime.now());
                final barColor = isToday
                    ? const Color(0xFF4F6EF7)
                    : rate >= 0.8
                        ? const Color(0xFF2ECC71)
                        : rate >= 0.5
                            ? const Color(0xFF4F6EF7).withOpacity(0.7)
                            : const Color(0xFF2A2D3A);

                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (rate > 0)
                        Text('${(rate * 100).round()}%',
                            style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Container(
                        height: barH,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(label,
                          style: TextStyle(
                              fontSize: 11,
                              color: isToday ? const Color(0xFF4F6EF7) : Colors.grey,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                    ],
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

class _HabitStreakList extends StatelessWidget {
  final List<dynamic> habits;
  const _HabitStreakList({required this.habits});

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No habits yet', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final sorted = [...habits]..sort((a, b) =>
        (b['current_streak'] as int? ?? 0).compareTo(a['current_streak'] as int? ?? 0));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text('HABIT STREAKS',
                style: TextStyle(fontSize: 11, color: Colors.grey,
                    fontWeight: FontWeight.w600, letterSpacing: 1.2)),
          ),
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final h = entry.value as Map<String, dynamic>;
            return _HabitStatRow(habit: h, isLast: i == sorted.length - 1);
          }),
        ],
      ),
    );
  }
}

class _HabitStatRow extends StatelessWidget {
  final Map<String, dynamic> habit;
  final bool isLast;
  const _HabitStatRow({required this.habit, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final accentHex = habit['color'] as String? ?? '#4F6EF7';
    final accent = Color(int.parse('FF${accentHex.substring(1)}', radix: 16));
    final streak = habit['current_streak'] as int? ?? 0;
    final rate = (habit['completion_rate'] as num?)?.toDouble() ?? 0.0;
    final icon = habit['icon'] as String? ?? '○';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HabitDetailScreen(habitId: habit['id'] as String),
        ),
      ),
      child: Column(
        children: [
          if (!isLast)
            Divider(height: 1, color: Colors.white.withOpacity(0.05), indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: rate,
                          backgroundColor: const Color(0xFF2A2D3A),
                          valueColor: AlwaysStoppedAnimation(accent),
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 2),
                        Text('$streak',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    Text('${(rate * 100).round()}%',
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
