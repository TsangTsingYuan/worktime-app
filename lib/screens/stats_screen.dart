import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/work_log.dart';
import '../providers/work_log_provider.dart';
import '../providers/todo_provider.dart';
import '../providers/auth_provider.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _range = 'today';
  int _todoCompleted = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final wp = context.read<WorkLogProvider>();
    wp.loadTodayLogs(user.id!);
    wp.loadWeekLogs(user.id!);
    wp.loadMonthLogs(user.id!);
    _loadTodoStats(user.id!);
  }

  Future<void> _loadTodoStats(int userId) async {
    final now = DateTime.now();
    int startMs;
    int endMs = DateTime(now.year, now.month, now.day, 23, 59, 59).millisecondsSinceEpoch;

    switch (_range) {
      case 'today':
        startMs = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
        break;
      case 'week':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        startMs = DateTime(weekStart.year, weekStart.month, weekStart.day).millisecondsSinceEpoch;
        break;
      case 'month':
      default:
        startMs = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
        break;
    }

    final count = await context.read<TodoProvider>().getCompletedCount(userId, startMs, endMs);
    if (mounted) setState(() => _todoCompleted = count);
  }

  List<MapEntry<String, int>> _aggregateByCategory(List<WorkLog> logs) {
    final map = <String, int>{};
    for (final log in logs) {
      if (log.status == 1) {
        map[log.category] = (map[log.category] ?? 0) + log.duration;
      }
    }
    final entries = map.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  bool _isWide(BuildContext context) => MediaQuery.of(context).size.width > 600;

  @override
  Widget build(BuildContext context) {
    final wp = context.watch<WorkLogProvider>();
    final List<WorkLog> logs = _range == 'today'
        ? wp.todayLogs
        : _range == 'week'
            ? wp.weekLogs
            : wp.monthLogs;

    final completed = logs.where((l) => l.status == 1).toList();
    final totalSecs = completed.fold<int>(0, (sum, l) => sum + l.duration);
    final cats = _aggregateByCategory(completed);
    final isWide = _isWide(context);

    return Scaffold(
      appBar: AppBar(title: const Text('统计报表')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'today', label: Text('今日'), icon: Icon(Icons.today)),
                    ButtonSegment(value: 'week', label: Text('本周'), icon: Icon(Icons.date_range)),
                    ButtonSegment(value: 'month', label: Text('本月'), icon: Icon(Icons.calendar_month)),
                  ],
                  selected: {_range},
                  onSelectionChanged: (v) {
                    setState(() => _range = v.first);
                    final user = context.read<AuthProvider>().user;
                    if (user != null) _loadTodoStats(user.id!);
                  },
                ),
                const SizedBox(height: 24),
                // Overview cards
                _buildOverviewCards(totalSecs, completed.length),
                const SizedBox(height: 24),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildPieChartSection(cats, totalSecs),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 3,
                        child: _buildDailyDetailSection(completed),
                      ),
                    ],
                  )
                else ...[
                  _buildPieChartSection(cats, totalSecs),
                  const SizedBox(height: 24),
                  _buildDailyDetailSection(completed),
                ],
                const SizedBox(height: 32),
                _buildTodoStatsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards(int totalSecs, int completedCount) {
    final isWide = _isWide(context);
    final cards = [
      _OverviewCard(
        title: '工作时长',
        value: _formatDuration(totalSecs),
        icon: Icons.timer,
      ),
      _OverviewCard(
        title: '完成任务',
        value: '$completedCount 个',
        icon: Icons.task_alt,
      ),
      _OverviewCard(
        title: '完成待办',
        value: '$_todoCompleted 个',
        icon: Icons.checklist,
      ),
    ];

    if (isWide) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: c,
        ))).toList(),
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 16),
        Expanded(child: cards[1]),
      ],
    );
  }

  Widget _buildPieChartSection(List<MapEntry<String, int>> cats, int totalSecs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const [
          Icon(Icons.pie_chart_outline, size: 20),
          SizedBox(width: 6),
          Text('分类统计',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        if (cats.isEmpty)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('暂无数据'),
              ],
            ),
          )
        else
          _buildPieChart(cats, totalSecs),
      ],
    );
  }

  Widget _buildDailyDetailSection(List<WorkLog> completed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const [
          Icon(Icons.list_alt, size: 20),
          SizedBox(width: 6),
          Text('每日明细',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        ...completed.reversed.map((log) {
          final date = DateTime.fromMillisecondsSinceEpoch(log.startTime);
          final dateStr = DateFormat('MM/dd HH:mm').format(date);
          return ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(log.title),
            subtitle: Text('$dateStr  ${log.category}'),
            trailing: Text(_formatDuration(log.duration)),
          );
        }),
      ],
    );
  }

  Widget _buildTodoStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const [
          Icon(Icons.checklist, size: 20),
          SizedBox(width: 6),
          Text('待办统计',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        _OverviewCard(
          title: '完成待办',
          value: '$_todoCompleted 个',
          icon: Icons.task_alt,
        ),
      ],
    );
  }

  Widget _buildPieChart(List<MapEntry<String, int>> cats, int totalSecs) {
    final colors = [Colors.blue, Colors.green, Colors.orange,
        Colors.purple, Colors.teal, Colors.red];
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _PiePainter(cats, totalSecs, colors),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: cats.asMap().entries.map((e) {
                final i = e.key;
                final cat = e.value;
                final pct = totalSecs > 0
                    ? (cat.value / totalSecs * 100).toStringAsFixed(1)
                    : '0';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${cat.key}  ${_formatDuration(cat.value)} ($pct%)',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  final List<MapEntry<String, int>> data;
  final int total;
  final List<Color> colors;

  _PiePainter(this.data, this.total, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    double startAngle = -90 * (3.14159 / 180);

    if (data.isEmpty) {
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    for (var i = 0; i < data.length; i++) {
      final sweep = data[i].value / total * 360;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep * (3.14159 / 180),
        true,
        paint,
      );
      startAngle += sweep * (3.14159 / 180);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, color: Colors.blue, size: 36),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
