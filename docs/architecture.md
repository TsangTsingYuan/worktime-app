# 系统架构设计

## 项目概述

工作打卡（WorkTime App）是一款跨平台的工作计时与统计应用，支持 Web / iOS / Android 三端。用户可记录工作任务的开始与结束时间，自动计时，并生成统计数据。

**核心能力：**
- 开始/结束工作任务计时
- 手动补录历史任务
- 按日/周/月统计工作时长
- 分类统计（开发、会议、学习、沟通、文档、其他）
- 待办管理（日历视图、优先级、截止日期、重复规则）
- 数据导出 CSV
- 久坐提醒 + 下班提醒 + 待办截止提醒
- **跨设备数据同步**（v2 新增）

---

## 整体架构

```
┌────────────────────────────────────────────────────────┐
│                   Flutter App 客户端                      │
│                                                        │
│  ┌──────┐  ┌──────┐  ┌─────────┐  ┌───────────────┐   │
│  │ 打卡  │  │ 统计  │  │  设置    │  │  登录/注册    │   │
│  └──┬───┘  └──┬───┘  └────┬────┘  └──────┬────────┘  │
│     │         │           │              │            │
│  ┌──┴─────────┴───────────┴──────────────┴────────┐  │
│  │               Provider 层                       │  │
│  │  AuthProvider  TimerProvider  WorkLogProvider  TodoProvider │  │
│  │  SettingsProvider  ReminderService            │  │
│  └─────────────────────┬─────────────────────────┘  │
│                        │                             │
│  ┌─────────────────────┴─────────────────────────┐  │
│  │               Service 层                       │  │
│  │  DatabaseHelper  ApiClient  SyncService       │  │
│  │  FileDownloader   ReminderService             │  │
│  └─────────────────────┬─────────────────────────┘  │
│                        │                             │
│  ┌─────────────────────┴─────────────────────────┐  │
│  │          Platform Adapter (条件导入)            │  │
│  │  Web: sqflite_common_ffi_web (OPFS+WASM)     │  │
│  │  Mobile: sqflite (原生 SQLite)                 │  │
│  │  Web: ReminderService_web (package:web)         │  │
│  │  Mobile: ReminderService (flutter_notif.)     │  │
│  └───────────────────────────────────────────────┘  │
└──────────────────────┬─────────────────────────────┘
                       │ HTTPS / REST API
                       │
┌──────────────────────┴─────────────────────────────┐
│                Dart Shelf 后端服务器                   │
│                                                        │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────┐  │
│  │ 认证中间件 │  │ 路由分发    │  │  Handler 层       │  │
│  │ (JWT)    │  │ shelf_router│  │  auth / worklog  │  │
│  │          │  │            │  │  sync            │  │
│  └────┬─────┘  └─────┬──────┘  └───────┬──────────┘  │
│       │              │                 │             │
│  ┌────┴──────────────┴─────────────────┴──────────┐  │
│  │              数据库层 (SQLite)                   │  │
│  │  users 表  │  work_logs 表                     │  │
│  └───────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
                       │
                       ▼
              部署选项：Fly.io / Railway / 自建 VPS
```

---

## 数据流

### 离线优先同步策略

```
设备A 创建任务
     │
     ├──→ 写入本地 SQLite (status=0, is_synced=false)
     │
     ├──→ UI 即时响应（离线可用）
     │
     └──→ 网络可用时 SyncService.pushChanges()
               │
               ├──→ POST /api/sync (JWT 认证)
               │         │
               │         └──→ 服务端写入 PostgreSQL/SQLite
               │
               └──→ 本地标记 is_synced=true

设备B 打开 App
     │
     ├──→ SyncService.pullChanges()
     │         │
     │         └──→ GET /api/sync?since=timestamp
     │
     ├──→ 写入本地 SQLite
     │
     └──→ UI 更新

AppBar 同步状态指示器：有后端时显示绿色云朵图标（空闲）/ 橙色旋转图标（同步中），无后端时隐藏。
```

### 开始一个任务

```
用户点击"开始工作"
    → 弹出对话框（输入标题、分类、备注）
    → WorkLogProvider.startNewTask()
        → DatabaseHelper.insertWorkLog() [status=0]
        → TimerProvider.start() [开始每秒计时]
            → HomeScreen 更新计时器显示
```

### 结束一个任务

```
用户点击"结束"
    → 确认对话框
    → WorkLogProvider.endTask(id, elapsedSeconds)
        → DatabaseHelper.updateWorkLog() [status=1, duration, endTime]
        → TimerProvider.stop()
        → SyncService.pushChanges()（网络可用时）
    → 任务出现在今日记录列表
```

