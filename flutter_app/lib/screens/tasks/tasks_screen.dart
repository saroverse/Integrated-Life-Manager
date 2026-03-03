import 'package:flutter/material.dart';
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
                _FilterChip('All', null, _filterStatus, (s) => setState(() => _filterStatus = s)),
                _FilterChip('Pending', 'pending', _filterStatus, (s) => setState(() => _filterStatus = s)),
                _FilterChip('Done', 'done', _filterStatus, (s) => setState(() => _filterStatus = s)),
              ],
            ),
          ),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) => tasks.isEmpty
                  ? const Center(child: Text('No tasks yet', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: tasks.length,
                      itemBuilder: (_, i) => _TaskTile(
                        task: tasks[i],
                        onComplete: () async {
                          await ApiService().completeTask(tasks[i]['id'] as String);
                          ref.invalidate(_tasksProvider);
                        },
                        onDelete: () async {
                          await ApiService().deleteTask(tasks[i]['id'] as String);
                          ref.invalidate(_tasksProvider);
                        },
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskSheet(BuildContext context) async {
    final titleController = TextEditingController();
    String priority = 'medium';
    String? dueDate;

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
                onChanged: (v) => setState(() => priority = v!),
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
                      if (dueDate != null) 'due_date': dueDate,
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

Widget _FilterChip(String label, String? value, String? current, void Function(String?) onTap) {
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

class _TaskTile extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  const _TaskTile({required this.task, required this.onComplete, required this.onDelete});

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
      child: ListTile(
        leading: GestureDetector(
          onTap: isDone ? null : onComplete,
          child: Icon(
            isDone ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isDone ? const Color(0xFF4F6EF7) : Colors.grey,
          ),
        ),
        title: Text(
          task['title'] as String,
          style: TextStyle(
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? Colors.grey : Colors.white,
            fontSize: 14,
          ),
        ),
        subtitle: task['due_date'] != null
            ? Text(task['due_date'] as String, style: const TextStyle(fontSize: 11))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(priority, style: TextStyle(fontSize: 10, color: priorityColor)),
            ),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
