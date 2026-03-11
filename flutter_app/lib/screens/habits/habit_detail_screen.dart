import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/habit_provider.dart';
import '../../services/api_service.dart';

class HabitDetailScreen extends ConsumerWidget {
  final String habitId;
  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarAsync = ref.watch(habitCalendarProvider(habitId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: calendarAsync.when(
        data: (data) => _DetailBody(data: data, habitId: habitId),
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final Map<String, dynamic> data;
  final String habitId;
  const _DetailBody({required this.data, required this.habitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = data['habit'] as Map<String, dynamic>;
    final stats = data['stats'] as Map<String, dynamic>;
    final days = data['days'] as List<dynamic>;

    final accentHex = habit['color'] as String? ?? '#4F6EF7';
    final accent = Color(int.parse('FF${accentHex.substring(1)}', radix: 16));
    final icon = habit['icon'] as String? ?? '○';
    final name = habit['name'] as String;

    final currentStreak = stats['current_streak'] as int? ?? 0;
    final longestStreak = stats['longest_streak'] as int? ?? 0;
    final totalCompletions = stats['total_completions'] as int? ?? 0;
    final weekdayRates = (stats['weekday_rates'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        List.filled(7, 0.0);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: const Color(0xFF1A1D27),
          expandedHeight: 120,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          flexibleSpace: FlexibleSpaceBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
            centerTitle: false,
            titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: Container(height: 3, color: accent),
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'archive') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1D27),
                      title: const Text('Archive habit?'),
                      content: Text('Archive "$name"? It will no longer appear in your daily list.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Archive', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await ApiService().deleteHabit(habitId);
                    ref.invalidate(habitsTodayProvider);
                    ref.invalidate(habitsStatsProvider(30));
                    if (context.mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'archive', child: Text('Archive habit')),
              ],
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Streak stats row
                _StatsRow(
                  current: currentStreak,
                  longest: longestStreak,
                  total: totalCompletions,
                  accent: accent,
                ),
                const SizedBox(height: 24),
                // Heatmap
                _SectionTitle(title: 'COMPLETION HEATMAP', subtitle: 'Last 90 days'),
                const SizedBox(height: 12),
                _HeatmapGrid(days: days, accent: accent),
                const SizedBox(height: 8),
                // Legend
                Row(
                  children: [
                    _LegendDot(color: accent, label: 'Completed'),
                    const SizedBox(width: 16),
                    _LegendDot(color: const Color(0xFF2A2D3A), label: 'Missed'),
                    const SizedBox(width: 16),
                    _LegendDot(color: Colors.transparent, label: 'Not scheduled', border: true),
                  ],
                ),
                const SizedBox(height: 24),
                // Weekday breakdown
                _SectionTitle(title: 'WEEKDAY BREAKDOWN', subtitle: 'Completion rate per day'),
                const SizedBox(height: 12),
                _WeekdayChart(rates: weekdayRates, accent: accent),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int current;
  final int longest;
  final int total;
  final Color accent;
  const _StatsRow({required this.current, required this.longest, required this.total, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(icon: '🔥', value: '$current', label: 'current streak', color: accent),
        const SizedBox(width: 10),
        _StatChip(icon: '⭐', value: '$longest', label: 'best streak', color: const Color(0xFFF39C12)),
        const SizedBox(width: 10),
        _StatChip(icon: '✓', value: '$total', label: 'total', color: const Color(0xFF2ECC71)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600, letterSpacing: 1.2)),
        const Spacer(),
        Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  final List<dynamic> days;
  final Color accent;
  const _HeatmapGrid({required this.days, required this.accent});

  @override
  Widget build(BuildContext context) {
    // Pad to start on Monday
    final firstDate = days.isNotEmpty ? DateTime.parse((days.first as Map)['date'] as String) : DateTime.now();
    final leadingPad = (firstDate.weekday - 1) % 7; // 0=Mon

    final totalCells = leadingPad + days.length;
    final rows = (totalCells / 7).ceil();
    final cellSize = (MediaQuery.of(context).size.width - 32 - 6 * 2.0) / 7;

    return SizedBox(
      height: rows * (cellSize + 2),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: rows * 7,
        itemBuilder: (_, idx) {
          final dayIdx = idx - leadingPad;
          if (dayIdx < 0 || dayIdx >= days.length) {
            return const SizedBox();
          }
          final day = days[dayIdx] as Map<String, dynamic>;
          final scheduled = day['scheduled'] as bool? ?? false;
          final completed = day['completed'] as bool? ?? false;

          Color cellColor;
          if (!scheduled) {
            cellColor = Colors.transparent;
          } else if (completed) {
            cellColor = accent;
          } else {
            cellColor = const Color(0xFF2A2D3A);
          }

          return Container(
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(2),
              border: !scheduled
                  ? Border.all(color: Colors.white.withOpacity(0.04), width: 0.5)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _WeekdayChart extends StatelessWidget {
  final List<double> rates;
  final Color accent;
  const _WeekdayChart({required this.rates, required this.accent});

  @override
  Widget build(BuildContext context) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday - 1; // 0=Mon

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        height: 100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(7, (i) {
            final rate = i < rates.length ? rates[i] : 0.0;
            final barH = 4.0 + rate * 72;
            final isToday = i == today;
            final barColor = isToday ? accent : accent.withOpacity(0.5 + rate * 0.5);

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${(rate * 100).round()}%',
                      style: TextStyle(fontSize: 9, color: rate > 0 ? Colors.grey : Colors.transparent)),
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
                  Text(labels[i],
                      style: TextStyle(
                          fontSize: 10,
                          color: isToday ? accent : Colors.grey,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool border;
  const _LegendDot({required this.color, required this.label, this.border = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: border ? Border.all(color: Colors.white24) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
