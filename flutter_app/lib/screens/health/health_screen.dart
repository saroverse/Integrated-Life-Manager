import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';

final _healthSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final today = await ApiService().getHealthSummary();
  // If today has no steps yet (morning before Zepp sync), also fetch yesterday as fallback
  if ((today['steps'] as num?) == 0 || today['steps'] == null) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2,'0')}-${yesterday.day.toString().padLeft(2,'0')}';
    try {
      final prev = await ApiService().getHealthSummary(date: yStr);
      // Merge: use today's sleep if present, yesterday's steps/HR if today's is empty
      return {
        ...prev,
        'steps': today['steps'] ?? prev['steps'],
        '_steps_note': today['steps'] == null || (today['steps'] as num) == 0 ? 'yesterday' : null,
      };
    } catch (_) {}
  }
  return today;
});

class HealthScreen extends ConsumerStatefulWidget {
  const HealthScreen({super.key});

  @override
  ConsumerState<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends ConsumerState<HealthScreen> {
  bool _syncing = false;
  String? _syncMessage;

  Future<void> _requestAndSync() async {
    setState(() { _syncing = true; _syncMessage = null; });
    try {
      final result = await ApiService().triggerZeppSync(days: 3);
      final steps = result['steps_today'] ?? result['steps'] ?? '?';
      setState(() { _syncMessage = 'Synced from Zepp cloud'; });
      ref.invalidate(_healthSummaryProvider);
    } catch (e) {
      setState(() { _syncMessage = 'Sync failed: $e'; });
    } finally {
      setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(_healthSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Health'),
        backgroundColor: const Color(0xFF0F1117),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
            onPressed: _syncing ? null : _requestAndSync,
          ),
        ],
      ),
      body: summaryAsync.when(
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_syncMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: _syncMessage!.contains('error') ? Colors.red.shade900.withOpacity(0.3) : Colors.green.shade900.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_syncMessage!, style: const TextStyle(fontSize: 13)),
              ),
            _HealthCard(
              icon: Icons.directions_walk,
              label: s['_steps_note'] == 'yesterday' ? 'Steps Yesterday' : 'Steps Today',
              value: (s['steps'] as num?)?.toInt() != 0
                  ? (s['steps'] as num?)?.toInt().toString() ?? '—'
                  : '—',
              sub: 'steps',
            ),
            _HealthCard(
              icon: Icons.favorite,
              label: 'Resting Heart Rate',
              value: s['resting_heart_rate']?.toString() ?? '—',
              sub: 'bpm',
            ),
            _HealthCard(
              icon: Icons.timeline,
              label: 'HRV',
              value: s['heart_rate_variability_sdnn']?.toString() ?? '—',
              sub: 'ms · recovery indicator',
            ),
            if (s['sleep'] != null) ...[
              _SleepCard(sleep: s['sleep'] as Map<String, dynamic>),
            ],
            const SizedBox(height: 8),
            const Text(
              'Data sourced from Amazfit Heliostrap via Zepp cloud sync',
              style: TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Could not load health data.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.sync),
                label: const Text('Retry'),
                onPressed: _requestAndSync,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  const _HealthCard({required this.icon, required this.label, required this.value, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF4F6EF7).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4F6EF7), size: 20),
        ),
        title: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        subtitle: Text('$label · $sub', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ),
    );
  }
}

class _SleepCard extends StatelessWidget {
  final Map<String, dynamic> sleep;
  const _SleepCard({required this.sleep});

  @override
  Widget build(BuildContext context) {
    final total = sleep['total'] as double?;
    final deep = sleep['deep'] as double?;
    final rem = sleep['rem'] as double?;
    final score = sleep['score'] as int?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bedtime, color: Color(0xFF4F6EF7), size: 20),
                const SizedBox(width: 10),
                const Text('Sleep Last Night', style: TextStyle(fontWeight: FontWeight.bold)),
                if (score != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F6EF7).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Score: $score', style: const TextStyle(fontSize: 11, color: Color(0xFF4F6EF7))),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _SleepStat('Total', total != null ? '${total.toStringAsFixed(1)}h' : '—'),
                _SleepStat('Deep', deep != null ? '${deep.toStringAsFixed(1)}h' : '—'),
                _SleepStat('REM', rem != null ? '${rem.toStringAsFixed(1)}h' : '—'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SleepStat extends StatelessWidget {
  final String label;
  final String value;
  const _SleepStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
