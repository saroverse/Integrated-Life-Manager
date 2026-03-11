import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/habit_provider.dart';
import '../../services/api_service.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  final String habitId;
  const HabitDetailScreen({super.key, required this.habitId});

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  late DateTime _displayedMonth;
  late Future<Map<String, dynamic>> _calendarFuture;
  DateTime? _createdMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _calendarFuture = _fetchMonth();
  }

  Future<Map<String, dynamic>> _fetchMonth() {
    final start = DateFormat('yyyy-MM-dd')
        .format(DateTime(_displayedMonth.year, _displayedMonth.month, 1));
    final end = DateFormat('yyyy-MM-dd')
        .format(DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0));
    return ApiService().getHabitCalendar(widget.habitId, start: start, end: end);
  }

  void _prevMonth() {
    if (_createdMonth != null) {
      final atEarliest = _displayedMonth.year == _createdMonth!.year &&
          _displayedMonth.month == _createdMonth!.month;
      if (atEarliest) return;
    }
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
      _calendarFuture = _fetchMonth();
    });
  }

  void _nextMonth() {
    final now = DateTime.now();
    if (_displayedMonth.year == now.year && _displayedMonth.month == now.month) return;
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
      _calendarFuture = _fetchMonth();
    });
  }

  bool get _canGoPrev {
    if (_createdMonth == null) return true;
    return _displayedMonth.year > _createdMonth!.year ||
        (_displayedMonth.year == _createdMonth!.year &&
            _displayedMonth.month > _createdMonth!.month);
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return !(_displayedMonth.year == now.year && _displayedMonth.month == now.month);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _calendarFuture,
        builder: (context, snapshot) {
          // Keep showing old data while loading next month
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          final data = snapshot.data!;
          final habit = data['habit'] as Map<String, dynamic>;

          // Extract created_at once for navigation limits
          if (_createdMonth == null) {
            final createdAtStr = habit['created_at'] as String?;
            if (createdAtStr != null) {
              final dt = DateTime.tryParse(createdAtStr);
              if (dt != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _createdMonth = DateTime(dt.year, dt.month));
                });
              }
            }
          }

          return _DetailBody(
            data: data,
            habitId: widget.habitId,
            displayedMonth: _displayedMonth,
            canGoPrev: _canGoPrev,
            canGoNext: _canGoNext,
            isLoading: snapshot.connectionState == ConnectionState.waiting,
            onPrevMonth: _prevMonth,
            onNextMonth: _nextMonth,
            ref: ref,
          );
        },
      ),
    );
  }
}