---

## 数据库设计

### 客户端 SQLite (worktime.db)

**表：user**
```sql
CREATE TABLE user (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nickname TEXT NOT NULL DEFAULT '',
  phone TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  config TEXT NOT NULL DEFAULT ''
);
```

**表：work_log**
```sql
CREATE TABLE work_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId INTEGER NOT NULL,
  title TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT '',
  startTime INTEGER NOT NULL,
  endTime INTEGER,
  duration INTEGER NOT NULL DEFAULT 0,
  status INTEGER NOT NULL DEFAULT 0,
  notes TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (userId) REFERENCES user(id)
);
```

**v1→v2 迁移新增字段：**
- `server_id TEXT` — 服务端 UUID
- `created_at INTEGER NOT NULL DEFAULT 0` — 创建时间戳
- `updated_at INTEGER NOT NULL DEFAULT 0` — 更新时间戳
- `is_synced INTEGER NOT NULL DEFAULT 0` — 是否已同步

用户表新增：
- `server_id TEXT`
- `token TEXT NOT NULL DEFAULT ''`

**表：todo**
```sql
CREATE TABLE todo (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  priority INTEGER NOT NULL DEFAULT 1,
  status INTEGER NOT NULL DEFAULT 0,
  dueDate INTEGER,
  category TEXT NOT NULL DEFAULT '',
  linkedWorkLogId INTEGER,
  parentId INTEGER,
  recurringRule TEXT NOT NULL DEFAULT '',
  sortOrder INTEGER NOT NULL DEFAULT 0,
  createdAt INTEGER NOT NULL DEFAULT 0,
  updatedAt INTEGER NOT NULL DEFAULT 0,
  isSynced INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (userId) REFERENCES user(id)
);
```

### 服务端 SQLite (worktime_server/data.db)

**表：users**
```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,           -- UUID
  phone TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  nickname TEXT NOT NULL DEFAULT '',
  config TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL,   -- epoch ms
  updated_at INTEGER NOT NULL
);
```

**表：work_logs**
```sql
CREATE TABLE work_logs (
  id TEXT PRIMARY KEY,           -- UUID
  user_id TEXT NOT NULL,
  client_id TEXT NOT NULL,       -- 客户端本地 ID 用于去重
  title TEXT NOT NULL,
  category TEXT DEFAULT '',
  start_time INTEGER NOT NULL,   -- epoch ms
  end_time INTEGER,
  duration INTEGER DEFAULT 0,    -- seconds
  status INTEGER DEFAULT 0,      -- 0=进行中, 1=完成
  notes TEXT DEFAULT '',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX idx_work_logs_user ON work_logs(user_id);
CREATE INDEX idx_work_logs_updated ON work_logs(updated_at);
CREATE UNIQUE INDEX idx_work_logs_client ON work_logs(user_id, client_id);
```

---

## API 设计

**Base URL:** `https://<host>/api`

### 认证

| Method | Path | Body | 说明 |
|--------|------|------|------|
| POST | `/auth/register` | `{phone, password, nickname}` | 注册，返回 JWT |
| POST | `/auth/login` | `{phone, password}` | 登录，返回 JWT |

### 工作日志

所有日志端点需 `Authorization: Bearer <token>` 头。

| Method | Path | Body/Query | 说明 |
|--------|------|------------|------|
| GET | `/worklogs` | `?since=timestamp` | 获取某时间后的变更 |
| POST | `/worklogs` | `{title, category, startTime, ...}` | 创建日志 |
| PUT | `/worklogs/:id` | `{title, category, duration, ...}` | 更新日志 |
| DELETE | `/worklogs/:id` | — | 删除日志 |

### 批量同步

| Method | Path | Body | 说明 |
|--------|------|------|------|
| POST | `/sync` | `{changes: [...], lastSyncAt: timestamp}` | 推送本地变更 + 拉取远程变更 |

**响应格式：**
```json
{
  "ok": true,
  "serverChanges": [...],
  "syncAt": 1712345678000
}
```


### 待办

| Method | Path | Body/Query | 说明 |
|--------|------|------------|------|
| GET | `/todos` | `?since=timestamp` | 增量获取待办 |
| POST | `/todos` | `{title, priority, dueDate, ...}` | 创建待办 |
| PUT | `/todos/:id` | `{title, status, ...}` | 更新待办 |
| DELETE | `/todos/:id` | — | 删除待办 |

### 用户设置

| Method | Path | Body | 说明 |
|--------|------|------|------|
| GET | `/settings` | — | 获取用户配置 JSON |
| PUT | `/settings` | `{workStart, workEnd, ...}` | 更新用户配置 |

