import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/local_cache.dart';
import 'services/sync_service.dart';

import 'screens/home/home_screen.dart';
import 'screens/planner/planner_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/health/health_screen.dart';
import 'screens/briefings/briefings_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/screen_time/screen_time_screen.dart';
import 'screens/habits/add_habit_screen.dart';
import 'screens/habits/habit_detail_screen.dart';
import 'screens/tasks/add_task_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNav(child: child),
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/tasks', builder: (_, __) => const PlannerScreen()),
        GoRoute(path: '/stats', builder: (_, __) => const StatsScreen()),
        GoRoute(path: '/health', builder: (_, __) => const HealthScreen()),
        GoRoute(path: '/briefings', builder: (_, __) => const BriefingsScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
    GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
    GoRoute(path: '/screen-time', builder: (_, __) => const ScreenTimeScreen()),
    GoRoute(path: '/habits/add', builder: (_, __) => const AddHabitScreen()),
    GoRoute(
      path: '/habits/:id',
      builder: (_, state) => HabitDetailScreen(habitId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/tasks/add', builder: (_, __) => const AddTaskScreen()),
  ],
);

class ILMApp extends StatelessWidget {
  const ILMApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Life Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F6EF7),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        cardColor: const Color(0xFF1A1D27),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

class ScaffoldWithNav extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNav({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      appBar: location == '/settings'
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF1A1D27),
              automaticallyImplyLeading: false,
              title: const Text('Life Manager', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () => context.go('/settings'),
                ),
              ],
            ),
      body: Column(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: pendingOpsNotifier,
            builder: (_, count, __) => count > 0
                ? _OfflineBanner(count: count)
                : const SizedBox.shrink(),
          ),
          Expanded(child: child),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chat'),
        backgroundColor: const Color(0xFF4F6EF7),
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1A1D27),
        selectedIndex: _selectedIndex(location),
        onDestinationSelected: (i) => context.go(_routes[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Planner'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Health'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI'),
        ],
      ),
    );
  }

  static const _routes = ['/', '/tasks', '/stats', '/health', '/briefings'];

  int _selectedIndex(String location) {
    for (int i = _routes.length - 1; i >= 0; i--) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }
}

// ─── Offline Banner ───────────────────────────────────────────────────────────

class _OfflineBanner extends StatefulWidget {
  final int count;
  const _OfflineBanner({required this.count});

  @override
  State<_OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<_OfflineBanner> {
  bool _syncing = false;

  Future<void> _trySyncNow() async {
    setState(() => _syncing = true);
    await SyncService().flushPendingOps();
    setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2A1F00),
      child: InkWell(
        onTap: _syncing ? null : _trySyncNow,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Color(0xFFF39C12), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.count} unsaved change${widget.count == 1 ? '' : 's'} — will sync when back online',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFFF39C12)),
                ),
              ),
              _syncing
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Color(0xFFF39C12)))
                  : const Text('Retry',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFF39C12),
                          fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
