import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/planner_provider.dart';
import '../../services/api_service.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  const AddTaskScreen({super.key});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _saving = false;

  // Step 1 — Category & Priority
  String? _category;
  String _priority = 'medium';

  // Step 2 — Details
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Step 3 — Schedule
  DateTime? _dueDate;
  TimeOfDay? _dueTime;
  String _recurrence = 'none';
  int _recurrenceInterval = 2;
  final Set<int> _recurrenceDays = {0, 2, 4}; // Mon, Wed, Fri default

  // ── Static data ─────────────────────────────────────────────────────────────

  static const _categories = [
    _Cat(Icons.work_outline, 'Work', Color(0xFF4F6EF7)),
    _Cat(Icons.person_outline, 'Personal', Color(0xFF2ECC71)),
    _Cat(Icons.favorite_outline, 'Health', Color(0xFFE74C3C)),
    _Cat(Icons.school_outlined, 'Learning', Color(0xFF9B59B6)),
    _Cat(Icons.brush_outlined, 'Creative', Color(0xFFF39C12)),
    _Cat(Icons.more_horiz, 'Other', Color(0xFF7F8C8D)),
  ];

  static const _priorities = [
    _Prio('low', 'Low', Color(0xFF7F8C8D)),
    _Prio('medium', 'Medium', Color(0xFF4F6EF7)),
    _Prio('high', 'High', Color(0xFFF39C12)),
    _Prio('urgent', 'Urgent', Color(0xFFE74C3C)),
  ];

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const _stepTitles = [
    'Type & priority',
    'What\'s the task?',
    'When is it due?',
  ];

  static const _stepSubtitles = [
    'Categorise your task and set its priority.',
    'Give your task a clear name and optional notes.',
    'Set a due date and how often it repeats.',
  ];

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _next() {
    if (_step == 1 && _titleCtrl.text.trim().isEmpty) {
      _snack('Please enter a task name');
      return;
    }
    if (_step == 2) {
      _createTask();
      return;
    }
    setState(() => _step++);
    _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
  }

  void _prev() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
    _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _createTask() async {
    setState(() => _saving = true);
    try {
      String? recurrence;
      String? recurrenceRule;

      if (_recurrence == 'daily') {
        recurrence = 'daily';
      } else if (_recurrence == 'weekly') {
        recurrence = 'weekly';
        final sorted = _recurrenceDays.toList()..sort();
        recurrenceRule = jsonEncode(sorted);
      } else if (_recurrence == 'interval') {
        recurrence = 'interval';
        recurrenceRule = '$_recurrenceInterval';
      }

      String? dueDateStr;
      String? dueTimeStr;
      if (_dueDate != null) {
        dueDateStr =
            '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}';
      }
      if (_dueTime != null) {
        dueTimeStr =
            '${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}';
      }

      await ApiService().createTask({
        'title': _titleCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'priority': _priority,
        if (_category != null) 'tags': _category,
        if (dueDateStr != null) 'due_date': dueDateStr,
        if (dueTimeStr != null) 'due_time': dueTimeStr,
        if (recurrence != null) 'recurrence': recurrence,
        if (recurrenceRule != null) 'recurrence_rule': recurrenceRule,
      });

      // Invalidate planner for the due date (or today)
      final dateStr = dueDateStr ??
          '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';
      ref.invalidate(plannerDayProvider(dateStr));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Failed to create task: $e');
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Task'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepProgress(step: _step, total: 3),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_stepTitles[_step],
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_stepSubtitles[_step],
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1TypePriority(
                  categories: _categories,
                  priorities: _priorities,
                  selectedCategory: _category,
                  selectedPriority: _priority,
                  onCategorySelected: (c) => setState(() => _category = c),
                  onPrioritySelected: (p) => setState(() => _priority = p),
                ),
                _Step2Details(
                  titleCtrl: _titleCtrl,
                  descCtrl: _descCtrl,
                ),
                _Step3Schedule(
                  dueDate: _dueDate,
                  dueTime: _dueTime,
                  recurrence: _recurrence,
                  recurrenceInterval: _recurrenceInterval,
                  recurrenceDays: _recurrenceDays,
                  dayNames: _dayNames,
                  onDateSelected: (d) => setState(() => _dueDate = d),
                  onTimeSelected: (t) => setState(() => _dueTime = t),
                  onRecurrenceChanged: (r) => setState(() => _recurrence = r),
                  onIntervalChanged: (v) => setState(() => _recurrenceInterval = v),
                  onDaysChanged: (d) => setState(() {
                    _recurrenceDays.clear();
                    _recurrenceDays.addAll(d);
                  }),
                ),
              ],
            ),
          ),
          _BottomNav(
            step: _step,
            totalSteps: 3,
            saving: _saving,
            onBack: _prev,
            onNext: _next,
            createLabel: 'Create Task',
          ),
        ],
      ),
    );
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _Cat {
  final IconData icon;
  final String name;
  final Color color;
  const _Cat(this.icon, this.name, this.color);
}

