import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/todo_item.dart';
import '../providers/auth_provider.dart';
import '../providers/todo_provider.dart';
import '../services/database_helper.dart';
import '../widgets/todo_card.dart';
import '../widgets/todo_edit_dialog.dart';

class TodoScreen extends StatefulWidget {
  final ValueChanged<TodoItem>? onStartTimerFromTodo;

  const TodoScreen({super.key, this.onStartTimerFromTodo});

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  Set<DateTime> _markedDates = {};
  bool _showCalendar = false; // 日历默认折叠

  // Filters
  String _searchQuery = '';
  int? _statusFilter; // null = all, 0 = pending, 2 = completed
  int? _priorityFilter;
  final String _categoryFilter = '';
  bool _overdueFilter = false;
  final TextEditingController _searchCtrl = TextEditingController();

  // Selected todo for detail panel
  TodoItem? _selectedTodo;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMonth() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final dates = await context
        .read<TodoProvider>()
        .getTodoDates(user.id!, _focusedDate.year, _focusedDate.month);
    if (mounted) {
      setState(() => _markedDates = dates);
      _loadDayTodos();
    }
  }

  Future<void> _loadDayTodos() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    if (_overdueFilter) {
      // Load all todos (across all dates) to find overdue items in memory
      await context.read<TodoProvider>().loadTodos(
            user.id!,
            startDay: 0,
            statusFilter: _statusFilter,
            priorityFilter: _priorityFilter,
            categoryFilter: _categoryFilter.isNotEmpty ? _categoryFilter : null,
            searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
          );
      return;
    }

    final startMs = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
        .millisecondsSinceEpoch;
    final endMs = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59)
        .millisecondsSinceEpoch;

    await context.read<TodoProvider>().loadTodos(
          user.id!,
          startDay: startMs,
          endDay: endMs,
          statusFilter: _statusFilter,
          priorityFilter: _priorityFilter,
          categoryFilter: _categoryFilter.isNotEmpty ? _categoryFilter : null,
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
  }

  void _onDaySelected(DateTime selected, DateTime focused) {
    setState(() {
      _selectedDate = selected;
      _focusedDate = focused;
    });
    _loadDayTodos();
  }

  void _onFormatChanged(CalendarFormat format) {
    setState(() {});
  }

  void _onPageChanged(DateTime focused) {
    setState(() => _focusedDate = focused);
    _loadMonth();
  }

  Future<List<String>> _loadTodoCategories(int userId) async {
    try {
      final db = DatabaseHelper();
      final cats = await db.getAllCategories(userId);
      if (cats.isEmpty) return ['开发', '会议', '学习', '沟通', '文档', '其他'];
      return cats;
    } catch (_) {
      return ['开发', '会议', '学习', '沟通', '文档', '其他'];
    }
  }

  Future<void> _addTodo() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final allCategories = await _loadTodoCategories(user.id!);
    if (!mounted) return;
    final todo = await showDialog<TodoItem>(
      context: context,
      builder: (ctx) => TodoEditDialog(
        userId: user.id!,
        categories: allCategories,
      ),
    );
    if (todo != null) {
      if (!mounted) return;
      final id = await context.read<TodoProvider>().addTodo(todo);
      setState(() => _selectedTodo = todo.copyWith(id: id));
      _loadMonth();
    }
  }

  Future<void> _editTodo(TodoItem existing) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final allCategories = await _loadTodoCategories(user.id!);
    if (!mounted) return;
    final todo = await showDialog<TodoItem>(
      context: context,
      builder: (ctx) => TodoEditDialog(
        existing: existing,
        userId: user.id!,
        categories: allCategories,
      ),
    );
    if (todo != null) {
      if (!mounted) return;
      await context.read<TodoProvider>().updateTodo(todo);
      setState(() => _selectedTodo = todo);
      _loadMonth();
    }
  }

  Future<void> _toggleComplete(TodoItem todo) async {
    await context.read<TodoProvider>().toggleComplete(todo);
    final updatedTodo = todo.copyWith(status: todo.status == 2 ? 0 : 2);
    if (_selectedTodo?.id == todo.id) {
      setState(() => _selectedTodo = updatedTodo);
    }
    _loadMonth();
  }

  /// 窄屏下弹出待办详情底部弹窗
  void _showDetailSheet(TodoItem todo) {
    setState(() => _selectedTodo = todo);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: _buildDetailPanel(todo),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedTodo = null);
    });
  }

  Future<void> _deleteTodo(TodoItem todo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('删除待办「${todo.title}」？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && todo.id != null) {
      if (!mounted) return;
      await context.read<TodoProvider>().deleteTodo(todo.id!);
      if (_selectedTodo?.id == todo.id) {
        setState(() => _selectedTodo = null);
      }
      _loadMonth();
    }
  }

  Future<void> _startExecution(TodoItem todo) async {
    // 标记为进行中并跳转到计时页
    final provider = context.read<TodoProvider>();
    final updated = await provider.startExecution(todo);
    // 跳转到计时页（传更新后的 status=1 todo）
    widget.onStartTimerFromTodo?.call(updated);
  }

  void _applyFilters() {
    _loadDayTodos();
  }

  bool _isWide(BuildContext context) => MediaQuery.of(context).size.width > 720;
  bool _canShowDetailInline(BuildContext context) =>
      MediaQuery.of(context).size.width >= 920;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TodoProvider>();
    var todos = provider.todos.where((t) => t.parentId == null).toList();
    if (_overdueFilter) {
      todos = todos.where((t) => t.isOverdue).toList();
    }
    final isLoading = provider.loading;
    final isWide = _isWide(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('待办事项'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(_showCalendar ? Icons.calendar_view_month : Icons.calendar_month_outlined),
            tooltip: _showCalendar ? '收起日历' : '显示日历',
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: '跳转到今天',
            onPressed: () {
              _onDaySelected(DateTime.now(), DateTime.now());
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final showDetailInline =
              _selectedTodo != null && constraints.maxWidth >= 920;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showCalendar)
                  SizedBox(
                    width: 340,
                    child: _buildCalendar(),
                  ),
                if (_showCalendar) const VerticalDivider(width: 1),
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      _buildFilters(),
                      const Divider(height: 1),
                      Expanded(child: _buildTodoList(isLoading, todos)),
                    ],
                  ),
                ),
                if (showDetailInline) ...[
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: 320,
                    child: _buildDetailPanel(_selectedTodo!),
                  ),
                ],
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showCalendar) _buildCalendar(),
                _buildFilters(),
                Divider(height: 1, color: Colors.grey.shade300),
                _buildTodoList(isLoading, todos),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTodo,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTodoList(bool isLoading, List<TodoItem> todos) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (todos.isEmpty) {
      final empty = _buildEmptyState();
      return _isWide(context) ? empty : SizedBox(height: 300, child: empty);
    }

    // 按完成状态分组：未完成(status 0/1)在前，已完成(status 2)在后
    // 每组内按优先级降序(高→中→低)
    final incomplete = todos.where((t) => t.status != 2).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final completed = todos.where((t) => t.status == 2).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    // 构建分组列表项
    final List<Widget> sections = [];
    if (incomplete.isNotEmpty) {
      sections.add(_sectionHeader('待完成', incomplete.length, Colors.orange));
      sections.addAll(incomplete.map((t) => _buildCard(t)));
    }
    if (completed.isNotEmpty) {
      sections.add(_sectionHeader('已完成', completed.length, Colors.green));
      sections.addAll(completed.map((t) => _buildCard(t)));
    }

    if (_isWide(context)) {
      return ListView(
        padding: const EdgeInsets.all(8),
        children: sections,
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      children: sections,
    );
  }

  Widget _sectionHeader(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count', style: TextStyle(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(TodoItem todo) {
    return TodoCard(
      todo: todo,
      onToggle: () => _toggleComplete(todo),
      onEdit: () => _editTodo(todo),
      onDelete: () => _deleteTodo(todo),
      onStartExecution: todo.status != 2
          ? () => _startExecution(todo)
          : null,
      onSelect: () {
        if (_canShowDetailInline(context)) {
          setState(() => _selectedTodo = todo);
        } else {
          _showDetailSheet(todo);
        }
      },
      isSelected: _selectedTodo?.id == todo.id,
    );
  }

  Widget _buildCalendar() {
    return TableCalendar<TodoItem>(
      firstDay: DateTime(2020),
      lastDay: DateTime(2030),
      focusedDay: _focusedDate,
      selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
      calendarFormat: _calendarFormat,
      onFormatChanged: _onFormatChanged,
      onDaySelected: _onDaySelected,
      onPageChanged: _onPageChanged,
      eventLoader: (day) {
        return _markedDates.contains(DateTime(day.year, day.month, day.day))
            ? [TodoItem(userId: 0, title: '')]
            : [];
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isNotEmpty) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.only(bottom: 2),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }
          return null;
        },
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Colors.blue.shade100,
          shape: BoxShape.circle,
        ),
        selectedDecoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
        selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: '搜索待办...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (v) {
              setState(() => _searchQuery = v);
              _applyFilters();
            },
          ),
          const SizedBox(height: 8),
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('全部', _statusFilter == null, () {
                  setState(() => _statusFilter = null);
                  _applyFilters();
                }),
                const SizedBox(width: 6),
                _filterChip('待办', _statusFilter == 0, () {
                  setState(() => _statusFilter = _statusFilter == 0 ? null : 0);
                  _applyFilters();
                }),
                const SizedBox(width: 6),
                _filterChip('已完成', _statusFilter == 2, () {
                  setState(() => _statusFilter = _statusFilter == 2 ? null : 2);
                  _applyFilters();
                }),
                const SizedBox(width: 6),
                _priorityChip('高', 2),
                const SizedBox(width: 6),
                _priorityChip('中', 1),
                const SizedBox(width: 6),
                _priorityChip('低', 0),
                const SizedBox(width: 6),
                _overdueChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
      selected: selected,
      selectedColor: Colors.blue,
      checkmarkColor: Colors.white,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => onTap(),
    );
  }

  Widget _priorityChip(String label, int priority) {
    final selected = _priorityFilter == priority;
    return FilterChip(
      label: Text(label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : _priorityColor(priority),
          )),
      selected: selected,
      selectedColor: _priorityColor(priority),
      checkmarkColor: Colors.white,
      visualDensity: VisualDensity.compact,
      onSelected: (_) {
        setState(() => _priorityFilter = _priorityFilter == priority ? null : priority);
        _applyFilters();
      },
    );
  }

  Color _priorityColor(int p) {
    switch (p) {
      case 2:
        return Colors.red;
      case 1:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Widget _overdueChip() {
    return FilterChip(
      label: Text('已过期',
          style: TextStyle(
            fontSize: 12,
            color: _overdueFilter ? Colors.white : Colors.red,
          )),
      selected: _overdueFilter,
      selectedColor: Colors.red,
      checkmarkColor: Colors.white,
      visualDensity: VisualDensity.compact,
      onSelected: (v) {
        setState(() => _overdueFilter = v);
        _applyFilters();
      },
    );
  }

  Widget _buildDetailPanel(TodoItem todo) {
    final completed = todo.status == 2;
    final overdue = todo.isOverdue;
    final dueStr = todo.dueDate != null
        ? _formatDate(todo.dueDate!)
        : '无';

    Color priorityColor(int p) {
      switch (p) {
        case 2: return Colors.red;
        case 1: return Colors.orange;
        default: return Colors.green;
      }
    }

    String priorityLabel(int p) {
      switch (p) {
        case 2: return '高';
        case 1: return '中';
        default: return '低';
      }
    }

    String recurringLabel(String rule) {
      switch (rule) {
        case 'daily': return '每天';
        case 'weekly': return '每周';
        case 'monthly': return '每月';
        default: return '不重复';
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 6),
              const Text('待办详情',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _selectedTodo = null),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          // Title
          Text(todo.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                decoration: completed ? TextDecoration.lineThrough : null,
                color: completed ? Colors.grey : null,
              )),
          const SizedBox(height: 16),

          // Status
          _detailRow(Icons.circle_outlined, '状态',
              completed ? '已完成' : (overdue ? '已过期' : '待办'),
              color: completed ? Colors.green : (overdue ? Colors.red : Colors.blue)),
          const SizedBox(height: 8),

          // Category
          if (todo.category.isNotEmpty)
            _detailRow(Icons.category_outlined, '分类', todo.category),
          if (todo.category.isNotEmpty) const SizedBox(height: 8),

          // Priority
          _detailRow(priorityColor(todo.priority) == Colors.red
              ? Icons.flag
              : Icons.flag_outlined, '优先级', priorityLabel(todo.priority),
              color: priorityColor(todo.priority)),
          const SizedBox(height: 8),

          // Due date
          _detailRow(Icons.access_time, '截止日期', dueStr,
              color: overdue ? Colors.red : null),
          const SizedBox(height: 8),

          // Start time
          if (todo.startTime != null)
            _detailRow(Icons.play_circle_outline, '开始时间', _formatDate(todo.startTime!),
                color: Colors.green),
          if (todo.startTime != null) const SizedBox(height: 8),

          // Recurring
          _detailRow(Icons.repeat, '重复', recurringLabel(todo.recurringRule)),
          const SizedBox(height: 8),

          // Description
          if (todo.description.isNotEmpty) ...[
            const Divider(),
            const SizedBox(height: 4),
            const Text('描述', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(todo.description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
          ],

          // Created / Updated
          const Divider(),
          _detailRow(Icons.create_outlined, '创建时间', _formatDate(todo.createdAt)),
          const SizedBox(height: 4),
          _detailRow(Icons.update, '更新时间', _formatDate(todo.updatedAt)),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              if (!completed && !overdue)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startExecution(todo),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('开始执行'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (!completed && !overdue) const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _editTodo(todo),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('编辑'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 8),
        Text('$label：', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              )),
        ),
      ],
    );
  }

  String _formatDate(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty || _statusFilter != null || _priorityFilter != null || _overdueFilter
                ? '没有匹配的待办'
                : '这一天没有待办',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            '点击右下角 + 添加',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
