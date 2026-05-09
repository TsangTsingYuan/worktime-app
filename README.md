# 工作打卡 (Worktime App)

Flutter Web 工时追踪应用，支持计时打卡、手动补录、统计报表、数据导出等功能。

## 技术栈

- **框架**: Flutter 3.41.7 (Dart 3.11.5)
- **状态管理**: Provider
- **数据库**: SQLite (sqflite + sqflite_common_ffi_web)
- **UI**: Material Design 3
- **HTTP**: http (Dart 官方)
- **加密**: crypto (SHA-256)
- **Web 互操作**: package:web + dart:js_interop
- **日历**: table_calendar

## 环境要求

- Flutter SDK >= 3.41 (Dart SDK >= 3.10)
- Linux / macOS / Windows (桌面端开发需对应平台工具)
- Chrome (运行 Web 调试)

## 快速开始

```bash
# 1. 安装依赖
flutter pub get

# 2. 代码分析
flutter analyze

# 3. 运行测试
flutter test

# 4. 启动开发服务器 (浏览器访问 http://localhost:8080)
flutter run -d chrome

# 5. 连接后端启动（可选）
flutter run -d chrome --dart-define=API_URL=https://your-server.com
```

## 构建

```bash
# Release 构建
flutter build web --release

# 构建产物目录: build/web/
```

## 部署

使用 nginx 部署构建产物，配置参考 `nginx/worktime.conf`：

```nginx
server {
    listen 8080;
    root /path/to/worktime_app/build/web;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /assets/ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    gzip on;
    gzip_types text/plain text/css application/javascript application/wasm;
}
```

## 项目结构

```
lib/
├── main.dart                    # 入口 & MultiProvider
├── models/
│   ├── user.dart                # 用户模型
│   ├── work_log.dart            # 工作记录模型
│   └── todo_item.dart           # 待办模型
├── providers/
│   ├── auth_provider.dart       # 登录/注册状态
│   ├── timer_provider.dart      # 计时器状态
│   ├── work_log_provider.dart   # 工作记录 CRUD
│   ├── settings_provider.dart   # 用户配置
│   └── todo_provider.dart       # 待办 CRUD
├── screens/
│   ├── login_screen.dart        # 登录/注册页
│   ├── home_screen.dart         # 打卡主页（计时 + 今日记录）
│   ├── stats_screen.dart        # 统计报表页
│   ├── todo_screen.dart         # 待办管理页
│   └── settings_screen.dart     # 个人设置页
├── services/
│   ├── database_helper.dart     # SQLite 数据库操作
│   ├── api_client.dart          # HTTP API 客户端
│   ├── sync_service.dart        # 离线同步服务
│   ├── file_downloader.dart     # 文件下载（条件导入基类）
│   ├── file_downloader_web.dart # Web 下载实现
│   ├── reminder_service.dart    # 提醒（条件导入基类）
│   └── reminder_service_web.dart# Web 提醒实现
└── widgets/
    ├── stat_chart.dart          # 柱状图 / 饼图组件
    ├── task_card.dart           # 任务卡片组件
    ├── timer_widget.dart        # 计时器组件
    ├── todo_card.dart           # 待办卡片组件
    └── todo_edit_dialog.dart    # 待办编辑弹窗
```

## 功能

| 功能 | 说明 |
|------|------|
| 用户登录/注册 | 手机号 + 密码（SHA-256 本地存储） |
| 计时打卡 | 选择任务分类、开始/暂停/结束计时 |
| 手动补录 | 补填历史任务 |
| 待办管理 | 日历视图、优先级、分类、截止日期、重复规则 |
| 统计报表 | 今日/本周/本月工作时长、分类统计（饼图） |
| 个人设置 | 昵称、工作时间、午休时长、久坐/下班提醒 |
| 数据导出 | CSV 格式导出今日/本周数据 |
| 离线同步 | 离线优先架构，有后端时自动同步 |
| 自适应布局 | 宽屏 NavigationRail，窄屏 BottomNavigation |

## 数据库

SQLite 本地存储，Web 端通过 `sqflite_common_ffi_web` 实现。重启不清除，持久保存于浏览器 IndexedDB。

表结构：

- **user**: id, nickname, phone, password(sha256), config, serverId, token
- **work_log**: id, userId, title, category, startTime, endTime, duration, status, notes, serverId, createdAt, updatedAt, isSynced
- **todo**: id, userId, title, description, priority, status, dueDate, category, linkedWorkLogId, parentId, recurringRule, sortOrder, createdAt, updatedAt, isSynced

## 已知问题

启动 `flutter run -d chrome` 时如遇到网络错误 `SocketException: Connection refused`，添加 `--web-allow-expose-url-rules` 或在项目目录重新 `flutter pub get` 后重试。
