import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/planner_provider.dart';
import '../../services/api_service.dart';

enum _PlannerView { day, week, month }

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  _PlannerView _view = _PlannerView.day;
  DateTime _selectedDate = DateTime.now();

  DateTime get _weekStart {
    final d = _selectedDate;
    return d.subtract(Duration(days: d.weekday - 1));
  }

  void _prevPage() => setState(() {
        if (_view == _PlannerView.day) {
          _selectedDate = _selectedDate.subtract(const Duration(days: 1));
        } else if (_view == _PlannerView.week) {
          _selectedDate = _selectedDate.subtract(const Duration(days: 7));
        } else {
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
        }
      });

  void _nextPage() => setState(() {
        if (_view == _PlannerView.day) {
          _selectedDate = _selectedDate.add(const Duration(days: 1));
        } else if (_view == _PlannerView.week) {
          _selectedDate = _selectedDate.add(const Duration(days: 7));
        } else {
          _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
        }
      });

  void _goToDate(DateTime d) => _showDayPreviewSheet(d);

  void _showDayPreviewSheet(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => _DayPreviewSheet(
          date: date,
          ref: ref,
          scrollController: scrollCtrl,
          onRefresh: _refresh,
        ),
      ),
    );
  }

  void _refresh() {
    ref.invalidate(plannerDayProvider);
    ref.invalidate(plannerWeekProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1117),
        title: const Text('Planner'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _ViewToggle(current: _view, onChanged: (v) => setState(() => _view = v)),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        backgroundColor: const Color(0xFF4F6EF7),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: switch (_view) {
        _PlannerView.day => _DayView(
            date: _selectedDate,
            onPrev: _prevPage,
            onNext: _nextPage,
            onRefresh: _refresh,
            ref: ref,
          ),
        _PlannerView.week => _WeekView(
            weekStart: _weekStart,
            selectedDate: _selectedDate,
            onPrev: _prevPage,
            onNext: _nextPage,
            onDayTap: _goToDate,
            ref: ref,
          ),
        _PlannerView.month => _MonthView(
            month: _selectedDate,
            selectedDate: _selectedDate,
            onPrev: _prevPage,
            onNext: _nextPage,
            onDayTap: _goToDate,
            ref: ref,
          ),
      },
    );
  }

  Future<void> _showAddSheet(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.task_alt, color: Color(0xFF4F6EF7)),
              title: const Text('Add Task'),
              subtitle: const Text('Create a guided task', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(context, 'task'),
            ),
            ListTile(
              leading: const Icon(Icons.event, color: Color(0xFF4F6EF7)),
              title: const Text('Add Event'),
              subtitle: const Text('Schedule a calendar event', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(context, 'event'),
            ),
            ListTile(
              leading: const Icon(Icons.repeat, color: Color(0xFF4F6EF7)),
              title: const Text('Add Habit'),
              subtitle: const Text('Build a recurring routine', style: TextStyle(fontSize: 12)),
              onTap: () => Navigator.pop(context, 'habit'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'task') {
      context.push('/tasks/add');
    } else if (choice == 'event') {
      await _showAddEventSheet(context);
    } else if (choice == 'habit') {
      context.push('/habits/add');
    }
  }

  Future<void> _showAddEventSheet(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    DateTime startDate = _selectedDate;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    String color = '#4F6EF7';

    const colors = [
      '#4F6EF7', '#E74C3C', '#27AE60', '#E67E22', '#9B59B6', '#16A085',
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('New Event', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Event title…', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: const InputDecoration(hintText: 'Location (optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.place, size: 18)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('MMM d').format(startDate)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: startDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                        );
                        if (picked != null) setS(() => startDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text('${startTime.format(ctx)} – ${endTime.format(ctx)}'),
                      onPressed: () async {
                        final s = await showTimePicker(context: ctx, initialTime: startTime);
                        if (s == null) return;
                        final e = await showTimePicker(context: ctx, initialTime: endTime);
                        if (e != null) setS(() { startTime = s; endTime = e; });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Color: ', style: TextStyle(color: Colors.grey)),
                  ...colors.map((c) {
                    final hex = int.parse(c.substring(1), radix: 16) | 0xFF000000;
                    return GestureDetector(
                      onTap: () => setS(() => color = c),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(hex),
                          shape: BoxShape.circle,
                          border: color == c ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final fmt = DateFormat('yyyy-MM-dd');
                    final timeFmt = (TimeOfDay t) =>
                        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                    await ApiService().createEvent({
                      'title': titleCtrl.text.trim(),
                      if (locationCtrl.text.trim().isNotEmpty) 'location': locationCtrl.text.trim(),
                      'start_date': fmt.format(startDate),
                      'start_time': timeFmt(startTime),
                      'end_date': fmt.format(startDate),
                      'end_time': timeFmt(endTime),
                      'color': color,
                    });
                    _refresh();
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Create Event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── View Toggle ─────────────────────────────────────────────────────────────

class _ViewToggle extends StatelessWidget {
  final _PlannerView current;
  final void Function(_PlannerView) onChanged;

  const _ViewToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const views = [_PlannerView.day, _PlannerView.week, _PlannerView.month];
    const labels = ['Day', 'Week', 'Month'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final selected = current == views[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(views[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF4F6EF7) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Day View ─────────────────────────────────────────────────────────────────

class _DayView extends ConsumerWidget {
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onRefresh;
  final WidgetRef ref;

  const _DayView({
    required this.date,
    required this.onPrev,
    required this.onNext,
    required this.onRefresh,
    required this.ref,
  });

  bool get _isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayAsync = ref.watch(plannerDayProvider(dateStr));

    return Column(
      children: [
        // Day header navigation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    // tap to go to today
                  },
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEEE').format(date),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        DateFormat('d MMMM yyyy').format(date),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _isToday ? const Color(0xFF4F6EF7) : Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
            ],
          ),
        ),

        // Content
        Expanded(
          child: dayAsync.when(
            loading: () => const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
            data: (data) => _DayContent(data: data, date: date, isToday: _isToday, onRefresh: onRefresh, ref: ref),
          ),
        ),
      ],
    );
  }
}

class _DayContent extends StatelessWidget {
  final Map<String, dynamic> data;
  final DateTime date;
  final bool isToday;
  final VoidCallback onRefresh;
  final WidgetRef ref;

  const _DayContent({
    required this.data,
    required this.date,
    required this.isToday,
    required this.onRefresh,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
    final overdue = List<Map<String, dynamic>>.from(data['overdue_tasks'] ?? []);
    final habits = List<Map<String, dynamic>>.from(data['habits'] ?? []);
    final events = List<Map<String, dynamic>>.from(data['events'] ?? []);

    // Split tasks into timed and all-day
    final timedTasks = tasks.where((t) => t['due_time'] != null).toList();
    final allDayTasks = tasks.where((t) => t['due_time'] == null).toList();

    // Split events into timed and all-day
    final timedEvents = events.where((e) => e['start_time'] != null).toList();
    final allDayEvents = events.where((e) => e['start_time'] == null).toList();

    // Build time-bucketed items
    List<Map<String, dynamic>> morningItems = [];
    List<Map<String, dynamic>> afternoonItems = [];
    List<Map<String, dynamic>> eveningItems = [];

    for (final t in timedTasks) {
      final slot = _timeSlot(t['due_time'] as String);
      if (slot == 0) morningItems.add({'type': 'task', 'data': t});
      else if (slot == 1) afternoonItems.add({'type': 'task', 'data': t});
      else eveningItems.add({'type': 'task', 'data': t});
    }
    for (final e in timedEvents) {
      final slot = _timeSlot(e['start_time'] as String);
      if (slot == 0) morningItems.add({'type': 'event', 'data': e});
      else if (slot == 1) afternoonItems.add({'type': 'event', 'data': e});
      else eveningItems.add({'type': 'event', 'data': e});
    }

    // Sort each bucket by time
    _sortByTime(morningItems);
    _sortByTime(afternoonItems);
    _sortByTime(eveningItems);

    final now = TimeOfDay.now();
    final currentSlot = _timeSlot('${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        // NOW card
        if (isToday) _NowCard(data: data),

        // Overdue
        if (overdue.isNotEmpty) ...[
          _SectionHeader(title: 'OVERDUE', color: Colors.red.shade400, badge: overdue.length),
          ...overdue.map((t) => _TaskTile(task: t, onComplete: () async {
            await ApiService().completeTask(t['id'] as String);
            onRefresh();
          }, onDelete: () async {
            await ApiService().deleteTask(t['id'] as String);
            onRefresh();
          })),
        ],

        // All day
        if (allDayTasks.isNotEmpty || allDayEvents.isNotEmpty) ...[
          _SectionHeader(title: 'ALL DAY', color: Colors.grey.shade400),
          ...allDayEvents.map((e) => _EventTile(event: e, onDelete: () async {
            await ApiService().deleteEvent(e['id'] as String);
            onRefresh();
          })),
          ...allDayTasks.map((t) => _TaskTile(task: t, onComplete: () async {
            await ApiService().completeTask(t['id'] as String);
            onRefresh();
          }, onDelete: () async {
            await ApiService().deleteTask(t['id'] as String);
            onRefresh();
          })),
        ],

        // Morning
        if (morningItems.isNotEmpty || (isToday && currentSlot == 0)) ...[
          _SectionHeader(
            title: 'MORNING  6 AM – 12 PM',
            color: Colors.amber.shade600,
            dimmed: isToday && currentSlot > 0,
          ),
          ..._buildTimedItems(morningItems, context, onRefresh),
        ],

        // Afternoon
        if (afternoonItems.isNotEmpty || (isToday && currentSlot == 1)) ...[
          _SectionHeader(
            title: 'AFTERNOON  12 PM – 6 PM',
            color: Colors.orange.shade400,
            highlight: isToday && currentSlot == 1,
            dimmed: isToday && currentSlot > 1,
          ),
          ..._buildTimedItems(afternoonItems, context, onRefresh),
        ],

        // Evening
        if (eveningItems.isNotEmpty || (isToday && currentSlot >= 2)) ...[
          _SectionHeader(
            title: 'EVENING  6 PM – 11 PM',
            color: Colors.deepPurple.shade300,
            highlight: isToday && currentSlot == 2,
          ),
          ..._buildTimedItems(eveningItems, context, onRefresh),
        ],

        // Habits
        if (habits.isNotEmpty) ...[
          _SectionHeader(title: 'HABITS', color: const Color(0xFF4F6EF7)),
          ...habits.map((h) => _HabitTile(
            habit: h,
            date: DateFormat('yyyy-MM-dd').format(date),
            onToggle: () => onRefresh(),
          )),
        ],

        // Empty state
        if (overdue.isEmpty && allDayTasks.isEmpty && allDayEvents.isEmpty &&
            morningItems.isEmpty && afternoonItems.isEmpty && eveningItems.isEmpty && habits.isEmpty)
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(children: [
              Icon(Icons.wb_sunny_outlined, size: 48, color: Colors.grey.shade700),
              const SizedBox(height: 12),
              Text('Nothing scheduled', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Tap + to add a task or event', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            ]),
          ),
      ],
    );
  }

  int _timeSlot(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    if (hour < 12) return 0;
    if (hour < 18) return 1;
    return 2;
  }

  void _sortByTime(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      final ta = a['type'] == 'task' ? (a['data']['due_time'] as String?) : (a['data']['start_time'] as String?);
      final tb = b['type'] == 'task' ? (b['data']['due_time'] as String?) : (b['data']['start_time'] as String?);
      return (ta ?? '').compareTo(tb ?? '');
    });
  }

  List<Widget> _buildTimedItems(
    List<Map<String, dynamic>> items,
    BuildContext context,
    VoidCallback onRefresh,
  ) {
    return items.map((item) {
      if (item['type'] == 'task') {
        return _TaskTile(
          task: item['data'] as Map<String, dynamic>,
          onComplete: () async {
            await ApiService().completeTask((item['data'] as Map)['id'] as String);
            onRefresh();
          },
          onDelete: () async {
            await ApiService().deleteTask((item['data'] as Map)['id'] as String);
            onRefresh();
          },
        );
      } else {
        return _EventTile(
          event: item['data'] as Map<String, dynamic>,
          onDelete: () async {
            await ApiService().deleteEvent((item['data'] as Map)['id'] as String);
            onRefresh();
          },
        );
      }
    }).toList();
  }
}

// ─── Now Card ─────────────────────────────────────────────────────────────────

class _NowCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _NowCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Find next upcoming item
    String? nextItem;
    final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
    final events = List<Map<String, dynamic>>.from(data['events'] ?? []);
    final nowMinutes = now.hour * 60 + now.minute;

    int bestDiff = 99999;
    for (final t in tasks) {
      if (t['due_time'] == null) continue;
      final parts = (t['due_time'] as String).split(':');
      final mins = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      final diff = mins - nowMinutes;
      if (diff >= 0 && diff < bestDiff) {
        bestDiff = diff;
        nextItem = '${t['title']} in ${diff}min';
      }
    }
    for (final e in events) {
      if (e['start_time'] == null) continue;
      final parts = (e['start_time'] as String).split(':');
      final mins = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      final diff = mins - nowMinutes;
      if (diff >= 0 && diff < bestDiff) {
        bestDiff = diff;
        nextItem = '${e['title']} in ${diff}min';
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF4F6EF7).withOpacity(0.2), const Color(0xFF4F6EF7).withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F6EF7).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(color: Color(0xFF4F6EF7), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Now — $timeStr', style: const TextStyle(color: Color(0xFF4F6EF7), fontSize: 12, fontWeight: FontWeight.bold)),
                if (nextItem != null)
                  Text('Next: $nextItem', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                if (nextItem == null)
                  Text('Nothing scheduled next', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final int? badge;
  final bool dimmed;
  final bool highlight;

  const _SectionHeader({
    required this.title,
    required this.color,
    this.badge,
    this.dimmed = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: highlight ? Border.all(color: color.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Container(width: 3, height: 14, color: dimmed ? color.withOpacity(0.3) : color,
              margin: const EdgeInsets.only(right: 8)),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: dimmed ? color.withOpacity(0.4) : color,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: Text('$badge', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Task Tile ────────────────────────────────────────────────────────────────

class _TaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onComplete;
  final VoidCallback onDelete;

  const _TaskTile({required this.task, required this.onComplete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final priority = task['priority'] as String? ?? 'medium';
    final priorityColor = switch (priority) {
      'urgent' => Colors.red.shade400,
      'high' => Colors.orange.shade400,
      'medium' => const Color(0xFF4F6EF7),
      _ => Colors.grey.shade600,
    };
    final dueTime = task['due_time'] as String?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      color: const Color(0xFF1A1D27),
      child: ListTile(
        dense: true,
        leading: GestureDetector(
          onTap: onComplete,
          child: Icon(Icons.radio_button_unchecked, color: priorityColor, size: 22),
        ),
        title: Text(task['title'] as String, style: const TextStyle(fontSize: 14)),
        subtitle: dueTime != null ? Text(dueTime, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: priorityColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
              child: Text(priority, style: TextStyle(fontSize: 9, color: priorityColor)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: onDelete,
              color: Colors.grey.shade700,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Event Tile ───────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onDelete;

  const _EventTile({required this.event, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colorHex = event['color'] as String? ?? '#4F6EF7';
    final color = Color(int.parse(colorHex.substring(1), radix: 16) | 0xFF000000);
    final start = event['start_time'] as String?;
    final end = event['end_time'] as String?;
    final location = event['location'] as String?;
    final timeStr = (start != null && end != null) ? '$start – $end' : start;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      color: const Color(0xFF1A1D27),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, color: color, margin: const EdgeInsets.only(left: 8)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event['title'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          if (timeStr != null)
                            Text(timeStr, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
                          if (location != null)
                            Text(location, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16),
                      onPressed: onDelete,
                      color: Colors.grey.shade700,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
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

// ─── Habit Tile ───────────────────────────────────────────────────────────────

class _HabitTile extends StatefulWidget {
  final Map<String, dynamic> habit;
  final String date;
  final VoidCallback onToggle;

  const _HabitTile({required this.habit, required this.date, required this.onToggle});

  @override
  State<_HabitTile> createState() => _HabitTileState();
}

class _HabitTileState extends State<_HabitTile> {
  late bool _completed;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _completed = widget.habit['completed'] as bool? ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final frequency = widget.habit['frequency'] as String?;
    final weekCount = widget.habit['week_count'] as int?;
    final frequencyCount = widget.habit['frequency_count'] as int?;
    final frequencyInterval = widget.habit['frequency_interval'] as int?;

    String? subtitle;
    if (frequency == 'x_per_week' && frequencyCount != null) {
      final done = weekCount ?? 0;
      subtitle = '$done/$frequencyCount this week';
    } else if (frequency == 'interval' && frequencyInterval != null) {
      subtitle = 'Every $frequencyInterval days';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      color: const Color(0xFF1A1D27),
      child: ListTile(
        dense: true,
        leading: Text(widget.habit['icon'] as String? ?? '✓', style: const TextStyle(fontSize: 20)),
        title: Text(widget.habit['name'] as String, style: const TextStyle(fontSize: 14)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: (frequency == 'x_per_week' && weekCount != null && frequencyCount != null && weekCount >= frequencyCount)
                      ? const Color(0xFF27AE60)
                      : Colors.grey,
                ))
            : null,
        trailing: _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
            : GestureDetector(
                onTap: () async {
                  setState(() => _loading = true);
                  try {
                    await ApiService().logHabit(widget.habit['id'] as String, {
                      'date': widget.date,
                      'completed': !_completed,
                      'count': 1,
                    });
                    setState(() => _completed = !_completed);
                    widget.onToggle();
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: Icon(
                  _completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _completed ? const Color(0xFF27AE60) : Colors.grey,
                  size: 24,
                ),
              ),
      ),
    );
  }
}

// ─── Day Preview Sheet (shown on day-tap in week/month view) ─────────────────

class _DayPreviewSheet extends StatelessWidget {
  final DateTime date;
  final WidgetRef ref;
  final ScrollController scrollController;
  final VoidCallback onRefresh;

  const _DayPreviewSheet({
    required this.date,
    required this.ref,
    required this.scrollController,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final dayAsync = ref.watch(plannerDayProvider(dateStr));
    final today = DateTime.now();
    final isToday = date.year == today.year && date.month == today.month && date.day == today.day;

    return Column(
      children: [
        // Handle
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE').format(date),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Text(
                    DateFormat('d MMMM yyyy').format(date),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isToday ? const Color(0xFF4F6EF7) : Colors.white,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F6EF7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF4F6EF7).withOpacity(0.4)),
                  ),
                  child: const Text('Today', style: TextStyle(fontSize: 11, color: Color(0xFF4F6EF7), fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFF2A2D3A)),
        // Content
        Expanded(
          child: dayAsync.when(
            loading: () => const Center(child: CircularProgressIndicator.adaptive()),
            error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
            data: (data) {
              final tasks = List<Map<String, dynamic>>.from(data['tasks'] ?? []);
              final overdue = List<Map<String, dynamic>>.from(data['overdue_tasks'] ?? []);
              final habits = List<Map<String, dynamic>>.from(data['habits'] ?? []);
              final events = List<Map<String, dynamic>>.from(data['events'] ?? []);

              if (tasks.isEmpty && overdue.isEmpty && habits.isEmpty && events.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wb_sunny_outlined, size: 40, color: Colors.grey.shade700),
                      const SizedBox(height: 10),
                      Text('Nothing scheduled', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                );
              }

              return ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (overdue.isNotEmpty) ...[
                    _SectionHeader(title: 'OVERDUE', color: Colors.red.shade400, badge: overdue.length),
                    ...overdue.map((t) => _TaskTile(
                          task: t,
                          onComplete: () async {
                            await ApiService().completeTask(t['id'] as String);
                            onRefresh();
                          },
                          onDelete: () async {
                            await ApiService().deleteTask(t['id'] as String);
                            onRefresh();
                          },
                        )),
                  ],
                  if (events.isNotEmpty) ...[
                    _SectionHeader(title: 'EVENTS', color: Colors.purple.shade300),
                    ...events.map((e) => _EventTile(
                          event: e,
                          onDelete: () async {
                            await ApiService().deleteEvent(e['id'] as String);
                            onRefresh();
                          },
                        )),
                  ],
                  if (tasks.isNotEmpty) ...[
                    _SectionHeader(title: 'TASKS', color: const Color(0xFF4F6EF7)),
                    ...tasks.map((t) => _TaskTile(
                          task: t,
                          onComplete: () async {
                            await ApiService().completeTask(t['id'] as String);
                            onRefresh();
                          },
                          onDelete: () async {
                            await ApiService().deleteTask(t['id'] as String);
                            onRefresh();
                          },
                        )),
                  ],
                  if (habits.isNotEmpty) ...[
                    _SectionHeader(title: 'HABITS', color: const Color(0xFF4F6EF7)),
                    ...habits.map((h) => _HabitTile(
                          habit: h,
                          date: dateStr,
                          onToggle: onRefresh,
                        )),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Week View ────────────────────────────────────────────────────────────────

class _WeekView extends ConsumerWidget {
  final DateTime weekStart;
  final DateTime selectedDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(DateTime) onDayTap;
  final WidgetRef ref;

  const _WeekView({
    required this.weekStart,
    required this.selectedDate,
    required this.onPrev,
    required this.onNext,
    required this.onDayTap,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final weekStr = DateFormat('yyyy-MM-dd').format(weekStart);
    final weekAsync = ref.watch(plannerWeekProvider(weekStr));
    final today = DateTime.now();

    return Column(
      children: [
        // Week header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
              Expanded(
                child: Text(
                  'Week of ${DateFormat('MMM d').format(weekStart)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
            ],
          ),
        ),

        // 7-day strip
        weekAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: CircularProgressIndicator.adaptive(),
          ),
          error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
          data: (days) => Column(
            children: [
              // Day cells
              SizedBox(
                height: 90,
                child: Row(
                  children: List.generate(7, (i) {
                    final day = weekStart.add(Duration(days: i));
                    final dayData = i < days.length ? days[i] as Map<String, dynamic> : <String, dynamic>{};
                    final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                    final taskCount = (dayData['task_count'] as int? ?? 0);
                    final eventCount = (dayData['event_count'] as int? ?? 0);
                    final habitDone = (dayData['habit_done'] as int? ?? 0);
                    final habitTotal = (dayData['habit_total'] as int? ?? 0);

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onDayTap(day),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isToday
                                ? const Color(0xFF4F6EF7).withOpacity(0.15)
                                : const Color(0xFF1A1D27),
                            borderRadius: BorderRadius.circular(8),
                            border: isToday ? Border.all(color: const Color(0xFF4F6EF7).withOpacity(0.4)) : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('E').format(day).substring(0, 1),
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${day.day}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? const Color(0xFF4F6EF7) : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Dots
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (taskCount > 0)
                                    _Dot(color: const Color(0xFF4F6EF7)),
                                  if (eventCount > 0)
                                    _Dot(color: Colors.purple.shade300),
                                  if (habitDone > 0)
                                    _Dot(color: const Color(0xFF27AE60)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Habit bar
                              if (habitTotal > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: LinearProgressIndicator(
                                    value: habitDone / habitTotal,
                                    minHeight: 3,
                                    backgroundColor: Colors.grey.shade800,
                                    valueColor: const AlwaysStoppedAnimation(Color(0xFF27AE60)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Week summary
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _WeekStat(
                      icon: Icons.task_alt,
                      label: 'Tasks',
                      value: days.fold<int>(0, (s, d) => s + ((d as Map)['task_count'] as int? ?? 0)).toString(),
                      color: const Color(0xFF4F6EF7),
                    ),
                    _WeekStat(
                      icon: Icons.event,
                      label: 'Events',
                      value: days.fold<int>(0, (s, d) => s + ((d as Map)['event_count'] as int? ?? 0)).toString(),
                      color: Colors.purple.shade300,
                    ),
                    _WeekStat(
                      icon: Icons.fitness_center,
                      label: 'Habits',
                      value: () {
                        final total = days.fold<int>(0, (s, d) => s + ((d as Map)['habit_total'] as int? ?? 0));
                        final done = days.fold<int>(0, (s, d) => s + ((d as Map)['habit_done'] as int? ?? 0));
                        return total > 0 ? '${(done / total * 100).round()}%' : '—';
                      }(),
                      color: const Color(0xFF27AE60),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _WeekStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _WeekStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}

// ─── Month View ───────────────────────────────────────────────────────────────

class _MonthView extends ConsumerWidget {
  final DateTime month;
  final DateTime selectedDate;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(DateTime) onDayTap;
  final WidgetRef ref;

  const _MonthView({
    required this.month,
    required this.selectedDate,
    required this.onPrev,
    required this.onNext,
    required this.onDayTap,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final today = DateTime.now();
    // Month start
    final firstDay = DateTime(month.year, month.month, 1);
    // Pad to Monday
    final startPad = (firstDay.weekday - 1) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final totalCells = startPad + daysInMonth;
    final rows = (totalCells / 7).ceil();

    // Fetch the full month of week data by splitting into weeks
    // We'll just fetch the month via event/task data — but we don't have a month endpoint.
    // We'll use plannerWeek for each week in the month.
    final weeks = <String>[];
    for (var i = 0; i < rows; i++) {
      final weekStart = firstDay.subtract(Duration(days: startPad)).add(Duration(days: i * 7));
      weeks.add(DateFormat('yyyy-MM-dd').format(weekStart));
    }

    final weekDataList = weeks.map((ws) => ref.watch(plannerWeekProvider(ws))).toList();

    // Build day data map
    final Map<String, Map<String, dynamic>> dayMap = {};
    for (final weekAsync in weekDataList) {
      weekAsync.whenData((days) {
        for (final d in days) {
          dayMap[(d as Map)['date'] as String] = d as Map<String, dynamic>;
        }
      });
    }

    return Column(
      children: [
        // Month header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
            ],
          ),
        ),

        // Day-of-week headers
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => Expanded(
                      child: Text(d,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),

        // Calendar grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85,
            ),
            itemCount: rows * 7,
            itemBuilder: (_, index) {
              final cellDate = firstDay.subtract(Duration(days: startPad)).add(Duration(days: index));
              final isCurrentMonth = cellDate.month == month.month;
              final isToday = cellDate.year == today.year && cellDate.month == today.month && cellDate.day == today.day;
              final dateStr = DateFormat('yyyy-MM-dd').format(cellDate);
              final dayData = dayMap[dateStr];

              final taskCount = dayData?['task_count'] as int? ?? 0;
              final eventCount = dayData?['event_count'] as int? ?? 0;
              final habitDone = dayData?['habit_done'] as int? ?? 0;
              final habitTotal = dayData?['habit_total'] as int? ?? 0;

              return GestureDetector(
                onTap: () => onDayTap(cellDate),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFF4F6EF7).withOpacity(0.15)
                        : const Color(0xFF1A1D27),
                    borderRadius: BorderRadius.circular(8),
                    border: isToday ? Border.all(color: const Color(0xFF4F6EF7), width: 1.5) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${cellDate.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: !isCurrentMonth
                              ? Colors.grey.shade800
                              : isToday
                                  ? const Color(0xFF4F6EF7)
                                  : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (taskCount > 0 && isCurrentMonth) _Dot(color: const Color(0xFF4F6EF7)),
                          if (eventCount > 0 && isCurrentMonth) _Dot(color: Colors.purple.shade300),
                          if (habitTotal > 0 && isCurrentMonth)
                            _Dot(
                              color: habitDone >= habitTotal
                                  ? const Color(0xFF27AE60)
                                  : Colors.grey.shade600,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dot(color: const Color(0xFF4F6EF7)), const SizedBox(width: 4),
              const Text('Tasks', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 12),
              _Dot(color: Colors.purple.shade300), const SizedBox(width: 4),
              const Text('Events', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 12),
              _Dot(color: const Color(0xFF27AE60)), const SizedBox(width: 4),
              const Text('Habits done', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
