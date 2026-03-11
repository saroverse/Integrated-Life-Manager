import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/habit_provider.dart';
import '../../services/api_service.dart';

class AddHabitScreen extends ConsumerStatefulWidget {
  const AddHabitScreen({super.key});

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _saving = false;

  // Step 1 — Category
  String? _category;

  // Step 2 — Tracking type
  String _trackingType = 'done';

  // Step 3 — Definition
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _icon = '⭐';
  String _color = '#4F6EF7';
  TimeOfDay? _reminderTime;
  int _targetCount = 1;

  // Step 4 — Schedule
  String _frequency = 'daily';
  final Set<int> _customDays = {0, 1, 2, 3, 4}; // Mon–Fri default

  // ── Static data ─────────────────────────────────────────────────────────────

  static const _categories = [
    _Cat('💪', 'Discipline', 'Cold showers, journaling, early rising'),
    _Cat('🏃', 'Fitness', 'Running, gym, sport, walking'),
    _Cat('🧠', 'Learning', 'Reading, studying, skills, courses'),
    _Cat('🧘', 'Mindfulness', 'Meditation, breathing, gratitude'),
    _Cat('❤️', 'Health', 'Sleep, hydration, nutrition, medication'),
    _Cat('🤝', 'Social', 'Family calls, networking, friendships'),
    _Cat('⭐', 'Custom', 'Anything that doesn\'t fit above'),
  ];

  static const _trackingTypes = [
    _Tracking('done', '✓', 'Done / Not Done',
        'Simple checkbox — mark it as done each day'),
    _Tracking('count', '🔢', 'Count',
        'Track a number: reps, pages, glasses of water…'),
    _Tracking('duration', '⏱', 'Duration',
        'Track minutes you spend on the habit'),
  ];

  static const _icons = [
    '⭐', '💪', '🏃', '🚴', '🧘', '🏊', '📚', '✍️', '💧', '🥗',
    '😴', '🏋️', '🎯', '🔥', '🎵', '💻', '🌿', '🙏', '🤝', '❤️',
    '🧠', '☀️', '🌊', '🍎', '📝', '🏆', '🧹', '📞', '🌙', '💊',
  ];

  static const _colors = [
    '#4F6EF7', '#2ECC71', '#E74C3C', '#F39C12',
    '#9B59B6', '#1ABC9C', '#E67E22', '#3498DB',
  ];

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static const _stepTitles = [
    'Choose a category',
    'How will you track it?',
    'Define your habit',
    'Set your schedule',
  ];

  static const _stepSubtitles = [
    'What area of life does this habit belong to?',
    'How do you want to measure progress each day?',
    'Give your habit a name, icon, and appearance.',
    'When and how often will you do it?',
  ];

  // ── Navigation ───────────────────────────────────────────────────────────────

  void _next() {
    if (_step == 0 && _category == null) {
      _snack('Please select a category');
      return;
    }
    if (_step == 2 && _nameCtrl.text.trim().isEmpty) {
      _snack('Please enter a habit name');
      return;
    }
    if (_step == 3) {
      _createHabit();
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

  Future<void> _createHabit() async {
    setState(() => _saving = true);
    try {
      String frequency = _frequency;
      String? frequencyDays;

      if (_frequency == 'custom') {
        frequency = 'weekly';
        final sorted = _customDays.toList()..sort();
        frequencyDays = jsonEncode(sorted);
      }

      final targetCount = _trackingType == 'done' ? 1 : _targetCount;

      await ApiService().createHabit({
        'name': _nameCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        'frequency': frequency,
        if (frequencyDays != null) 'frequency_days': frequencyDays,
        'target_count': targetCount,
        'icon': _icon,
        'color': _color,
        if (_category != null) 'category': _category,
        if (_reminderTime != null)
          'reminder_time':
              '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}',
      });

      ref.invalidate(habitsTodayProvider);
      ref.invalidate(habitsStatsProvider(30));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Failed to create habit: $e');
      setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
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
        title: const Text('New Habit'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          _StepProgress(step: _step, total: 4),
          const SizedBox(height: 16),
          // Step heading
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
          // Page content
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1Category(
                  categories: _categories,
                  selected: _category,
                  onSelected: (c) => setState(() => _category = c),
                ),
                _Step2Tracking(
                  types: _trackingTypes,
                  selected: _trackingType,
                  onSelected: (t) => setState(() => _trackingType = t),
                ),
                _Step3Definition(
                  nameCtrl: _nameCtrl,
                  descCtrl: _descCtrl,
                  icon: _icon,
                  color: _color,
                  icons: _icons,
                  colors: _colors,
                  reminderTime: _reminderTime,
                  trackingType: _trackingType,
                  targetCount: _targetCount,
                  onIconSelected: (v) => setState(() => _icon = v),
                  onColorSelected: (v) => setState(() => _color = v),
                  onReminderSelected: (v) => setState(() => _reminderTime = v),
                  onTargetChanged: (v) => setState(() => _targetCount = v),
                ),
                _Step4Schedule(
                  frequency: _frequency,
                  customDays: _customDays,
                  dayNames: _dayNames,
                  onFrequencyChanged: (v) => setState(() => _frequency = v),
                  onCustomDaysChanged: (v) => setState(() {
                    _customDays.clear();
                    _customDays.addAll(v);
                  }),
                ),
              ],
            ),
          ),
          // Bottom navigation
          _BottomNav(
            step: _step,
            saving: _saving,
            onBack: _prev,
            onNext: _next,
          ),
        ],
      ),
    );
  }
}