class _Prio {
  final String id;
  final String label;
  final Color color;
  const _Prio(this.id, this.label, this.color);
}

// ─── Step Progress ────────────────────────────────────────────────────────────

class _StepProgress extends StatelessWidget {
  final int step;
  final int total;
  const _StepProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: List.generate(total, (i) {
          final done = i < step;
          final active = i == step;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
              height: 3,
              decoration: BoxDecoration(
                color: done || active
                    ? const Color(0xFF4F6EF7)
                    : const Color(0xFF2A2D3A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Bottom Nav ───────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int step;
  final int totalSteps;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String createLabel;

  const _BottomNav({
    required this.step,
    required this.totalSteps,
    required this.saving,
    required this.onBack,
    required this.onNext,
    required this.createLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 8, 24, MediaQuery.of(context).padding.bottom + 16),
      child: Row(
        children: [
          if (step > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: saving ? null : onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0xFF2A2D3A)),
                ),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: saving ? null : onNext,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F6EF7),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(step == totalSteps - 1 ? createLabel : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 1: Type & Priority ──────────────────────────────────────────────────

class _Step1TypePriority extends StatelessWidget {
  final List<_Cat> categories;
  final List<_Prio> priorities;
  final String? selectedCategory;
  final String selectedPriority;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<String> onPrioritySelected;

  const _Step1TypePriority({
    required this.categories,
    required this.priorities,
    required this.selectedCategory,
    required this.selectedPriority,
    required this.onCategorySelected,
    required this.onPrioritySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('CATEGORY'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final cat = categories[i];
              final isSelected = selectedCategory == cat.name;
              return GestureDetector(
                onTap: () => onCategorySelected(cat.name),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? cat.color.withOpacity(0.15)
                        : const Color(0xFF1A1D27),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? cat.color : const Color(0xFF2A2D3A),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(cat.icon,
                          color: isSelected ? cat.color : Colors.grey, size: 22),
                      const SizedBox(height: 4),
                      Text(cat.name,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.white70)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const _SectionLabel('PRIORITY'),
          const SizedBox(height: 10),
          Row(
            children: priorities.map((p) {
              final isSelected = selectedPriority == p.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onPrioritySelected(p.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(
                        right: p.id != priorities.last.id ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? p.color.withOpacity(0.15)
                          : const Color(0xFF1A1D27),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? p.color : const Color(0xFF2A2D3A),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: p.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(p.label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.grey)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Step 2: Details ──────────────────────────────────────────────────────────

class _Step2Details extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;

  const _Step2Details({required this.titleCtrl, required this.descCtrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: titleCtrl,
            autofocus: true,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Task name…',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 18),
              filled: true,
              fillColor: const Color(0xFF1A1D27),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: descCtrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Notes (optional)',
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFF1A1D27),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 3: Schedule ─────────────────────────────────────────────────────────

class _Step3Schedule extends StatelessWidget {
  final DateTime? dueDate;
  final TimeOfDay? dueTime;
  final String recurrence;
  final int recurrenceInterval;
  final Set<int> recurrenceDays;
  final List<String> dayNames;
  final ValueChanged<DateTime?> onDateSelected;
  final ValueChanged<TimeOfDay?> onTimeSelected;
  final ValueChanged<String> onRecurrenceChanged;
  final ValueChanged<int> onIntervalChanged;
  final ValueChanged<Set<int>> onDaysChanged;

  const _Step3Schedule({
    required this.dueDate,
    required this.dueTime,
    required this.recurrence,
    required this.recurrenceInterval,
    required this.recurrenceDays,
    required this.dayNames,
    required this.onDateSelected,
    required this.onTimeSelected,
    required this.onRecurrenceChanged,
    required this.onIntervalChanged,
    required this.onDaysChanged,
  });

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Due date
          const _SectionLabel('DUE DATE'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: dueDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              onDateSelected(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D27),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: dueDate != null
                        ? const Color(0xFF4F6EF7)
                        : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    dueDate != null ? _formatDate(dueDate!) : 'No due date',
                    style: TextStyle(
                        color: dueDate != null ? Colors.white : Colors.grey),
                  ),
                  const Spacer(),
                  if (dueDate != null)
                    GestureDetector(
                      onTap: () {
                        onDateSelected(null);
                        onTimeSelected(null);
                      },
                      child: const Icon(Icons.close, color: Colors.grey, size: 16),
                    ),
                ],
              ),
            ),
          ),
          // Due time (only if date selected)
          if (dueDate != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: dueTime ?? const TimeOfDay(hour: 9, minute: 0),
                );
                onTimeSelected(picked);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1D27),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_outlined,
                      color: dueTime != null
                          ? const Color(0xFF4F6EF7)
                          : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      dueTime != null ? dueTime!.format(context) : 'No time',
                      style: TextStyle(
                          color: dueTime != null ? Colors.white : Colors.grey),
                    ),
                    const Spacer(),
                    if (dueTime != null)
                      GestureDetector(
                        onTap: () => onTimeSelected(null),
                        child: const Icon(Icons.close, color: Colors.grey, size: 16),
                      ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          // Recurrence
          const _SectionLabel('RECURRENCE'),
          const SizedBox(height: 10),
          _RecurrenceOption(
            label: 'No repeat',
            subtitle: 'One-time task',
            icon: Icons.looks_one_outlined,
            selected: recurrence == 'none',
            onTap: () => onRecurrenceChanged('none'),
          ),
          const SizedBox(height: 8),
          _RecurrenceOption(
            label: 'Every day',
            subtitle: 'Repeats daily',
            icon: Icons.repeat,
            selected: recurrence == 'daily',
            onTap: () => onRecurrenceChanged('daily'),
          ),
          const SizedBox(height: 8),
          _RecurrenceOption(
            label: 'Specific days',
            subtitle: 'Pick days of the week',
            icon: Icons.calendar_view_week_outlined,
            selected: recurrence == 'weekly',
            onTap: () => onRecurrenceChanged('weekly'),
          ),
          if (recurrence == 'weekly') ...[
            const SizedBox(height: 12),
            Row(
              children: List.generate(7, (i) {
                final sel = recurrenceDays.contains(i);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final updated = Set<int>.from(recurrenceDays);
                      if (sel) {
                        updated.remove(i);
                      } else {
                        updated.add(i);
                      }
                      onDaysChanged(updated);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(right: i < 6 ? 6 : 0),
                      height: 44,
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF4F6EF7)
                            : const Color(0xFF1A1D27),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel
                              ? const Color(0xFF4F6EF7)
                              : const Color(0xFF2A2D3A),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          dayNames[i].substring(0, 1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 8),
          _RecurrenceOption(
            label: 'Every N days',
            subtitle: 'Set a day interval',
            icon: Icons.loop,
            selected: recurrence == 'interval',
            onTap: () => onRecurrenceChanged('interval'),
          ),
          if (recurrence == 'interval') ...[
            const SizedBox(height: 12),
            _NumberStepper(
              value: recurrenceInterval,
              min: 2,
              max: 14,
              suffix: recurrenceInterval == 1 ? 'day' : 'days',
              onChanged: onIntervalChanged,
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _RecurrenceOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RecurrenceOption({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF4F6EF7).withOpacity(0.12)
              : const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF4F6EF7) : const Color(0xFF2A2D3A),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: selected ? const Color(0xFF4F6EF7) : Colors.grey,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.white70)),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF4F6EF7), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8));
  }
}

class _NumberStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  const _NumberStepper({
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
            color: value > min ? Colors.white70 : Colors.white24,
          ),
          Expanded(
            child: Text(
              'Every $value $suffix',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: value < max ? () => onChanged(value + 1) : null,
            color: value < max ? Colors.white70 : Colors.white24,
          ),
        ],
      ),
    );
  }
}
