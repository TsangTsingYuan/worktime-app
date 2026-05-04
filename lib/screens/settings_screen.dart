import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/work_log_provider.dart';
import '../services/file_downloader.dart'
    if (dart.library.html) '../services/file_downloader_web.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final settings = context.watch<SettingsProvider>().settings;

    return Scaffold(
      appBar: AppBar(title: const Text('个人设置')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile section
              _SectionHeader(title: '个人档案', icon: Icons.person),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Text(
                    (user?.nickname ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(user?.nickname ?? ''),
                subtitle: Text(user?.phone ?? ''),
                trailing: const Icon(Icons.edit),
                onTap: () => _editNickname(context),
              ),

              const Divider(),
              _SectionHeader(title: '工作时间配置', icon: Icons.work_history),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('上班时间'),
                subtitle: Text(settings.workStart),
                onTap: () => _pickTime(context, true),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('下班时间'),
                subtitle: Text(settings.workEnd),
                onTap: () => _pickTime(context, false),
              ),
              ListTile(
                leading: const Icon(Icons.free_breakfast),
                title: const Text('午休时长'),
                subtitle: Text('${settings.breakDuration} 分钟'),
                onTap: () => _editBreakDuration(context),
              ),

              const Divider(),
              _SectionHeader(title: '提醒配置', icon: Icons.notifications_outlined),
              SwitchListTile(
                secondary: const Icon(Icons.accessibility_new),
                title: const Text('久坐提醒'),
                subtitle: Text(settings.sedentaryReminder > 0
                    ? '每 ${settings.sedentaryReminder} 分钟提醒一次'
                    : '已关闭，点击设置提醒间隔'),
                value: settings.sedentaryReminder > 0,
                onChanged: (v) {
                  if (v) {
                    _editSedentaryReminder(context);
                  } else {
                    final s = context.read<SettingsProvider>().settings;
                    final u = context.read<AuthProvider>().user;
                    context.read<SettingsProvider>().updateSettings(
                      WorkSettings(
                        workStart: s.workStart,
                        workEnd: s.workEnd,
                        breakDuration: s.breakDuration,
                        sedentaryReminder: 0,
                        offWorkReminder: s.offWorkReminder,
                      ),
                      u!.id!,
                    );
                  }
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notification_important),
                title: const Text('下班未打卡提醒'),
                subtitle: const Text('下班后检测是否已打卡'),
                value: settings.offWorkReminder,
                onChanged: (v) => _toggleSetting(context, offWorkReminder: v),
              ),

              const Divider(),
              _SectionHeader(title: '数据管理', icon: Icons.storage),
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('导出今日数据'),
                subtitle: const Text('导出为 CSV 文件'),
                onTap: () => _exportData(context),
              ),
              ListTile(
                leading: const Icon(Icons.file_download),
                title: const Text('导出本周数据'),
                subtitle: const Text('导出为 CSV 文件'),
                onTap: () => _exportData(context, range: 'week'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('清空今日数据', style: TextStyle(color: Colors.red)),
                onTap: () => _clearData(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editNickname(BuildContext context) async {
    final ctrl = TextEditingController(
      text: context.read<AuthProvider>().user?.nickname ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.edit),
          SizedBox(width: 8),
          Text('修改昵称'),
        ]),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.close, size: 18), SizedBox(width: 4), Text('取消')])),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.check), SizedBox(width: 4), Text('确认')]),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      context.read<AuthProvider>().updateProfile(result);
    }
  }

  void _pickTime(BuildContext context, bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    final formatted = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final settings = context.read<SettingsProvider>().settings;
    final user = context.read<AuthProvider>().user;
    final newSettings = isStart
        ? WorkSettings(
            workStart: formatted,
            workEnd: settings.workEnd,
            breakDuration: settings.breakDuration,
            sedentaryReminder: settings.sedentaryReminder,
            offWorkReminder: settings.offWorkReminder,
          )
        : WorkSettings(
            workStart: settings.workStart,
            workEnd: formatted,
            breakDuration: settings.breakDuration,
            sedentaryReminder: settings.sedentaryReminder,
            offWorkReminder: settings.offWorkReminder,
          );
    context.read<SettingsProvider>().updateSettings(newSettings, user!.id!);
  }

  void _editBreakDuration(BuildContext context) async {
    final ctrl = TextEditingController(
      text: context.read<SettingsProvider>().settings.breakDuration.toString(),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.free_breakfast),
          SizedBox(width: 8),
          Text('午休时长（分钟）'),
        ]),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.close, size: 18), SizedBox(width: 4), Text('取消')])),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.check), SizedBox(width: 4), Text('确认')]),
          ),
        ],
      ),
    );
    if (result != null) {
      final mins = int.tryParse(result) ?? 60;
      final settings = context.read<SettingsProvider>().settings;
      final user = context.read<AuthProvider>().user;
      final newSettings = WorkSettings(
        workStart: settings.workStart,
        workEnd: settings.workEnd,
        breakDuration: mins,
        sedentaryReminder: settings.sedentaryReminder,
        offWorkReminder: settings.offWorkReminder,
      );
      context.read<SettingsProvider>().updateSettings(newSettings, user!.id!);
    }
  }

  void _editSedentaryReminder(BuildContext context) async {
    final settings = context.read<SettingsProvider>().settings;
    final ctrl = TextEditingController(
      text: settings.sedentaryReminder > 0 ? settings.sedentaryReminder.toString() : '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.accessibility_new),
          SizedBox(width: 8),
          Text('久坐提醒间隔（分钟）'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '输入分钟数，0 关闭',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text('每间隔指定分钟提醒一次，设置为 0 可关闭',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.close, size: 18), SizedBox(width: 4), Text('取消')])),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.check), SizedBox(width: 4), Text('确认')]),
          ),
        ],
      ),
    );
    if (result != null) {
      final minutes = int.tryParse(result) ?? 0;
      final s = context.read<SettingsProvider>().settings;
      final u = context.read<AuthProvider>().user;
      context.read<SettingsProvider>().updateSettings(
        WorkSettings(
          workStart: s.workStart,
          workEnd: s.workEnd,
          breakDuration: s.breakDuration,
          sedentaryReminder: minutes,
          offWorkReminder: s.offWorkReminder,
        ),
        u!.id!,
      );
    }
  }

  void _toggleSetting(BuildContext context,
      {bool? offWorkReminder}) {
    final settings = context.read<SettingsProvider>().settings;
    final user = context.read<AuthProvider>().user;
    final newSettings = WorkSettings(
      workStart: settings.workStart,
      workEnd: settings.workEnd,
      breakDuration: settings.breakDuration,
      sedentaryReminder: settings.sedentaryReminder,
      offWorkReminder: offWorkReminder ?? settings.offWorkReminder,
    );
    context.read<SettingsProvider>().updateSettings(newSettings, user!.id!);
  }

  void _exportData(BuildContext context, {String range = 'today'}) {
    final wp = context.read<WorkLogProvider>();
    final logs = range == 'week' ? wp.weekLogs : wp.todayLogs;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Row(children: const [Icon(Icons.info_outline, color: Colors.white, size: 20), SizedBox(width: 8), Text('暂无数据可导出')])),
      );
      return;
    }

    final buf = StringBuffer(
        '﻿任务名称,分类,开始时间,结束时间,持续时长(秒),状态,备注\n');
    for (final log in logs) {
      final start = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(DateTime.fromMillisecondsSinceEpoch(log.startTime));
      final end = log.endTime != null
          ? DateFormat('yyyy-MM-dd HH:mm:ss')
              .format(DateTime.fromMillisecondsSinceEpoch(log.endTime!))
          : '-';
      final notes = log.notes.replaceAll(',', '，').replaceAll('\n', ' ');
      buf.writeln(
          '${log.title},${log.category},$start,$end,${log.duration},${log.status == 1 ? "已完成" : "进行中"},$notes');
    }

    final now = DateFormat('yyyyMMdd').format(DateTime.now());
    final filename = range == 'week' ? '本周数据_$now.csv' : '今日数据_$now.csv';

    downloadCsv(buf.toString(), filename);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Row(children: [Icon(Icons.file_download_done, color: Colors.white, size: 20), const SizedBox(width: 8), Text('$filename 已下载')])),
      );
    }
  }

  void _clearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.warning, color: Colors.red),
          SizedBox(width: 8),
          Text('确认清空'),
        ]),
        content: const Text('将清空所有今日数据，此操作不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.close, size: 18), SizedBox(width: 4), Text('取消')])),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.delete_forever, color: Colors.white),
              SizedBox(width: 4),
              Text('确认清空', style: TextStyle(color: Colors.white)),
            ]),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        await context.read<WorkLogProvider>().clearTodayLogs(user.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Row(children: const [Icon(Icons.delete_sweep, color: Colors.white, size: 20), SizedBox(width: 8), Text('数据已清空')])),
          );
        }
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  const _SectionHeader({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
