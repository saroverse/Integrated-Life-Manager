import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/habit_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardTodayProvider);
    final habitsAsync = ref.watch(habitsTodayProvider);
    final briefingAsync = ref.watch(latestBriefingProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardTodayProvider);
            ref.invalidate(habitsTodayProvider);
            ref.invalidate(latestBriefingProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Text(
                DateFormat('EEEE, MMMM d').format(DateTime.now()),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Good ${_timeGreeting()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Stats row
              dashboardAsync.when(
                data: (d) => _StatsRow(data: d),
                loading: () => const _StatsRowSkeleton(),
                error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
              ),

              const SizedBox(height: 16),

              // AI Briefing
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 16, color: Color(0xFF4F6EF7)),
                          const SizedBox(width: 8),
                          Text('Morning Briefing', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 12),
                      briefingAsync.when(
                        data: (b) => b != null
                            ? MarkdownBody(
                                data: b['content'] as String? ?? '',
                                styleSheet: MarkdownStyleSheet(
                                  p: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFB0B8CC)),
                                  h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  h3: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              )
                            : const Text(
                                'No briefing yet. The backend generates one at 7:00 AM.',
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                        loading: () => const CircularProgressIndicator.adaptive(),
                        error: (_, __) => const Text('Could not load briefing', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Today's Habits
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's Habits", style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      habitsAsync.when(
                        data: (habits) => habits.isEmpty
                            ? const Text('No habits set up yet.', style: TextStyle(color: Colors.grey))
                            : Column(
                                children: habits.map<Widget>((h) => _HabitTile(habit: h, ref: ref)).toList(),
                              ),
                        loading: () => const CircularProgressIndicator.adaptive(),
                        error: (_, __) => const Text('Could not load habits', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'morning';
    if (h < 17) return 'afternoon';
    return 'evening';
  }
}

class _StatsRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final steps = data['health']?['steps'] ?? 0;
    final sleep = data['health']?['sleep']?['total'];
    final habitsD = data['habits']?['completed'] ?? 0;
    final habitsT = data['habits']?['total'] ?? 0;
    final screen = data['screen_time']?['total_hours'] ?? 0.0;

    return Row(
      children: [
        _StatChip(label: 'Steps', value: _num(steps.toInt()), icon: Icons.directions_walk),
        const SizedBox(width: 8),
        _StatChip(label: 'Sleep', value: sleep != null ? '${sleep.toStringAsFixed(1)}h' : '—', icon: Icons.bedtime),
        const SizedBox(width: 8),
        _StatChip(label: 'Habits', value: '$habitsD/$habitsT', icon: Icons.check_circle_outline),
        const SizedBox(width: 8),
        _StatChip(label: 'Screen', value: '${(screen as double).toStringAsFixed(1)}h', icon: Icons.phone_android),
      ],
    );
  }

  String _num(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : n.toString();
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2D3A)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF4F6EF7)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  const _StatsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (_) => Expanded(
        child: Container(
          height: 70,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D27),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      )),
    );
  }
}

class _HabitTile extends StatelessWidget {
  final Map<String, dynamic> habit;
  final WidgetRef ref;
  const _HabitTile({required this.habit, required this.ref});

  @override
  Widget build(BuildContext context) {
    final completed = habit['completed'] as bool? ?? false;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: GestureDetector(
        onTap: () => ref.read(habitLogProvider.notifier).toggle(
              habit['id'] as String,
              !completed,
            ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? const Color(0xFF4F6EF7) : Colors.transparent,
            border: Border.all(
              color: completed ? const Color(0xFF4F6EF7) : Colors.grey.shade600,
              width: 2,
            ),
          ),
          child: completed
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : habit['icon'] != null
                  ? Center(child: Text(habit['icon'] as String, style: const TextStyle(fontSize: 16)))
                  : null,
        ),
      ),
      title: Text(
        habit['name'] as String,
        style: TextStyle(
          fontSize: 14,
          decoration: completed ? TextDecoration.lineThrough : null,
          color: completed ? Colors.grey : Colors.white,
        ),
      ),
      subtitle: habit['category'] != null
          ? Text(habit['category'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey))
          : null,
    );
  }
}