---

## 安全设计

- **密码**：服务端使用 bcrypt 哈希存储，不存明文；客户端使用 SHA-256 哈希后存储到本地 SQLite
- **JWT**：登录/注册后发放 JWT，有效期 7 天
- **CORS**：仅允许来自 GitHub Pages 域名和白名单域名的跨域请求
- **数据隔离**：每个 JWT 只允许访问对应用户的数据
- **本地存储**：JWT 存储于客户端内存 + localStorage(web) / SharedPreferences(移动端)

---

## 部署架构

### 前端部署 (GitHub Actions)

```
Git Push → GitHub Actions → flutter build web → deploy-pages
                                                      │
                                                      ▼
                                            https://tsangtsingyuan.github.io/worktime-app/
```

### 后端部署 (Docker)

```
Docker Build → Push to Registry → Deploy to Cloud
                                       │
                          ┌────────────┼────────────┐
                          ▼            ▼            ▼
                       Fly.io      Railway      自建 VPS
```

---

## 项目目录结构

```
worktime_app/                          # Flutter 前端项目
├── lib/
│   ├── main.dart                      # 入口 + MultiProvider
│   ├── models/
│   │   ├── user.dart                  # 用户模型
│   │   ├── work_log.dart              # 工作日志模型
│   │   └── todo_item.dart            # 待办模型
│   ├── providers/
│   │   ├── auth_provider.dart         # 认证状态管理
│   │   ├── timer_provider.dart        # 计时器状态管理
│   │   ├── work_log_provider.dart     # 日志 CRUD + 同步触发
│   │   ├── settings_provider.dart     # 配置管理
│   │   └── todo_provider.dart        # 待办 CRUD
│   ├── screens/
│   │   ├── login_screen.dart          # 登录/注册页面
│   │   ├── home_screen.dart           # 主页（计时 + 今日记录）
│   │   ├── stats_screen.dart          # 统计页面
│   │   ├── settings_screen.dart       # 设置页面
│   │   └── todo_screen.dart          # 待办管理
│   ├── services/
│   │   ├── database_helper.dart       # SQLite CRUD
│   │   ├── api_client.dart            # HTTP API 客户端
│   │   ├── sync_service.dart          # 离线同步服务
│   │   ├── file_downloader.dart       # 文件下载（条件导入基类）
│   │   ├── file_downloader_web.dart   # Web 下载实现
│   │   ├── reminder_service.dart      # 提醒（条件导入基类）
│   │   └── reminder_service_web.dart  # Web 提醒实现
│   └── widgets/
│       ├── task_card.dart             # 任务卡片组件
│       ├── timer_widget.dart          # 计时器组件
│       ├── todo_card.dart            # 待办卡片组件
│       └── todo_edit_dialog.dart     # 待办编辑弹窗
├── web/                               # Web 配置
│   ├── index.html
│   ├── manifest.json
│   └── sqlite3.wasm
├── docs/                              # 文档
│   ├── architecture.md                # 架构设计文档
│   └── progress.md                    # 开发进度跟踪
├── pubspec.yaml
└── .github/workflows/deploy-pages.yml

worktime_server/                       # Dart Shelf 后端项目
├── bin/
│   └── server.dart                    # 服务入口
├── lib/
│   ├── database.dart                  # SQLite 初始化 + CRUD
│   ├── router.dart                    # 路由定义
│   ├── middleware/
│   │   └── auth.dart                  # JWT 认证中间件
│   ├── handlers/
│   │   ├── auth_handler.dart          # 注册/登录
│   │   ├── worklog_handler.dart       # 日志 CRUD
│   │   └── sync_handler.dart          # 批量同步
│   └── models/
│       ├── user.dart                  # 服务端用户模型
│       └── work_log.dart              # 服务端日志模型
├── pubspec.yaml
├── Dockerfile
└── .env.example
```

---

## 技术栈

| 层次 | 技术 | 版本 |
|------|------|------|
| 客户端框架 | Flutter | 3.41.x |
| 客户端语言 | Dart | 3.11.x |
| 状态管理 | Provider | 6.x |
| 客户端数据库 | sqflite + sqflite_common_ffi_web | 2.x |
| HTTP 客户端 | http (Dart 官方) | 1.x |
| 后端框架 | Dart Shelf | 1.x |
| 后端数据库 | sqlite3 (Dart 包) | 2.x |
| 认证 | bcrypt + JWT | — |
| CI/CD | GitHub Actions | — |
| 后端部署 | Docker + Fly.io/Railway | — |