// ─── Detail Body ──────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  final Map<String, dynamic> data;
  final String habitId;
  final DateTime displayedMonth;
  final bool canGoPrev;
  final bool canGoNext;
  final bool isLoading;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final WidgetRef ref;

  const _DetailBody({
    required this.data,
    required this.habitId,
    required this.displayedMonth,
    required this.canGoPrev,
    required this.canGoNext,
    required this.isLoading,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
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
    final completionRate = (stats['completion_rate'] as num?)?.toDouble() ?? 0.0;
    final weekdayRates = (stats['weekday_rates'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        List.filled(7, 0.0);

    // Parse created_at for calendar display
    final createdAtStr = habit['created_at'] as String?;
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

    return CustomScrollView(
      slivers: [
        // ── App Bar ──
        SliverAppBar(
          backgroundColor: const Color(0xFF1A1D27),
          expandedHeight: 110,
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
                Text(name,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                      content: Text(
                          'Archive "$name"? It will no longer appear in your daily list.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Archive',
                              style: TextStyle(color: Colors.red)),
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
                // ── All-time stats ──
                _StatsRow(
                  current: currentStreak,
                  longest: longestStreak,
                  total: totalCompletions,
                  rate: completionRate,
                  accent: accent,
                ),
                const SizedBox(height: 24),

                // ── Monthly Calendar ──
                _SectionHeader(
                  leading: Row(
                    children: [
                      const Text('HISTORY',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2)),
                    ],
                  ),
                  trailing: _MonthNav(
                    month: displayedMonth,
                    canGoPrev: canGoPrev,
                    canGoNext: canGoNext,
                    isLoading: isLoading,
                    onPrev: onPrevMonth,
                    onNext: onNextMonth,
                  ),
                ),
                const SizedBox(height: 12),
                _MonthCalendar(
                  days: days,
                  month: displayedMonth,
                  accent: accent,
                  habitCreatedAt: createdAt,
                ),
                const SizedBox(height: 8),
                // Legend
                Row(
                  children: [
                    _LegendDot(color: accent, label: 'Done'),
                    const SizedBox(width: 16),
                    _LegendDot(color: const Color(0xFF2A2D3A), label: 'Missed'),
                    const SizedBox(width: 16),
                    _LegendDot(
                        color: Colors.transparent, label: 'No schedule', border: true),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Weekday breakdown ──
                _SectionHeader(
                  leading: const Text('WEEKDAY BREAKDOWN',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2)),
                  trailing: Text(
                    DateFormat('MMMM').format(displayedMonth),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
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

// ─── Month Navigation ─────────────────────────────────────────────────────────

class _MonthNav extends StatelessWidget {
  final DateTime month;
  final bool canGoPrev;
  final bool canGoNext;
  final bool isLoading;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthNav({
    required this.month,
    required this.canGoPrev,
    required this.canGoNext,
    required this.isLoading,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 18),
          onPressed: canGoPrev ? onPrev : null,
          color: canGoPrev ? Colors.white70 : Colors.white12,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 110,
          child: isLoading
              ? const Center(
                  child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5)))
              : Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 18),
          onPressed: canGoNext ? onNext : null,
          color: canGoNext ? Colors.white70 : Colors.white12,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

// ─── Monthly Calendar Grid ────────────────────────────────────────────────────

class _MonthCalendar extends StatelessWidget {
  final List<dynamic> days;
  final DateTime month;
  final Color accent;
  final DateTime? habitCreatedAt;

  const _MonthCalendar({
    required this.days,
    required this.month,
    required this.accent,
    required this.habitCreatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstDay.weekday - 1; // Mon = 0
    final totalCells = ((leadingBlanks + daysInMonth) / 7).ceil() * 7;

    // Build lookup: date string → day data
    final dayMap = <String, Map<String, dynamic>>{};
    for (final d in days) {
      final m = d as Map<String, dynamic>;
      dayMap[m['date'] as String] = m;
    }

    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D27),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Day-of-week headers
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemCount: totalCells,
            itemBuilder: (_, idx) {
              if (idx < leadingBlanks || idx >= leadingBlanks + daysInMonth) {
                return const SizedBox();
              }
              final dayNum = idx - leadingBlanks + 1;
              final cellDate = DateTime(month.year, month.month, dayNum);
              final dateStr = DateFormat('yyyy-MM-dd').format(cellDate);
              final isToday = cellDate.year == now.year &&
                  cellDate.month == now.month &&
                  cellDate.day == now.day;
              final isFuture = cellDate.isAfter(now);
              final isBeforeCreation = habitCreatedAt != null &&
                  cellDate
                      .isBefore(DateTime(habitCreatedAt!.year, habitCreatedAt!.month, habitCreatedAt!.day));

              final dayData = dayMap[dateStr];
              final scheduled = dayData?['scheduled'] as bool? ?? false;
              final completed = dayData?['completed'] as bool? ?? false;

              Color? bgColor;
              Color textColor;
              bool showBorder = false;

              if (isBeforeCreation) {
                bgColor = null;
                textColor = Colors.white.withOpacity(0.08);
              } else if (isFuture) {
                bgColor = null;
                textColor = Colors.white.withOpacity(0.2);
              } else if (!scheduled) {
                bgColor = null;
                textColor = Colors.white.withOpacity(0.25);
              } else if (completed) {
                bgColor = accent;
                textColor = Colors.white;
              } else {
                bgColor = const Color(0xFF2A2D3A);
                textColor = Colors.grey;
              }

              if (isToday) showBorder = true;

              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: showBorder
                      ? Border.all(color: accent, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor,
                      fontWeight:
                          isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int current;
  final int longest;
  final int total;
  final double rate;
  final Color accent;
  const _StatsRow({
    required this.current,
    required this.longest,
    required this.total,
    required this.rate,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(icon: '🔥', value: '$current', label: 'streak', color: accent),
        const SizedBox(width: 8),
        _StatChip(
            icon: '⭐', value: '$longest', label: 'best', color: const Color(0xFFF39C12)),
        const SizedBox(width: 8),
        _StatChip(
            icon: '✓', value: '$total', label: 'total', color: const Color(0xFF2ECC71)),
        const SizedBox(width: 8),
        _StatChip(
            icon: '%',
            value: '${(rate * 100).round()}',
            label: 'rate',
            color: rate >= 0.8
                ? const Color(0xFF2ECC71)
                : rate >= 0.5
                    ? const Color(0xFF4F6EF7)
                    : const Color(0xFFF39C12)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: const TextStyle(fontSize: 9, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final Widget leading;
  final Widget trailing;
  const _SectionHeader({required this.leading, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        const Spacer(),
        trailing,
      ],
    );
  }
}

// ─── Weekday Chart ────────────────────────────────────────────────────────────

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
            final barH = 4.0 + rate * 62;
            final isToday = i == today;
            final barColor =
                isToday ? accent : accent.withOpacity(0.4 + rate * 0.6);

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('${(rate * 100).round()}%',
                      style: TextStyle(
                          fontSize: 8,
                          color: rate > 0 ? Colors.grey : Colors.transparent)),
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
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─── Legend Dot ───────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool border;
  const _LegendDot(
      {required this.color, required this.label, this.border = false});

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
