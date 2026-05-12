import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/timer_provider.dart';
import '../providers/work_log_provider.dart';
import '../services/sync_service.dart';
import '../widgets/task_card.dart';
import '../widgets/timer_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    await context.read<WorkLogProvider>().loadTodayLogs(user.id!);
    if (mounted) {
      final timerProvider = context.read<TimerProvider>();
      final ongoingLogs = context
          .read<WorkLogProvider>()
          .todayLogs
          .where((l) => l.status == 0);
      for (final log in ongoingLogs) {
        timerProvider.resumeFromOngoingTask(log);
      }
    }
  }

  Future<void> _startNewTask() async {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = '开发';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(children: const [
            Icon(Icons.play_circle_outline),
            SizedBox(width: 8),
            Text('开始新任务'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '任务名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '开发', child: Row(children: [Icon(Icons.code, size: 18), SizedBox(width: 8), Text('开发')])),
                    DropdownMenuItem(value: '会议', child: Row(children: [Icon(Icons.groups, size: 18), SizedBox(width: 8), Text('会议')])),
                    DropdownMenuItem(value: '学习', child: Row(children: [Icon(Icons.school, size: 18), SizedBox(width: 8), Text('学习')])),
                    DropdownMenuItem(value: '沟通', child: Row(children: [Icon(Icons.forum, size: 18), SizedBox(width: 8), Text('沟通')])),
                    DropdownMenuItem(value: '文档', child: Row(children: [Icon(Icons.description, size: 18), SizedBox(width: 8), Text('文档')])),
                    DropdownMenuItem(value: '其他', child: Row(children: [Icon(Icons.more_horiz, size: 18), SizedBox(width: 8), Text('其他')])),
                  ],
                  onChanged: (v) => setDState(() => category = v!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.close, size: 18),
                SizedBox(width: 4),
                Text('取消'),
              ]),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.timer),
                SizedBox(width: 4),
                Text('开始计时'),
              ]),
            ),
          ],
        ),
      ),
    );

    if (result == true && titleCtrl.text.trim().isNotEmpty) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user == null) return;
      final id = await context
          .read<WorkLogProvider>()
          .startNewTask(user.id!, titleCtrl.text.trim(), category,
              notes: notesCtrl.text.trim());
      if (mounted) {
        context.read<TimerProvider>().start(
              id,
              titleCtrl.text.trim(),
              category,
            );
      }
    }
  }

  Future<void> _stopTask(int workLogId) async {
    final timer = context.read<TimerProvider>();
    final state = timer.getTimer(workLogId);
    if (state == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.stop_circle_outlined),
          SizedBox(width: 8),
          Text('结束任务'),
        ]),
        content: Text('任务 "${state.taskTitle}"\n\n计时：${state.formattedTime}\n\n确认结束吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.check_circle),
              SizedBox(width: 4),
              Text('确认结束'),
            ]),
          ),
        ],
      ),
    );
    if (result == true) {
      if (!mounted) return;
      await context.read<WorkLogProvider>().endTask(workLogId, state.elapsedSeconds);
      timer.stop(workLogId);
    }
  }

  Future<void> _addManualLog() async {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String category = '开发';
    final now = DateTime.now();
    DateTime startDate = now;
    TimeOfDay startTime = TimeOfDay.now();
    DateTime endDate = now;
    // Pre-fill end time as start time + 1 hour
    final endHour = now.add(const Duration(hours: 1));
    TimeOfDay endTime = TimeOfDay.fromDateTime(endHour);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Row(children: const [
            Icon(Icons.edit_note),
            SizedBox(width: 8),
            Text('手动补录'),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: '任务名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '开发', child: Row(children: [Icon(Icons.code, size: 18), SizedBox(width: 8), Text('开发')])),
                    DropdownMenuItem(value: '会议', child: Row(children: [Icon(Icons.groups, size: 18), SizedBox(width: 8), Text('会议')])),
                    DropdownMenuItem(value: '学习', child: Row(children: [Icon(Icons.school, size: 18), SizedBox(width: 8), Text('学习')])),
                    DropdownMenuItem(value: '沟通', child: Row(children: [Icon(Icons.forum, size: 18), SizedBox(width: 8), Text('沟通')])),
                    DropdownMenuItem(value: '文档', child: Row(children: [Icon(Icons.description, size: 18), SizedBox(width: 8), Text('文档')])),
                    DropdownMenuItem(value: '其他', child: Row(children: [Icon(Icons.more_horiz, size: 18), SizedBox(width: 8), Text('其他')])),
                  ],
                  onChanged: (v) => setDState(() => category = v!),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('开始时间'),
                        subtitle: Text(
                          '${startDate.toString().split(' ')[0]} ${startTime.format(ctx)}',
                        ),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (!ctx.mounted) return;
                          if (d != null) {
                            setDState(() => startDate = d);
                          }
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: startTime,
                          );
                          if (!ctx.mounted) return;
                          if (t != null) setDState(() => startTime = t);
                        },
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('结束时间'),
                        subtitle: Text(
                          '${endDate.toString().split(' ')[0]} ${endTime.format(ctx)}',
                        ),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate: endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (!ctx.mounted) return;
                          if (d != null) setDState(() => endDate = d);
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: endTime,
                          );
                          if (!ctx.mounted) return;
                          if (t != null) setDState(() => endTime = t);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.close, size: 18),
                SizedBox(width: 4),
                Text('取消'),
              ]),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.save),
                SizedBox(width: 4),
                Text('保存'),
              ]),
            ),
          ],
        ),
      ),
    );

    if (result == true && titleCtrl.text.trim().isNotEmpty) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      if (user == null) return;
      final sMs = DateTime(startDate.year, startDate.month, startDate.day,
              startTime.hour, startTime.minute)
          .millisecondsSinceEpoch;
      final eMs = DateTime(endDate.year, endDate.month, endDate.day,
              endTime.hour, endTime.minute)
          .millisecondsSinceEpoch;
      if (eMs <= sMs) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Row(children: const [Icon(Icons.warning, color: Colors.white, size: 20), SizedBox(width: 8), Text('结束时间必须晚于开始时间')])),
          );
        }
        return;
      }
      await context.read<WorkLogProvider>().addManualLog(
            user.id!,
            titleCtrl.text.trim(),
            category,
            sMs,
            eMs,
            notesCtrl.text.trim(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final logs = context.watch<WorkLogProvider>().todayLogs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('工作打卡'),
        centerTitle: false,
        actions: [
          Consumer<SyncService>(
            builder: (context, sync, child) {
              if (!sync.hasServer) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Tooltip(
                  message: sync.isSyncing ? '同步中...' : '同步完成',
                  child: Icon(
                    sync.isSyncing ? Icons.sync : Icons.cloud_done,
                    size: 20,
                    color: sync.isSyncing ? Colors.orange : Colors.green,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: isWide ? _buildWideLayout(logs) : _buildNarrowLayout(logs),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewTask,
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始工作'),
      ),
    );
  }

  Widget _buildNarrowLayout(List logs) {
    final activeTimers = context.watch<TimerProvider>().activeTimers;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...activeTimers.map((t) => TimerWidget(
                workLogId: t.workLogId,
                onStop: _stopTask,
              )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.list_alt, size: 20),
                    const SizedBox(width: 6),
                    const Text('今日记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _addManualLog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('补录'),
                ),
              ],
            ),
          ),
          if (logs.isEmpty)
            SizedBox(
              height: 300,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('暂无记录，点击下方按钮开始'),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: logs.length,
              itemBuilder: (_, i) => TaskCard(log: logs[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildWideLayout(List logs) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              ...context.watch<TimerProvider>().activeTimers.map(
                    (t) => TimerWidget(
                      workLogId: t.workLogId,
                      onStop: _stopTask,
                    ),
                  ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.list_alt, size: 20),
                        const SizedBox(width: 6),
                        const Text('今日记录',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addManualLog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('补录'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('暂无记录，点击右下角按钮开始'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: logs.length,
                        itemBuilder: (_, i) => TaskCard(log: logs[i]),
                      ),
              ),
            ],
          ),
        ),
        Container(
          width: 1,
          color: Colors.grey.shade300,
          margin: const EdgeInsets.symmetric(vertical: 16),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildQuickStats(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    return const _QuickStatsCard();
  }
}

class _QuickStatsCard extends StatelessWidget {
  const _QuickStatsCard();

  @override
  Widget build(BuildContext context) {
    final logs = context.watch<WorkLogProvider>().todayLogs;
    int totalSecs = 0;
    int completed = 0;
    final catMap = <String, int>{};
    for (final log in logs) {
      if (log.status == 1) {
        totalSecs += log.duration;
        completed++;
        catMap[log.category] = (catMap[log.category] ?? 0) + log.duration;
      }
    }
    final h = totalSecs ~/ 3600;
    final m = (totalSecs % 3600) ~/ 60;
    final s = totalSecs % 60;

    String fmtDuration(int secs) {
      final fh = secs ~/ 3600;
      final fm = (secs % 3600) ~/ 60;
      final fs = secs % 60;
      if (fh > 0) return '${fh}h ${fm}m ${fs}s';
      if (fm > 0) return '${fm}m ${fs}s';
      return '${fs}s';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: const [
          Icon(Icons.today, size: 20),
          SizedBox(width: 6),
          Text('今日概览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem(Icons.timer, '工作时长', '${h}h ${m}m ${s}s'),
                    _statItem(Icons.task_alt, '完成任务', '$completed 个'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: const [
          Icon(Icons.pie_chart_outline, size: 20),
          SizedBox(width: 6),
          Text('分类分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 8),
        ...catMap.entries.map((e) {
          final pct = totalSecs > 0 ? (e.value / totalSecs * 100).toStringAsFixed(1) : '0';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 48, child: Text(e.key, style: const TextStyle(fontSize: 13))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalSecs > 0 ? e.value / totalSecs : 0,
                      minHeight: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                    width: 110,
                    child: Text('${fmtDuration(e.value)} $pct%',
                        style: const TextStyle(fontSize: 12), textAlign: TextAlign.right)),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 32),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}
