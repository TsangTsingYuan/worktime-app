import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';
import 'models/todo_item.dart';
import 'providers/auth_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/work_log_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/todo_provider.dart';
import 'services/reminder_service.dart'
    if (dart.library.html) 'services/reminder_service_web.dart';
import 'services/api_client.dart';
import 'services/sync_service.dart';
import 'services/database_helper.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/todo_screen.dart';
import 'screens/settings_screen.dart';

/// Backend API URL.
/// Override at build time: flutter build web --dart-define=API_URL=https://your-server.com
const String _kApiBaseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

/// Shared instances (live as long as the app lives)
final _db = DatabaseHelper();
final _apiClient = ApiClient(_kApiBaseUrl);
final _syncService = SyncService(_apiClient, _db);

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
        ChangeNotifierProvider(create: (_) => AuthProvider(_apiClient, _syncService)),
        ChangeNotifierProvider(create: (_) => TimerProvider()),
        ChangeNotifierProvider(create: (_) => WorkLogProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => TodoProvider()),
        ChangeNotifierProvider(create: (_) => ReminderService()),
        ChangeNotifierProvider.value(value: _syncService),
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
  late final SyncService _syncService;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _settings = context.read<SettingsProvider>();
    _workLog = context.read<WorkLogProvider>();
    _reminderService = context.read<ReminderService>();
    _syncService = context.read<SyncService>();

    _reminderService.initializeVisibilityListener();

    if (_auth.user != null) {
      _settings.loadFromJson(_auth.user!.config);
    }

    if (_auth.isLoggedIn) {
      _reminderService.start(_settings, _workLog);
      _triggerSync();
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
      _triggerSync();
    } else {
      _reminderService.stop();
    }
  }

  void _triggerSync() {
    final user = _auth.user;
    if (user != null && user.id != null && _syncService.hasServer) {
      _syncService.sync(user.id!);
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

  void _startTimerFromTodo(TodoItem todo) {
    final user = _auth.user;
    if (user == null || user.id == null) return;
    final userId = user.id!;
    final workLogProvider = context.read<WorkLogProvider>();
    final timerProvider = context.read<TimerProvider>();
    final todoProvider = context.read<TodoProvider>();
    // Switch to home tab
    setState(() => _currentIndex = 0);
    // Start a new work log and timer from this todo
    workLogProvider.loadTodayLogs(userId).then((_) {
      return workLogProvider.startNewTask(
        userId,
        todo.title,
        todo.category.isNotEmpty ? todo.category : '其他',
        notes: todo.description,
      );
    }).then((workLogId) {
      timerProvider.start(workLogId, todo.title, todo.category.isNotEmpty ? todo.category : '其他');
      if (todo.id != null) {
        todoProvider.updateTodo(todo.copyWith(linkedWorkLogId: workLogId));
      }
    });
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
                  icon: Icon(Icons.checklist_outlined),
                  selectedIcon: Icon(Icons.checklist),
                  label: Text('待办'),
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
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: '待办',
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
        return TodoScreen(
          onStartTimerFromTodo: _startTimerFromTodo,
        );
      case 3:
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }
}
