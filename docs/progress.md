# 开发进度跟踪

> 更新日期：2026-05-08

## 总体进度

| 阶段 | 状态 | 进度 |
|------|------|------|
| Phase 0: Bug 修复 — Timer 持久化 | ✅ 完成 | 100% |
| Phase 1: 后端服务 (worktime_server) | ✅ 完成 | 100% |
| Phase 2: Flutter 客户端改造 | ✅ 完成 | 100% |
| Phase 3: 移动端适配 | ⏳ 待定 | 0% |

---

## Phase 0: Bug 修复（已完成）

- [x] **TimerProvider** — 新增 `resumeFromOngoingTask()` 方法，从 DB 恢复进行中任务计时
- [x] **HomeScreen** — `initState` 中检测 `_activeLog` 后自动恢复计时器
- [x] **WorkLogProvider.endTask** — 改为从 `_todayLogs` 列表读取完整记录，不再依赖 `_activeLog`
- [x] **构建验证** — `flutter analyze` 无错误，`flutter build web` 编译通过
- [x] **已部署** — 已提交推送至 GitHub Pages

---

## Phase 1: 后端服务（已完成）

### 1.1 项目初始化
- [x] 创建 worktime_server 项目结构（`bin/server.dart` + `pubspec.yaml` + `.env.example`）
- [x] 配置依赖（shelf, shelf_router, sqlite3, dart_jsonwebtoken, bcrypt, uuid）

### 1.2 数据库层
- [x] SQLite 初始化（users 表 + work_logs 表 + 索引）
- [x] 用户 CRUD（getUserByPhone, getUserById, insertUser, updateUser, getUserSettings, updateUserSettings）
- [x] 日志 CRUD（insertWorkLog, updateWorkLog, deleteWorkLog, getWorkLogsSince, getWorkLogsByClientIds）

### 1.3 认证
- [x] bcrypt 密码哈希存储
- [x] JWT token 签发（30天有效期）与验证中间件
- [x] 注册端点 POST /api/auth/register（手机号唯一校验）
- [x] 登录端点 POST /api/auth/login

### 1.4 日志 API
- [x] GET /api/worklogs?since=timestamp（增量拉取）
- [x] POST /api/worklogs（创建，支持 clientId 去重）
- [x] PUT /api/worklogs/:id（更新）
- [x] DELETE /api/worklogs/:id（删除）

### 1.5 批量同步
- [x] POST /api/sync（推送变更 + 拉取远程变更）
- [x] 增量变更检测（updated_at > lastSyncAt）
- [x] 基于 clientId 的去重逻辑

### 1.6 用户设置 API
- [x] GET /api/settings
- [x] PUT /api/settings

### 1.7 部署配置
- [x] Dockerfile（dart compile exe + debian-slim）
- [x] 环境变量配置（PORT, DB_PATH, JWT_SECRET, ALLOWED_ORIGIN）
- [x] CORS 中间件（支持自定义 allowedOrigin）

---

## Phase 2: Flutter 客户端改造（已完成）

### 2.1 HTTP 客户端
- [x] 添加 http 包依赖
- [x] 创建 ApiClient 服务（token 管理 + 统一错误处理 + 超时控制）

### 2.2 数据模型更新
- [x] WorkLog 模型新增 serverId / createdAt / updatedAt / isSynced
- [x] User 模型新增 serverId / token

### 2.3 数据库迁移
- [x] v1→v2 迁移（work_log 表：新增 serverId, createdAt, updatedAt, isSynced）
- [x] v1→v2 迁移（user 表：新增 serverId, token）

### 2.4 同步服务
- [x] SyncService（pushChanges / pullChanges / sync）
- [x] 增量同步逻辑（lastSyncAt 时间戳）
- [x] 冲突解决（clientId 去重, last-write-wins）
- [x] 网络异常保护（catch + 安全返回）

### 2.5 Provider 改造
- [x] AuthProvider: API 优先登录 + 本地回退
- [x] WorkLogProvider: 新建/结束/补录标记 is_synced=false
- [x] SettingsProvider: 配置方法保留（同步到服务端需后续扩展）

### 2.6 集成
- [x] main.dart 初始化 ApiClient + SyncService（使用 --dart-define API_URL 配置）
- [x] 登录后自动触发同步
- [x] 100% 离线可用（后端不可用不影响基本功能）

---

## Phase 3: 移动端适配（待定）

- [ ] `flutter create --platforms android,ios` 生成平台目录
- [ ] ReminderService 替换为 flutter_local_notifications
- [ ] FileDownloader 替换为 share_plus / path_provider
- [ ] Token 存储使用 flutter_secure_storage

---

## 部署说明

### 后端部署

```bash
# 1. 构建 Docker 镜像
cd worktime_server
docker build -t worktime-server .

# 2. 运行（本地测试）
docker run -p 8080:8080 \
  -e JWT_SECRET=your-secret-key \
  -e ALLOWED_ORIGIN=https://tsangtsingyuan.github.io \
  worktime-server

# 3. 部署到 Fly.io（推荐）
fly launch
fly secrets set JWT_SECRET=your-secret-key
fly secrets set ALLOWED_ORIGIN=https://tsangtsingyuan.github.io
fly deploy
```

### 前端构建（连接后端）

```bash
flutter build web --no-source-maps \
  --dart-define=API_URL=https://your-app.fly.dev
```

---

---

## Phase 4: 代码优化（2026-05-08 已完成）

基于测试报告《测试报告_20260508.md》的 11 项修复优化：

| # | 项目 | 类型 | 状态 |
|---|------|------|------|
| 1 | SHA-256 密码哈希存储 | 修复 | ✅ |
| 2 | TimerWidget 独立监听，避免整页重建 | 性能 | ✅ |
| 3 | DropdownButtonFormField `value` → `initialValue` | 修复 | ✅ |
| 4 | `dart:html` → `package:web` + `dart:js_interop` | 修复 | ✅ |
| 5 | `_buildQuickStats()` 拆分为独立组件 | 性能 | ✅ |
| 6 | SyncService 首次同步从本地 DB 读取 lastSyncAt | 性能 | ✅ |
| 7 | AppBar 同步状态指示器 | UX | ✅ |
| 8 | 修改昵称后 SnackBar 反馈 | UX | ✅ |
| 9 | 手动补录预填结束时间为开始+1h | UX | ✅ |
| 10 | PWA manifest 描述更新 | 工程化 | ✅ |
| 11 | async 操作后 `if (!mounted) return;` 保护 | 工程化 | ✅ |

---

## 已知问题

1. ~~Web 端 `dart:html` 已弃用，后续需迁移至 `package:web` + `dart:js_interop`~~ ✅ **已完成**
2. 安卓/iOS 平台目录为空，需重新生成
3. 无单元测试覆盖同步逻辑
4. SettingsProvider 同步到服务端的功能尚未接入 SyncService
5. 删除操作的同步尚未实现（仅新增和修改会同步）
