import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';
import 'providers/auth_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/work_log_provider.dart';
import 'providers/settings_provider.dart';
import 'services/reminder_service.dart'
    if (dart.library.html) 'services/reminder_service_web.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
  runApp(const WorktimeApp());
}

class WorktimeApp extends StatelessWidget {
  const WorktimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => WorkLogProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ReminderService()),
      ],
      child: MaterialApp(
        title: '工作打卡',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late final AuthProvider _auth;
  late final SettingsProvider _settings;
  late final WorkLogProvider _workLog;
  late final ReminderService _reminderService;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _settings = context.read<SettingsProvider>();
    _workLog = context.read<WorkLogProvider>();
    _reminderService = context.read<ReminderService>();

    _reminderService.initializeVisibilityListener();

    if (_auth.user != null) {
      _settings.loadFromJson(_auth.user!.config);
    }

    if (_auth.isLoggedIn) {
      _reminderService.start(_settings, _workLog);
    }

    _auth.addListener(_onAuthChanged);
    _settings.addListener(_onSettingsChanged);
    _reminderService.addListener(_onPendingMessage);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _settings.removeListener(_onSettingsChanged);
    _reminderService.removeListener(_onPendingMessage);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_auth.isLoggedIn && _auth.user != null) {
      _settings.loadFromJson(_auth.user!.config);
      _reminderService.start(_settings, _workLog);
    } else {
      _reminderService.stop();
    }
  }

  void _onSettingsChanged() {
    _reminderService.update(_settings);
  }

  void _onPendingMessage() {
    final msg = _reminderService.pendingMessage;
    if (msg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
      );
      _reminderService.clearPendingMessage();
    }
  }

  void _onNavigate(int index) {
    if (index == 0) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<WorkLogProvider>().loadTodayLogs(user.id!);
      }
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    if (!isLoggedIn) return const LoginScreen();

    final isWide = MediaQuery.of(context).size.width > 600;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onNavigate,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.timer_outlined),
                  selectedIcon: Icon(Icons.timer),
                  label: Text('打卡'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('统计'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('设置'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _buildPage()),
          ],
        ),
      );
    }

    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onNavigate,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: '打卡',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_currentIndex) {
      case 0:
        return const HomeScreen();
      case 1:
        return const StatsScreen();
      case 2:
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }
}
