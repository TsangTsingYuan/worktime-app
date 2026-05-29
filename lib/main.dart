import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_stub_init.dart'
    if (dart.library.html) 'services/database_web_init.dart';
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
  configureDatabase();
  // 预初始化数据库，减少首次启动时的等待
  unawaited(_db.database);
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
        title: 'Time Flies',
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
  bool _autoLoginChecking = true;

  final Map<int, int> _todoByWorkLogId = {}; // workLogId -> todoId (for auto-complete)

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _settings = context.read<SettingsProvider>();
    _workLog = context.read<WorkLogProvider>();
    _reminderService = context.read<ReminderService>();
    _syncService = context.read<SyncService>();

    _reminderService.initializeVisibilityListener();

    _tryAutoLogin();

    _auth.addListener(_onAuthChanged);
    _settings.addListener(_onSettingsChanged);
    _reminderService.addListener(_onPendingMessage);
  }

  Future<void> _tryAutoLogin() async {
    final loggedIn = await _auth.autoLogin();
    if (!mounted) return;
    setState(() => _autoLoginChecking = false);
    if (loggedIn) {
      if (_auth.user != null) {
        _settings.loadFromJson(_auth.user!.config);
      }
      _reminderService.start(_settings, _workLog, _auth, todoProvider: context.read<TodoProvider>());
      _triggerSync();
    }
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
      _reminderService.start(_settings, _workLog, _auth, todoProvider: context.read<TodoProvider>());
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
    final action = _reminderService.pendingAction;
    final msg = _reminderService.pendingMessage;
    if (msg == null || !mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        if (action != null) {
          // 待办提醒：显示可操作按钮
          return AlertDialog(
            title: const Row(children: [
              Icon(Icons.notifications_active, color: Colors.blue),
              SizedBox(width: 8),
              Text('待办提醒'),
            ]),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _reminderService.clearPendingMessage();
                },
                child: const Text('知道了'),
              ),
              if (action.type == 'start' || action.type == 'overdue')
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _reminderService.clearPendingMessage();
                    _executeTodoFromReminder(action.todoId);
                  },
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('开始执行'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              if (action.type == 'end' || action.type == 'overdue')
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _reminderService.clearPendingMessage();
                    _completeTodoFromReminder(action.todoId);
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('标记完成'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                ),
            ],
          );
        }

        // 普通提醒（久坐/下班）
        return AlertDialog(
          title: const Row(children: [
            Icon(Icons.notifications_active, color: Colors.blue),
            SizedBox(width: 8),
            Text('提醒'),
          ]),
          content: Text(msg),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _reminderService.clearPendingMessage();
              },
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }

  /// 从提醒弹窗开始执行待办
  void _executeTodoFromReminder(int todoId) {
    final todoProvider = context.read<TodoProvider>();
    final todo = todoProvider.todos.where((t) => t.id == todoId).toList();
    if (todo.isEmpty) return;
    // 标记开始执行并跳转计时
    todoProvider.startExecution(todo.first).then((updated) {
      _startTimerFromTodo(updated);
    });
  }

  /// 从提醒弹窗标记待办完成
  void _completeTodoFromReminder(int todoId) {
    final todoProvider = context.read<TodoProvider>();
    final todo = todoProvider.todos.where((t) => t.id == todoId).toList();
    if (todo.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    todoProvider.completeOnTimerEnd(
      todo.first.copyWith(
        status: 2,
        updatedAt: now,
      ),
      0, // 无关联工作记录
    );
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
        // 如果待办是"执行中"(status=1)，记录用于结束时自动完成
        if (todo.status == 1) {
          _todoByWorkLogId[workLogId] = todo.id!;
          // 监听 TimerProvider 变化
          timerProvider.addListener(_onTimerChanged);
        }
      }
    });
  }

  void _onTimerChanged() {
    if (!mounted) return;
    final timerProvider = context.read<TimerProvider>();
    final activeIds = timerProvider.activeTimers.map((t) => t.workLogId).toSet();
    bool changed = false;
    for (final entry in _todoByWorkLogId.entries.toList()) {
      if (!activeIds.contains(entry.key)) {
        // 计时结束，标记待办完成
        final todoProvider = context.read<TodoProvider>();
        final todos = todoProvider.todos.where((t) => t.id == entry.value).toList();
        if (todos.isNotEmpty) {
          todoProvider.completeOnTimerEnd(todos.first, entry.key);
        }
        _todoByWorkLogId.remove(entry.key);
        changed = true;
      }
    }
    if (changed && _todoByWorkLogId.isEmpty) {
      // 没有更多执行中的待办，移除监听
      timerProvider.removeListener(_onTimerChanged);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_autoLoginChecking) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在验证登录状态...'),
            ],
          ),
        ),
      );
    }

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
