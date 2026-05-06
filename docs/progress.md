# 开发进度跟踪

> 更新日期：2026-05-05

## 总体进度

| 阶段 | 状态 | 进度 |
|------|------|------|
| Phase 0: Bug 修复 — Timer 持久化 | ✅ 完成 | 100% |
| Phase 1: 后端服务 (worktime_server) | 🔄 进行中 | 0% |
| Phase 2: Flutter 客户端改造 | ⏳ 待开始 | 0% |
| Phase 3: 移动端适配 | ⏳ 待定 | 0% |

---

## Phase 0: Bug 修复（已完成）

- [x] **TimerProvider** — 新增 `resumeFromOngoingTask()` 方法，从 DB 恢复进行中任务计时
- [x] **HomeScreen** — `initState` 中检测 `_activeLog` 后自动恢复计时器
- [x] **WorkLogProvider.endTask** — 改为从 `_todayLogs` 列表读取完整记录，不再依赖 `_activeLog`
- [x] **构建验证** — `flutter analyze` 无错误，`flutter build web` 编译通过
- [x] **已部署** — 已提交推送至 GitHub Pages

---

## Phase 1: 后端服务

### 1.1 项目初始化
- [ ] 创建 worktime_server 项目结构
- [ ] 配置 pubspec.yaml 依赖
- [ ] 创建 .env.example 配置文件

### 1.2 数据库层
- [ ] 实现 SQLite 初始化（users 表 + work_logs 表）
- [ ] 实现用户 CRUD（create_user, get_user_by_phone, update_user）
- [ ] 实现日志 CRUD（insert_log, update_log, delete_log, get_logs_since）

### 1.3 认证
- [ ] 实现 bcrypt 密码哈希
- [ ] 实现 JWT token 签发与验证
- [ ] 实现注册端点 POST /api/auth/register
- [ ] 实现登录端点 POST /api/auth/login
- [ ] 实现 JWT 认证中间件

### 1.4 日志 API
- [ ] 实现 GET /api/worklogs 获取日志
- [ ] 实现 POST /api/worklogs 创建日志
- [ ] 实现 PUT /api/worklogs/:id 更新日志
- [ ] 实现 DELETE /api/worklogs/:id 删除日志

### 1.5 批量同步
- [ ] 实现 POST /api/sync 批量同步端点
- [ ] 实现增量变更检测（`updated_at > lastSyncAt`）

### 1.6 用户设置 API
- [ ] 实现 GET /api/settings
- [ ] 实现 PUT /api/settings

### 1.7 部署配置
- [ ] 编写 Dockerfile
- [ ] 编写 fly.io 配置（如有需要）
- [ ] 编写部署说明

---

## Phase 2: Flutter 客户端改造

### 2.1 HTTP 客户端
- [ ] 添加 http 包依赖
- [ ] 创建 ApiClient 服务（token 管理 + 统一错误处理）

### 2.2 数据模型更新
- [ ] WorkLog 模型新增 serverId / createdAt / updatedAt / isSynced 字段
- [ ] User 模型新增 serverId / token 字段

### 2.3 数据库迁移
- [ ] 实现 v1→v2 迁移（新增 server_id, created_at, updated_at, is_synced 列）
- [ ] 实现 v1→v2 迁移（user 表新增 server_id, token 列）

### 2.4 同步服务
- [ ] 创建 SyncService（pushChanges / pullChanges / sync）
- [ ] 实现增量同步逻辑（lastSyncAt 时间戳）
- [ ] 冲突解决（last-write-wins）

### 2.5 Provider 改造
- [ ] AuthProvider: API 优先登录 + 本地回退
- [ ] WorkLogProvider: 每次变更标记 is_synced=false + 触发推送
- [ ] SettingsProvider: 同步设置到服务端

### 2.6 集成
- [ ] main.dart 初始化 ApiClient + SyncService
- [ ] 登录后自动触发同步
- [ ] 异常处理和重试逻辑

---

## Phase 3: 移动端适配（待定）

- [ ] `flutter create --platforms android,ios` 生成平台目录
- [ ] ReminderService 替换为 flutter_local_notifications
- [ ] FileDownloader 替换为 share_plus / path_provider
- [ ] Token 存储使用 flutter_secure_storage

---

## 已知问题

1. Web 端 `dart:html` 已弃用，后续需迁移至 `package:web` + `dart:js_interop`
2. 安卓/iOS 平台目录为空，需重新生成
3. 无单元测试覆盖同步逻辑
