import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _listsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ApiService().getLists();
});

final _itemsProvider =
    FutureProvider.family<List<dynamic>, String>((ref, listId) async {
  return ApiService().getListItems(listId);
});

// ── Lists overview screen ─────────────────────────────────────────────────────

class ListsScreen extends ConsumerWidget {
  const ListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsync = ref.watch(_listsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lists'),
        backgroundColor: const Color(0xFF0F1117),
      ),
      body: listsAsync.when(
        data: (lists) => lists.isEmpty
            ? _emptyState(context, ref)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lists.length,
                itemBuilder: (context, i) {
                  final list = lists[i] as Map<String, dynamic>;
                  return _ListCard(
                    list: list,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ListDetailScreen(list: list),
                      ),
                    ).then((_) => ref.invalidate(_listsProvider)),
                    onDelete: () async {
                      final confirmed = await _confirmDelete(context, list['name'] as String);
                      if (confirmed) {
                        await ApiService().deleteList(list['id'] as String);
                        ref.invalidate(_listsProvider);
                      }
                    },
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.grey))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateList(context, ref),
        backgroundColor: const Color(0xFF4F6EF7),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New List', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.list_alt_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No lists yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Create a shopping list, watchlist, or anything else',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Create a list'),
            onPressed: () => _showCreateList(context, ref),
          ),
        ],
      ),
    );
  }

  void _showCreateList(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D27),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateListSheet(
        onCreated: () => ref.invalidate(_listsProvider),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A1D27),
            title: const Text('Delete list?'),
            content: Text('Delete "$name" and all its items?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete', style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;
  }
}

// ── List card ─────────────────────────────────────────────────────────────────

class _ListCard extends StatelessWidget {
  final Map<String, dynamic> list;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ListCard({required this.list, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final icon = list['icon'] as String? ?? '📋';
    final color = _parseColor(list['color'] as String?);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
        ),
        title: Text(list['name'] as String,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_right, color: Colors.grey),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String? hex) {
    if (hex == null) return const Color(0xFF4F6EF7);
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF4F6EF7);
    }
  }
}

// ── Create list sheet ─────────────────────────────────────────────────────────

class _CreateListSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateListSheet({required this.onCreated});

  @override
  State<_CreateListSheet> createState() => _CreateListSheetState();
}

class _CreateListSheetState extends State<_CreateListSheet> {
  final _ctrl = TextEditingController();
  String _selectedIcon = '📋';
  bool _saving = false;

  static const _presets = [
    ('🛒', 'Shopping', '#4F6EF7'),
    ('🎬', 'Watchlist', '#9B59B6'),
    ('🎁', 'Birthday', '#E74C3C'),
    ('🎄', 'Christmas', '#27AE60'),
    ('🧳', 'Packing', '#F39C12'),
    ('📚', 'Reading', '#1ABC9C'),
    ('📋', 'Custom', '#607D8B'),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // Quick presets
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((p) {
              final (icon, name, color) = p;
              return GestureDetector(
                onTap: () {
                  _ctrl.text = name == 'Custom' ? '' : name;
                  setState(() => _selectedIcon = icon);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252836),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedIcon == icon
                          ? const Color(0xFF4F6EF7)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(icon),
                      const SizedBox(width: 6),
                      Text(name, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'List name',
              filled: true,
              fillColor: const Color(0xFF252836),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              prefixText: '$_selectedIcon  ',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiService().createList({'name': name, 'icon': _selectedIcon});
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── List detail screen (items) ────────────────────────────────────────────────

class ListDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> list;
  const ListDetailScreen({super.key, required this.list});

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  final _addCtrl = TextEditingController();
  bool _adding = false;

  String get _listId => widget.list['id'] as String;

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final text = _addCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _adding = true);
    try {
      await ApiService().addListItem(_listId, text);
      _addCtrl.clear();
      ref.invalidate(_itemsProvider(_listId));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    final nowChecked = !(item['checked'] as bool);
    await ApiService().updateListItem(
        _listId, item['id'] as String, {'checked': nowChecked ? 1 : 0});
    ref.invalidate(_itemsProvider(_listId));
  }

  Future<void> _deleteItem(String itemId) async {
    await ApiService().deleteListItem(_listId, itemId);
    ref.invalidate(_itemsProvider(_listId));
  }

  Future<void> _clearChecked() async {
    await ApiService().clearCheckedItems(_listId);
    ref.invalidate(_itemsProvider(_listId));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(_itemsProvider(_listId));
    final icon = widget.list['icon'] as String? ?? '📋';
    final name = widget.list['name'] as String;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: Text('$icon  $name'),
        backgroundColor: const Color(0xFF0F1117),
        actions: [
          itemsAsync.maybeWhen(
            data: (items) {
              final hasChecked = items.any((i) => (i as Map)['checked'] == true);
              if (!hasChecked) return const SizedBox.shrink();
              return TextButton(
                onPressed: _clearChecked,
                child: const Text('Clear done', style: TextStyle(color: Colors.grey, fontSize: 13)),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Add item input
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addCtrl,
                    decoration: InputDecoration(
                      hintText: 'Add item...',
                      filled: true,
                      fillColor: const Color(0xFF1A1D27),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _addItem(),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _adding ? null : _addItem,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F6EF7),
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _adding
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
          // Items list
          Expanded(
            child: itemsAsync.when(
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Text('No items yet — add one above',
                        style: TextStyle(color: Colors.grey)),
                  );
                }
                final unchecked = items.where((i) => (i as Map)['checked'] != true).toList();
                final checked = items.where((i) => (i as Map)['checked'] == true).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    ...unchecked.map((item) => _ItemTile(
                          item: item as Map<String, dynamic>,
                          onToggle: () => _toggleItem(item),
                          onDelete: () => _deleteItem(item['id'] as String),
                        )),
                    if (checked.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Completed', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                      ...checked.map((item) => _ItemTile(
                            item: item as Map<String, dynamic>,
                            onToggle: () => _toggleItem(item),
                            onDelete: () => _deleteItem(item['id'] as String),
                          )),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item tile ─────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ItemTile({required this.item, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final checked = item['checked'] as bool;
    return Dismissible(
      key: Key(item['id'] as String),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          dense: true,
          leading: GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: checked ? const Color(0xFF4F6EF7) : Colors.grey,
                    width: 2),
                color: checked ? const Color(0xFF4F6EF7) : Colors.transparent,
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          title: Text(
            item['text'] as String,
            style: TextStyle(
              decoration: checked ? TextDecoration.lineThrough : null,
              color: checked ? Colors.grey : null,
            ),
          ),
        ),
      ),
    );
  }
}
