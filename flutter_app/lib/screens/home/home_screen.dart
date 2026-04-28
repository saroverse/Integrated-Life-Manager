import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/habit_provider.dart';
import '../../services/api_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _briefingExpanded = false;

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardTodayProvider);
    final habitsAsync = ref.watch(habitsTodayProvider);
    final briefingAsync = ref.watch(latestBriefingProvider);
    final tasksAsync = ref.watch(tasksTodayProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardTodayProvider);
            ref.invalidate(habitsTodayProvider);
            ref.invalidate(latestBriefingProvider);
            ref.invalidate(tasksTodayProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d').format(DateTime.now()),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Good ${_timeGreeting()}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, size: 22),
                    onPressed: () => context.push('/chat'),
                    tooltip: 'AI Assistant',
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Stats row
              dashboardAsync.when(
                data: (d) => _StatsRow(data: d),
                loading: () => const _StatsRowSkeleton(),
                error: (e, _) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // AI Briefing — collapsible
              briefingAsync.when(
                data: (b) => b != null ? _BriefingCard(
                  content: b['content'] as String? ?? '',
                  expanded: _briefingExpanded,
                  onToggle: () => setState(() => _briefingExpanded = !_briefingExpanded),
                ) : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // Today's Tasks
              tasksAsync.when(
                data: (tasks) {
                  final pending = tasks.where((t) =>
                    (t['status'] as String?) != 'done'
                  ).toList();
                  if (pending.isEmpty) return const SizedBox.shrink();
                  return _SectionCard(
                    title: "Today's Tasks",
                    trailing: TextButton(
                      onPressed: () => context.push('/tasks/add'),
                      child: const Text('+ Add'),
                    ),
                    child: Column(
                      children: pending.map<Widget>((t) => _TaskTile(
                        task: t,
                        onComplete: () async {
                          await ApiService().completeTask(t['id'] as String);
                          ref.invalidate(tasksTodayProvider);
                          ref.invalidate(dashboardTodayProvider);
                        },
                      )).toList(),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              const SizedBox(height: 16),

              // Today's Habits
              habitsAsync.when(
                data: (habits) {
                  if (habits.isEmpty) return const SizedBox.shrink();
                  final done = habits.where((h) => h['completed'] as bool? ?? false).length;
                  return _SectionCard(
                    title: "Today's Habits",
                    trailing: Text(
                      '$done/${habits.length}',
                      style: TextStyle(
                        color: done == habits.length ? const Color(0xFF4F6EF7) : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    child: Column(
                      children: habits.map<Widget>((h) => _HabitTile(habit: h, ref: ref)).toList(),
                    ),
                  );
                },
                loading: () => const _SectionSkeleton(height: 120),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat'),
        backgroundColor: const Color(0xFF4F6EF7),
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Ask AI'),
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

// ── Shared section card ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  const _SectionCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Briefing card (collapsible) ──────────────────────────────────────────────

class _BriefingCard extends StatelessWidget {
  final String content;
  final bool expanded;
  final VoidCallback onToggle;
  const _BriefingCard({required this.content, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    // Show first ~120 chars as preview
    final preview = content.length > 120 ? '${content.substring(0, 120)}…' : content;

    return Card(
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 15, color: Color(0xFF4F6EF7)),
                  const SizedBox(width: 8),
                  Text('Morning Briefing', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedCrossFade(
                firstChild: Text(
                  preview,
                  style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFB0B8CC)),
                ),
                secondChild: MarkdownBody(
                  data: content,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFB0B8CC)),
                    h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    h3: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Task tile ────────────────────────────────────────────────────────────────

class _TaskTile extends StatefulWidget {
  final Map<String, dynamic> task;
  final VoidCallback onComplete;
  const _TaskTile({required this.task, required this.onComplete});

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile> {
  bool _completing = false;

  Color _priorityColor(String? p) {
    switch (p) {
      case 'high': return const Color(0xFFE05252);
      case 'medium': return const Color(0xFFF0A500);
      default: return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final priority = widget.task['priority'] as String?;
    final title = widget.task['title'] as String? ?? '';
    final dueTime = widget.task['due_time'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: _priorityColor(priority),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                if (dueTime != null)
                  Text(dueTime, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          if (_completing)
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            GestureDetector(
              onTap: () async {
                setState(() => _completing = true);
                widget.onComplete();
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade600, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Habit tile ───────────────────────────────────────────────────────────────

class _HabitTile extends StatelessWidget {
  final Map<String, dynamic> habit;
  final WidgetRef ref;
  const _HabitTile({required this.habit, required this.ref});

  @override
  Widget build(BuildContext context) {
    final completed = habit['completed'] as bool? ?? false;
    final id = habit['id'] as String;

    return InkWell(
      onTap: () => ref.read(habitLogProvider.notifier).toggle(id, !completed),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? const Color(0xFF4F6EF7) : Colors.transparent,
                border: Border.all(
                  color: completed ? const Color(0xFF4F6EF7) : Colors.grey.shade600,
                  width: 2,
                ),
              ),
              child: completed
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : habit['icon'] != null
                      ? Center(child: Text(habit['icon'] as String, style: const TextStyle(fontSize: 14)))
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                habit['name'] as String,
                style: TextStyle(
                  fontSize: 14,
                  decoration: completed ? TextDecoration.lineThrough : null,
                  color: completed ? Colors.grey : Colors.white,
                ),
              ),
            ),
            if (habit['category'] != null)
              Text(
                habit['category'] as String,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Stats row ────────────────────────────────────────────────────────────────

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
        _StatChip(label: 'Steps', value: _num((steps as num).toInt()), icon: Icons.directions_walk),
        const SizedBox(width: 8),
        _StatChip(label: 'Sleep', value: sleep != null ? '${(sleep as num).toStringAsFixed(1)}h' : '—', icon: Icons.bedtime),
        const SizedBox(width: 8),
        _StatChip(label: 'Habits', value: '$habitsD/$habitsT', icon: Icons.check_circle_outline),
        const SizedBox(width: 8),
        _StatChip(
          label: 'Screen',
          value: '${(screen as double).toStringAsFixed(1)}h',
          icon: Icons.phone_android,
          onTap: () => context.push('/screen-time'),
        ),
      ],
    );
  }

  String _num(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : n.toString();
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  const _StatChip({required this.label, required this.value, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D27),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: onTap != null ? const Color(0xFF3A3D4A) : const Color(0xFF2A2D3A),
            ),
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

class _SectionSkeleton extends StatelessWidget {
  final double height;
  const _SectionSkeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
