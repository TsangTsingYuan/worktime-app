import 'package:flutter/material.dart';
import '../models/todo_item.dart';

/// Priority chip colors
Color priorityColor(int priority) {
  switch (priority) {
    case 2:
      return Colors.red;
    case 1:
      return Colors.orange;
    default:
      return Colors.green;
  }
}

/// Priority icon
IconData priorityIcon(int priority) {
  switch (priority) {
    case 2:
      return Icons.flag;
    case 1:
      return Icons.flag_outlined;
    default:
      return Icons.flag_outlined;
  }
}

class TodoCard extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onStartExecution; // 开始执行
  final VoidCallback? onToggleSubtasks;
  final List<TodoItem>? subtasks;
  final bool subtasksExpanded;
  final VoidCallback? onSelect;
  final bool isSelected;

  const TodoCard({
    super.key,
    required this.todo,
    this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onStartExecution,
    this.onToggleSubtasks,
    this.subtasks,
    this.subtasksExpanded = false,
    this.onSelect,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final completed = todo.status == 2;
    final overdue = todo.isOverdue;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      shape: isSelected
          ? RoundedRectangleBorder(
              side: BorderSide(color: Colors.blue.shade300, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      color: isSelected ? Colors.blue.shade50 : null,
      child: Column(
        children: [
          ListTile(
            leading: Checkbox(
              value: completed,
              onChanged: overdue ? null : (_) => onToggle?.call(),
              shape: const CircleBorder(),
              activeColor: Colors.green,
            ),
            title: Row(
              children: [
                if (!completed)
                  Icon(priorityIcon(todo.priority),
                      size: 16, color: priorityColor(todo.priority)),
                if (!completed) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    todo.title,
                    style: TextStyle(
                      decoration: completed ? TextDecoration.lineThrough : null,
                      color: completed ? Colors.grey : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (todo.category.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(todo.category,
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (todo.startTime != null && !completed) ...[
                      Icon(Icons.play_circle_outline, size: 12, color: Colors.green.shade400),
                      const SizedBox(width: 2),
                      Text(
                        '开始 ${_formatDate(todo.startTime!)}',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade600),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (todo.dueDate != null) ...[
                      Icon(Icons.access_time, size: 12, color: overdue ? Colors.red : Colors.grey),
                      const SizedBox(width: 2),
                      Text(
                        '截止 ${_formatDate(todo.dueDate!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: overdue ? Colors.red : Colors.grey.shade600,
                          fontWeight: overdue ? FontWeight.bold : null,
                        ),
                      ),
                      if (overdue)
                        Text(' 已过期',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                    if (todo.recurringRule.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.repeat, size: 12, color: Colors.blue.shade300),
                      Text(_recurringLabel(todo.recurringRule),
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade300)),
                    ],
                    if (todo.description.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 0),
                        child: Icon(Icons.description_outlined, size: 14, color: Colors.grey.shade400),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!completed && !overdue && todo.status != 1 && onStartExecution != null)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, size: 20),
                    tooltip: '开始执行',
                    onPressed: onStartExecution,
                    visualDensity: VisualDensity.compact,
                    color: Colors.green,
                  ),
                if (todo.status == 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('进行中', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                    ),
                  ),
                PopupMenuButton<String>(
                  itemBuilder: (ctx) => [
                    if (!overdue)
                      const PopupMenuItem(value: 'edit', child: Text('编辑')),
                    if (!overdue)
                      const PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                  icon: const Icon(Icons.more_vert, size: 18),
                ),
              ],
            ),
            onTap: () {
              if (overdue) return;
              onSelect?.call();
              onEdit?.call();
            },
          ),

          // Subtasks
          if (subtasks != null && subtasks!.isNotEmpty)
            _buildSubtasks(context),
        ],
      ),
    );
  }

  Widget _buildSubtasks(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggleSubtasks,
          child: Container(
            padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
            child: Row(
              children: [
                Icon(
                  subtasksExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  '子任务 (${subtasks!.where((s) => s.status == 2).length}/${subtasks!.length})',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        if (subtasksExpanded)
          ...subtasks!.map((st) => ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                leading: Checkbox(
                  value: st.status == 2,
                  onChanged: (_) => onToggleSubtasks?.call(),
                  shape: const CircleBorder(),
                  activeColor: Colors.green,
                ),
                title: Text(st.title,
                    style: TextStyle(
                      fontSize: 14,
                      decoration: st.status == 2 ? TextDecoration.lineThrough : null,
                      color: st.status == 2 ? Colors.grey : null,
                    )),
              )),
      ],
    );
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _recurringLabel(String rule) {
    switch (rule) {
      case 'daily': return '每天';
      case 'weekly': return '每周';
      case 'monthly': return '每月';
      default: return '';
    }
  }
}
