import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';

final _tasksProvider = FutureProvider.family<List<dynamic>, String?>((ref, status) async {
  return ApiService().getTasks(status: status);
});

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(_tasksProvider(_filterStatus));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        backgroundColor: const Color(0xFF0F1117),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskSheet(context),
        backgroundColor: const Color(0xFF4F6EF7),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChipButton('All', null, _filterStatus, (s) => setState(() => _filterStatus = s)),
                _FilterChipButton('Pending', 'pending', _filterStatus, (s) => setState(() => _filterStatus = s)),
                _FilterChipButton('Done', 'done', _filterStatus, (s) => setState(() => _filterStatus = s)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(_tasksProvider),
              child: tasksAsync.when(
                data: (tasks) => tasks.isEmpty
                    ? _EmptyState(
                        icon: Icons.task_alt,
                        message: _filterStatus == 'done'
                            ? 'No completed tasks'
                            : 'No tasks yet.\nTap + to create one.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                        itemCount: tasks.length,
                        itemBuilder: (_, i) {
                          final task = tasks[i];
                          final isDone = task['status'] == 'done';
                          return _SwipeableTaskTile(
                            key: ValueKey(task['id']),
                            task: task,
                            onComplete: isDone ? null : () async {
                              HapticFeedback.lightImpact();
                              await ApiService().completeTask(task['id'] as String);
                              ref.invalidate(_tasksProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(children: [
                                      const Icon(Icons.check_circle, color: Colors.white, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text('Done: ${task['title']}')),
                                    ]),
                                    backgroundColor: const Color(0xFF2ECC71),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                            onDelete: () async {
                              await ApiService().deleteTask(task['id'] as String);
                              ref.invalidate(_tasksProvider);
                            },
                          );
                        },
                      ),
                loading: () => _TaskListSkeleton(),
                error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskSheet(BuildContext context) async {
    final titleController = TextEditingController();
    String priority = 'medium';

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
              const Text('New Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Task title...', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: priority,
                decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                items: ['low', 'medium', 'high', 'urgent']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase())))
                    .toList(),
                onChanged: (v) => setS(() => priority = v!),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (titleController.text.isEmpty) return;
                    await ApiService().createTask({
                      'title': titleController.text,
                      'priority': priority,
                    });
                    ref.invalidate(_tasksProvider);
                    if (context.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Create Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Swipeable task tile ──────────────────────────────────────────────────────

class _SwipeableTaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback? onComplete;
  final VoidCallback onDelete;
  const _SwipeableTaskTile({super.key, required this.task, required this.onComplete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDone = task['status'] == 'done';

    return Dismissible(
      key: ValueKey(task['id']),
      direction: isDone
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd && !isDone) {
          onComplete?.call();
          return false; // tile stays, UI updates via provider
        }
        // end-to-start = delete
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete task?'),
            content: Text(task['title'] as String),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        return confirm ?? false;
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF2ECC71),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerLeft,
        child: const Row(children: [
          Icon(Icons.check, color: Colors.white),
          SizedBox(width: 8),
          Text('Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade700,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          SizedBox(width: 8),
          Icon(Icons.delete_outline, color: Colors.white),
        ]),
      ),
      child: _TaskCard(task: task, onComplete: onComplete),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback? onComplete;
  const _TaskCard({required this.task, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final isDone = task['status'] == 'done';
    final priority = task['priority'] as String? ?? 'medium';
    final priorityColor = switch (priority) {
      'urgent' => Colors.red.shade400,
      'high' => Colors.orange.shade400,
      'medium' => Colors.blue.shade400,
      _ => Colors.grey.shade600,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 56,
            decoration: BoxDecoration(
              color: isDone ? Colors.grey.shade700 : priorityColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: isDone ? null : onComplete,
            child: Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone ? const Color(0xFF4F6EF7) : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] as String,
                    style: TextStyle(
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.grey : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  if (task['due_date'] != null)
                    Text(task['due_date'] as String,
                        style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(priority, style: TextStyle(fontSize: 10, color: priorityColor)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ──────────────────────────────────────────────────────────────

Widget _FilterChipButton(String label, String? value, String? current, void Function(String?) onTap) {
  final selected = current == value;
  return Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(value),
    ),
  );
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton loading ─────────────────────────────────────────────────────────

class _TaskListSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: 5,
      itemBuilder: (_, __) => Container(
        height: 56,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D27),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
