import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../providers/habit_provider.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsTodayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        backgroundColor: const Color(0xFF0F1117),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddHabitSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(habitsTodayProvider),
        child: habitsAsync.when(
          data: (habits) {
            final done = habits.where((h) => h['completed'] == true).length;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Progress bar
                if (habits.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Today: $done/${habits.length}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      Text('${habits.isEmpty ? 0 : (done / habits.length * 100).round()}%',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: habits.isEmpty ? 0 : done / habits.length,
                      backgroundColor: const Color(0xFF2A2D3A),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                ...habits.map((h) => _HabitCard(habit: h, ref: ref)),
                if (habits.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Text('No habits yet.\nTap + to create one.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator.adaptive()),
          error: (e, _) => Center(child: Text('$e')),
        ),
      ),
    );
  }

  Future<void> _showAddHabitSheet(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    String category = '';
    String frequency = 'daily';

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
                      if (category.isNotEmpty) 'category': category,
                    });
                    ref.invalidate(habitsTodayProvider);
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

class _HabitCard extends StatelessWidget {
  final Map<String, dynamic> habit;
  final WidgetRef ref;
  const _HabitCard({required this.habit, required this.ref});

  @override
  Widget build(BuildContext context) {
    final completed = habit['completed'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: GestureDetector(
          onTap: () => ref.read(habitLogProvider.notifier).toggle(
                habit['id'] as String,
                !completed,
              ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed ? const Color(0xFF4F6EF7) : const Color(0xFF1A1D27),
              border: Border.all(
                color: completed ? const Color(0xFF4F6EF7) : const Color(0xFF2A2D3A),
                width: 2,
              ),
            ),
            child: completed
                ? const Icon(Icons.check, color: Colors.white, size: 22)
                : Center(
                    child: Text(
                      habit['icon'] as String? ?? '○',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
          ),
        ),
        title: Text(
          habit['name'] as String,
          style: TextStyle(
            decoration: completed ? TextDecoration.lineThrough : null,
            color: completed ? Colors.grey : Colors.white,
          ),
        ),
        subtitle: habit['category'] != null
            ? Text(habit['category'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey))
            : null,
      ),
    );
  }
}
