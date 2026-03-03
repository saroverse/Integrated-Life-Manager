import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/health_service.dart';
import '../../services/sync_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _syncing = false;
  String? _syncResult;

  Future<void> _manualSync() async {
    setState(() { _syncing = true; _syncResult = null; });
    try {
      final result = await SyncService().syncAll();
      setState(() {
        _syncResult = result.hasError
            ? 'Error: ${result.error}'
            : 'Synced ${result.healthMetrics} health records, ${result.screenTimeEntries} screen time entries';
      });
    } finally {
      setState(() => _syncing = false);
    }
  }

  Future<void> _requestHealthPermission() async {
    final granted = await HealthService().requestPermissions();
    setState(() {
      _syncResult = granted ? '✅ Health Connect permissions granted' : '❌ Permission denied';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF0F1117),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_syncResult != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _syncResult!.contains('Error') || _syncResult!.contains('❌')
                    ? Colors.red.shade900.withOpacity(0.3)
                    : Colors.green.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_syncResult!, style: const TextStyle(fontSize: 13)),
            ),

          const _SectionHeader('Data Sync'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite_outline, color: Color(0xFF4F6EF7)),
                  title: const Text('Health Connect Permissions'),
                  subtitle: const Text('Grant access to Amazfit health data'),
                  trailing: FilledButton.tonal(
                    onPressed: _requestHealthPermission,
                    child: const Text('Grant'),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_android, color: Color(0xFF4F6EF7)),
                  title: const Text('Screen Time Access'),
                  subtitle: const Text('Samsung: Settings > Apps > Special App Access > Usage Access'),
                  trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync, color: Color(0xFF4F6EF7)),
                  title: const Text('Sync Now'),
                  subtitle: const Text('Manually push health + screen time to backend'),
                  trailing: _syncing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : FilledButton.tonal(onPressed: _manualSync, child: const Text('Sync')),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const _SectionHeader('Connection'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined, color: Color(0xFF4F6EF7)),
              title: const Text('Backend URL'),
              subtitle: const Text('Edit lib/config/constants.dart to change'),
              trailing: const Icon(Icons.info_outline, size: 16, color: Colors.grey),
            ),
          ),

          const SizedBox(height: 16),
          const _SectionHeader('About'),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Integrated Life Manager'),
                  subtitle: const Text('Version 1.0.0'),
                  leading: const Icon(Icons.info_outline),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Amazfit Setup'),
                  subtitle: const Text('Zepp app → Profile → Connected Apps → Health Connect'),
                  leading: const Icon(Icons.watch_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 0.8, fontWeight: FontWeight.w600),
      ),
    );
  }
}