// ─── Shared data classes ──────────────────────────────────────────────────────

class _Cat {
  final String emoji;
  final String name;
  final String desc;
  const _Cat(this.emoji, this.name, this.desc);
}

class _Tracking {
  final String id;
  final String emoji;
  final String name;
  final String desc;
  const _Tracking(this.id, this.emoji, this.name, this.desc);
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
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _BottomNav(
      {required this.step,
      required this.saving,
      required this.onBack,
      required this.onNext});

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
                  : Text(step == 3 ? 'Create Habit' : 'Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 1: Category ─────────────────────────────────────────────────────────

class _Step1Category extends StatelessWidget {
  final List<_Cat> categories;
  final String? selected;
  final ValueChanged<String> onSelected;
  const _Step1Category(
      {required this.categories, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2,
      ),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat = categories[i];
        final isSelected = selected == cat.name;
        return GestureDetector(
          onTap: () => onSelected(cat.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4F6EF7).withOpacity(0.15)
                  : const Color(0xFF1A1D27),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4F6EF7)
                    : const Color(0xFF2A2D3A),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(cat.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(cat.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(cat.desc,
                          style:
                              const TextStyle(fontSize: 10, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Step 2: Tracking Type ────────────────────────────────────────────────────

class _Step2Tracking extends StatelessWidget {
  final List<_Tracking> types;
  final String selected;
  final ValueChanged<String> onSelected;
  const _Step2Tracking(
      {required this.types, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: types.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final t = types[i];
        final isSelected = selected == t.id;
        return GestureDetector(
          onTap: () => onSelected(t.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF4F6EF7).withOpacity(0.12)
                  : const Color(0xFF1A1D27),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4F6EF7)
                    : const Color(0xFF2A2D3A),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4F6EF7).withOpacity(0.2)
                        : const Color(0xFF2A2D3A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                      child: Text(t.emoji,
                          style: const TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(t.desc,
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      color: Color(0xFF4F6EF7), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Step 3: Definition ───────────────────────────────────────────────────────

class _Step3Definition extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final String icon;
  final String color;
  final List<String> icons;
  final List<String> colors;
  final TimeOfDay? reminderTime;
  final String trackingType;
  final int targetCount;
  final ValueChanged<String> onIconSelected;
  final ValueChanged<String> onColorSelected;
  final ValueChanged<TimeOfDay?> onReminderSelected;
  final ValueChanged<int> onTargetChanged;

  const _Step3Definition({
    required this.nameCtrl,
    required this.descCtrl,
    required this.icon,
    required this.color,
    required this.icons,
    required this.colors,
    required this.reminderTime,
    required this.trackingType,
    required this.targetCount,
    required this.onIconSelected,
    required this.onColorSelected,
    required this.onReminderSelected,
    required this.onTargetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor =
        Color(int.parse('FF${color.substring(1)}', radix: 16));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + icon preview row
          Row(
            children: [
              // Icon preview tap to change
              GestureDetector(
                onTap: () => _showIconPicker(context),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: accentColor.withOpacity(0.4), width: 1.5),
                  ),
                  child: Center(
                      child: Text(icon,
                          style: const TextStyle(fontSize: 26))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Habit name…',
                    filled: true,
                    fillColor: const Color(0xFF1A1D27),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Description
          TextField(
            controller: descCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Description (optional)',
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
          const SizedBox(height: 20),
          // Color picker
          const Text('Colour',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
          const SizedBox(height: 8),
          Row(
            children: colors.map((c) {
              final col = Color(int.parse('FF${c.substring(1)}', radix: 16));
              final isSelected = color == c;
              return GestureDetector(
                onTap: () => onColorSelected(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 10),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: isSelected
                        ? [BoxShadow(color: col.withOpacity(0.6), blurRadius: 6)]
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Target count (only for count/duration)
          if (trackingType != 'done') ...[
            _SectionLabel(
                trackingType == 'count' ? 'Daily target (reps/units)' : 'Daily target (minutes)'),
            const SizedBox(height: 8),
            _NumberStepper(
              value: targetCount,
              min: 1,
              max: trackingType == 'duration' ? 240 : 100,
              onChanged: onTargetChanged,
              suffix: trackingType == 'duration' ? 'min' : 'reps',
            ),
            const SizedBox(height: 20),
          ],
          // Reminder
          _SectionLabel('Daily reminder'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: reminderTime ?? const TimeOfDay(hour: 8, minute: 0),
              );
              onReminderSelected(picked);
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
                  const Icon(Icons.notifications_none,
                      color: Colors.grey, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    reminderTime != null
                        ? reminderTime!.format(context)
                        : 'No reminder',
                    style: TextStyle(
                        color:
                            reminderTime != null ? Colors.white : Colors.grey),
                  ),
                  const Spacer(),
                  if (reminderTime != null)
                    GestureDetector(
                      onTap: () => onReminderSelected(null),
                      child: const Icon(Icons.close,
                          color: Colors.grey, size: 16),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showIconPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick an icon',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: icons.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () {
                  onIconSelected(icons[i]);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: icon == icons[i]
                        ? const Color(0xFF4F6EF7).withOpacity(0.2)
                        : const Color(0xFF2A2D3A),
                    borderRadius: BorderRadius.circular(10),
                    border: icon == icons[i]
                        ? Border.all(color: const Color(0xFF4F6EF7))
                        : null,
                  ),
                  child: Center(
                      child: Text(icons[i],
                          style: const TextStyle(fontSize: 22))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 4: Schedule ─────────────────────────────────────────────────────────

class _Step4Schedule extends StatelessWidget {
  final String frequency;
  final Set<int> customDays;
  final List<String> dayNames;
  final ValueChanged<String> onFrequencyChanged;
  final ValueChanged<Set<int>> onCustomDaysChanged;

  const _Step4Schedule({
    required this.frequency,
    required this.customDays,
    required this.dayNames,
    required this.onFrequencyChanged,
    required this.onCustomDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Frequency options
          _FrequencyOption(
            label: 'Every day',
            subtitle: '7 days a week',
            icon: Icons.calendar_today,
            selected: frequency == 'daily',
            onTap: () => onFrequencyChanged('daily'),
          ),
          const SizedBox(height: 10),
          _FrequencyOption(
            label: 'Weekdays',
            subtitle: 'Monday to Friday',
            icon: Icons.work_outline,
            selected: frequency == 'weekdays',
            onTap: () => onFrequencyChanged('weekdays'),
          ),
          const SizedBox(height: 10),
          _FrequencyOption(
            label: 'Custom days',
            subtitle: 'Pick specific days of the week',
            icon: Icons.tune,
            selected: frequency == 'custom',
            onTap: () => onFrequencyChanged('custom'),
          ),
          // Custom day toggles
          if (frequency == 'custom') ...[
            const SizedBox(height: 16),
            Row(
              children: List.generate(7, (i) {
                final selected = customDays.contains(i);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final updated = Set<int>.from(customDays);
                      if (selected) {
                        updated.remove(i);
                      } else {
                        updated.add(i);
                      }
                      onCustomDaysChanged(updated);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: EdgeInsets.only(right: i < 6 ? 6 : 0),
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF4F6EF7)
                            : const Color(0xFF1A1D27),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
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
                            color: selected ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 28),
          // Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D27),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF4F6EF7).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF4F6EF7), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _scheduleSummary(),
                    style:
                        const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _scheduleSummary() {
    if (frequency == 'daily') return 'This habit will appear every day.';
    if (frequency == 'weekdays') {
      return 'This habit will appear Monday through Friday.';
    }
    if (customDays.isEmpty) return 'Select at least one day.';
    final sorted = customDays.toList()..sort();
    final names = sorted.map((i) => dayNames[i]).join(', ');
    return 'This habit will appear on: $names.';
  }
}

class _FrequencyOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FrequencyOption({
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
            color: selected
                ? const Color(0xFF4F6EF7)
                : const Color(0xFF2A2D3A),
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
                          color:
                              selected ? Colors.white : Colors.white70)),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
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
            fontSize: 12,
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
              '$value $suffix',
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
