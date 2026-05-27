import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoEditDialog extends StatefulWidget {
  final TodoItem? existing;
  final int userId;
  final List<String> categories;

  const TodoEditDialog({
    super.key,
    this.existing,
    required this.userId,
    this.categories = const ['开发', '会议', '学习', '沟通', '文档', '其他'],
  });

  @override
  State<TodoEditDialog> createState() => _TodoEditDialogState();
}

class _TodoEditDialogState extends State<TodoEditDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _categoryCtrl;
  late int _priority;
  late String _recurringRule;
  bool _hasDueDate = false;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _descCtrl = TextEditingController(text: t?.description ?? '');
    _categoryCtrl = TextEditingController(text: t?.category ?? '');
    _priority = t?.priority ?? 1;
    _recurringRule = t?.recurringRule ?? '';
    if (t?.dueDate != null) {
      _hasDueDate = true;
      _dueDate = DateTime.fromMillisecondsSinceEpoch(t!.dueDate!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Row(children: [
        Icon(isEditing ? Icons.edit : Icons.add_task),
        const SizedBox(width: 8),
        Flexible(
          child: Text(isEditing ? '编辑待办' : '新增待办',
              overflow: TextOverflow.ellipsis),
        ),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '标题',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // Priority
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('优先级：', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  _priorityChip(0, '低', Colors.green),
                  const SizedBox(width: 4),
                  _priorityChip(1, '中', Colors.orange),
                  const SizedBox(width: 4),
                  _priorityChip(2, '高', Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Category
            TextField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: '分类',
                border: OutlineInputBorder(),
                isDense: true,
                prefixIcon: Icon(Icons.category_outlined, size: 20),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (widget.categories.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: () {
                  final typed = _categoryCtrl.text.trim();
                  final displayCats = <String>[...widget.categories];
                  if (typed.isNotEmpty && !displayCats.contains(typed)) {
                    displayCats.add(typed);
                  }
                  return displayCats.map((c) => ChoiceChip(
                    label: Text(c, style: const TextStyle(fontSize: 12)),
                    selected: _categoryCtrl.text == c,
                    selectedColor: Colors.blue.shade100,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _categoryCtrl.text = c),
                  )).toList();
                }(),
              ),
            ],
            const SizedBox(height: 12),

            // Due date
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('设置截止日期', style: TextStyle(fontSize: 14)),
              value: _hasDueDate,
              onChanged: (v) {
                setState(() {
                  _hasDueDate = v;
                  if (v && _dueDate == null) {
                    final tomorrow = DateTime.now().add(const Duration(days: 1));
                    _dueDate = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18, 0);
                  }
                });
              },
            ),
            if (_hasDueDate && _dueDate != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: Text(
                  '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}  ${_dueDate!.hour.toString().padLeft(2, '0')}:${_dueDate!.minute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate!,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked == null) return;
                  if (!context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(_dueDate!),
                  );
                  if (time == null) return;
                  if (!context.mounted) return;
                  setState(() => _dueDate = DateTime(
                    picked.year, picked.month, picked.day, time.hour, time.minute,
                  ));
                },
              ),

            // Recurring
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _recurringRule,
              decoration: const InputDecoration(
                labelText: '重复',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('不重复')),
                DropdownMenuItem(value: 'daily', child: Text('每天')),
                DropdownMenuItem(value: 'weekly', child: Text('每周')),
                DropdownMenuItem(value: 'monthly', child: Text('每月')),
              ],
              onChanged: (v) => setState(() => _recurringRule = v ?? ''),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(isEditing ? '保存' : '添加'),
        ),
      ],
    );
  }

  Widget _priorityChip(int p, String label, Color color) {
    final selected = _priority == p;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : color)),
      selected: selected,
      selectedColor: color,
      onSelected: (_) => setState(() => _priority = p),
      visualDensity: VisualDensity.compact,
    );
  }

  void _submit() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final todo = TodoItem(
      id: widget.existing?.id,
      userId: widget.userId,
      title: title,
      description: _descCtrl.text.trim(),
      priority: _priority,
      category: _categoryCtrl.text.trim(),
      dueDate: _hasDueDate ? _dueDate?.millisecondsSinceEpoch : null,
      recurringRule: _recurringRule,
      status: widget.existing?.status ?? 0,
      linkedWorkLogId: widget.existing?.linkedWorkLogId,
      sortOrder: widget.existing?.sortOrder ?? 0,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    Navigator.pop(context, todo);
  }
}
