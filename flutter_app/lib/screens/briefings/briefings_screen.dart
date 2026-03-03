import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_service.dart';

final _summariesProvider = FutureProvider.family<List<dynamic>, String>((ref, type) async {
  return ApiService().getSummaries(type: type, limit: 10);
});

class BriefingsScreen extends ConsumerStatefulWidget {
  const BriefingsScreen({super.key});

  @override
  ConsumerState<BriefingsScreen> createState() => _BriefingsScreenState();
}

class _BriefingsScreenState extends ConsumerState<BriefingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  static const _types = [
    ('daily_briefing', 'Morning Briefing'),
    ('daily_recap', 'Daily Recap'),
    ('weekly_recap', 'Weekly Recap'),
    ('monthly_recap', 'Monthly Recap'),
  ];

  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _types.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final type = _types[_tabs.index].$1;
    setState(() => _generating = true);
    try {
      await ApiService().push({'type': type}); // not ideal, but we'll call generate via POST
      // Actually call the generate endpoint directly
      final dio = ApiService();
      ref.invalidate(_summariesProvider(type));
    } finally {
      setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Summaries'),
        backgroundColor: const Color(0xFF0F1117),
        actions: [
          IconButton(
            icon: _generating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            onPressed: _generating ? null : _generate,
            tooltip: 'Generate now',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: _types.map((t) => Tab(text: t.$2)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _types.map((t) => _SummaryList(type: t.$1)).toList(),
      ),
    );
  }
}

class _SummaryList extends ConsumerWidget {
  final String type;
  const _SummaryList({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(_summariesProvider(type));

    return summariesAsync.when(
      data: (summaries) => summaries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text('No summaries yet', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text(
                    'The backend generates them automatically.\nYou can also tap ✨ to generate now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: summaries.length,
              itemBuilder: (_, i) => _SummaryCard(summary: summaries[i]),
            ),
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.red))),
    );
  }
}

class _SummaryCard extends StatefulWidget {
  final Map<String, dynamic> summary;
  const _SummaryCard({required this.summary});

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final content = widget.summary['content'] as String? ?? '';
    final date = widget.summary['period_start'] as String? ?? '';
    final model = widget.summary['model_used'] as String? ?? '';
    final genTime = widget.summary['generation_time'] as double?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Spacer(),
                  Text(
                    genTime != null ? '${genTime.toStringAsFixed(1)}s' : '',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey, size: 18),
                ],
              ),
              if (model.isNotEmpty)
                Text(model, style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 8),
              if (_expanded)
                MarkdownBody(
                  data: content,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFB0B8CC)),
                    h2: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    h3: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                )
              else
                Text(
                  content.length > 200 ? '${content.substring(0, 200)}...' : content,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFB0B8CC), height: 1.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
