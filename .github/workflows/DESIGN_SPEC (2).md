# luci-app-fcc — 完整开发设计方案 / Claude Code 执行规范

> 项目定位：**运行在 OpenWrt / ImmortalWrt 上的 FCC 综合管理器**
>
> 核心能力：
>
> 1. **Web Terminal**：选择、启动、连接、关闭 Claude Code / Codex / Pi / OpenCode / Cline / Hermes / DeepSeek Harness / Grok Build / Muse Code / Aider。
> 2. **FCC Server Manager**：启动、停止、重启 `fcc-server`，并直接进入 FCC `/admin` 配置 API Key、Provider、Model。
> 3. **Runtime Monitor**：监控 Luci-FCC、FCC、FCC Server、各 Coding Agent 的版本、状态、PID、Uptime、内存占用，并显示 OpenWrt 系统内存和存储空间；支持 FCC 版本更新。
>
> **本文件就是 Claude Code 的实施规范。执行本文件时，不要只生成设计文档；应直接创建/修改代码、测试、CI 和文档，直到达到验收标准。**

---

## 0. 执行规则

Claude Code 执行本项目时必须遵守：

1. 先检查当前仓库是否已有代码；如果为空仓库，按本文创建完整项目。
2. 如果当前仓库已有代码，不要盲目覆盖；先分析现有结构，再将本文要求整合进去。
3. 必须实际检查上游 FCC 当前代码，而不是根据旧版本猜测命令名称、版本号或安装方式。
4. 必须实际检查 `10000ge10000/luci-app-openclaw` 当前实现，把它作为 LuCI、Runtime、Service、CI 和 Web Terminal 的参考。
5. Agent launcher 必须以 FCC 当前 `pyproject.toml` / installer 为事实来源。当前上游已定义：
   - `fcc-server`
   - `fcc-claude`
   - `fcc-codex`
   - `fcc-pi`
   - `fcc-opencode`
   - `fcc-cline`
   - `fcc-hermes`
   - `fcc-dsh`
   - `fcc-grok`
   - `fcc-muse`
   - `fcc-aider`
6. UI 中的名称使用友好名称，但内部使用稳定的 agent ID：
   - `claude`
   - `codex`
   - `pi`
   - `opencode`
   - `cline`
   - `hermes`
   - `dsh`
   - `grok`
   - `muse`
   - `aider`
7. 不允许把 API Key 明文保存到 `/etc/config/fcc`。
8. 不允许从 HTTP 参数直接拼接 shell 命令；所有 agent、action、路径必须白名单校验。
9. Web Terminal 必须是真正的 PTY/interactive terminal，而不是 textarea + HTTP POST。
10. 优先使用 tmux 管理持久化 session；如果目标 OpenWrt 环境没有 tmux，则实现独立 PTY/session backend。
11. `fcc-server` 与 Agent session 必须有独立生命周期。
12. FCC 更新前必须进行状态检查；更新失败不能让 LuCI 本身不可用。
13. 所有安装、更新、卸载和运行时操作都必须记录日志。
14. 必须支持英文和简体中文。
15. 必须提供 OpenWrt 24.10 `.ipk` 和 OpenWrt 25.12 `.apk` 的 CI 构建。
16. 第一阶段重点架构：`x86_64` 和 `aarch64`；代码结构不得限制以后增加其它架构。
17. 不要把完整 Python/Node/FCC runtime 强行塞入 `luci-app-fcc` LuCI package；LuCI 包应尽量轻量，Runtime 独立管理。
18. 不要因为某一个 Agent 不可安装而阻塞其它 Agent。每个 Agent 必须具有独立 installed/running/error 状态。
19. 所有版本检测都应动态读取实际 executable/package 信息，不要把当前 FCC 版本硬编码为运行时版本。
20. 完成后必须执行 lint、shellcheck（如果环境可用）、Lua 语法检查、package manifest 检查以及可执行的集成测试。

---

# 1. 项目目标

创建：

```text
luci-app-fcc
```

用于在 OpenWrt / ImmortalWrt 上管理：

```text
Free Claude Code (FCC)
```

目标用户不需要 SSH 到路由器执行：

```bash
fcc-server
fcc-claude
fcc-codex
fcc-pi
fcc-opencode
...
```

而是通过 LuCI：

```text
LuCI
  -> Services
      -> FCC
```

完成安装、配置、启动、停止、连接和监控。

---

# 2. 三个主 Tab

LuCI 页面必须只有三个核心 Tab：

```text
Web 控制台
配置管理
基本信息
```

推荐菜单：

```text
Services
└── FCC
    ├── Web 控制台
    ├── 配置管理
    └── 基本信息
```

英文：

```text
Services
└── FCC
    ├── Web Console
    ├── Configuration
    └── Basic Information
```

---

# 3. 技术栈、轻量化与资源约束（强制规范）

> **本章是整个项目的架构级硬性约束。后续 Web Terminal、Runtime、Server Manager、Monitor、Package、CI 和测试设计均必须遵守本章。**
>
> 核心原则：**`luci-app-fcc` 必须是轻量级 LuCI 控制层；FCC Runtime 是独立、可选、可升级的运行环境。安装 LuCI-FCC 不应因为管理功能而强制引入 Python、Node.js、数据库或大型 Web Framework。**

## 3.1 总体技术栈

### LuCI / 前端

必须优先使用 OpenWrt/LuCI 原生能力：

```text
Lua
LuCI View / Controller / RPC
Native JavaScript
HTML
CSS
LuCI 原生 UI / form / DOM API
Browser WebSocket API
xterm.js（仅 Web Terminal 所需）
```

禁止为了 UI 引入：

```text
React
Vue
Svelte
Angular
jQuery
Bootstrap
Tailwind CSS
大型 UI Framework
大型状态管理框架
```

前端不应依赖 npm/node 才能在目标路由器运行。

Node.js、npm、pnpm、yarn 等如果用于构建 xterm.js 等静态资源，只能存在于**开发/CI 构建环境**，不得成为 `luci-app-fcc` 的运行时依赖。

### LuCI 后端

优先使用：

```text
Lua
rpcd
ubus
UCI
procd
POSIX / OpenWrt ash
/proc
/sys
sysfs
```

禁止为了提供 LuCI-FCC API 引入：

```text
Flask
FastAPI
Django
Express
Koa
Node.js HTTP Server
独立 Python Web Framework
数据库 Server
Redis
Docker
```

### FCC Runtime

FCC Runtime 与 LuCI package 完全分层：

```text
LuCI package
    ↓
Runtime Manager / Session Manager
    ↓
FCC Runtime
    ├── Python
    ├── uv
    ├── Node.js（如上游 Agent 需要）
    ├── fcc-server
    └── Coding Agents
```

Python、Node.js、uv 是否存在以及具体版本，必须由 Runtime Manager 动态检测。

---

## 3.2 Dependency Minimalism

`luci-app-fcc` 必须遵循最小依赖原则。

### LuCI package 不得强制依赖

```text
python
node
npm
pnpm
yarn
uv
docker
sqlite
redis
数据库
独立 Web Server
独立 WebSocket Server
```

可以依赖 OpenWrt 已有的基础组件，例如：

```text
luci-base
rpcd
ubus
procd
```

具体 package dependency 必须根据实际代码和目标 OpenWrt 版本确定，不能为了“方便开发”增加大型运行时依赖。

### Runtime dependency 不等于 LuCI dependency

例如：

```text
Python >= 3.14
Node.js
uv
FCC
```

属于：

```text
FCC Runtime dependency
```

而不是：

```text
Package/luci-app-fcc DEPENDS
```

这是本项目的重要架构边界。

---

## 3.3 Resource Usage Targets

设计目标是让老旧 OpenWrt / ImmortalWrt 设备至少可以安装并运行 LuCI-FCC 的管理层。

### 空闲状态

在没有打开 Web Terminal、没有执行更新、没有 Runtime 安装任务时：

```text
luci-app-fcc 不应运行常驻 Node.js/Python daemon
不应运行数据库
不应运行独立 WebSocket server
不应持续高频轮询
```

### CPU

Web Console 没有活动 Terminal 时：

```text
目标：接近 0% CPU
```

状态刷新应采用低频、批量方式：

```text
Runtime status：约 1~2 秒一次
Version information：页面打开时查询，或 30~60 秒刷新
```

禁止：

```text
100 ms 高频轮询
每个 Agent 单独启动一个 ps/grep/df shell
```

### 内存

目标：

```text
LuCI-FCC 管理层本身尽量保持在低十 MB 级增量以内。
```

这里是工程目标而不是绝对 ABI 保证；最终数值必须通过实际设备测试记录。

### Package size

目标：

```text
luci-app-fcc package 尽量保持在 1~2 MB 级别。
```

如果 xterm.js 静态资源导致超出目标，必须优先：

```text
压缩
去除不需要的 addon
避免重复依赖
```

而不是引入更大的前端 Framework。

---

## 3.4 Web Terminal 的轻量化原则

Terminal 必须支持真正的交互式 PTY，但不得因此引入完整 Node/Python Web Terminal Server。

推荐架构：

```text
Browser
   │
   │ WebSocket
   ▼
Minimal Terminal / PTY backend
   │
   ▼
tmux（如果可用）
   │
   ▼
fcc-claude / fcc-codex / ...
```

LuCI Controller 主要负责：

```text
权限
Session 创建/关闭
Session 列表
参数验证
状态查询
```

Terminal 数据流应尽可能：

```text
event-driven
```

而不是：

```text
HTTP polling
```

浏览器刷新、断线、重新连接不得导致新的 Agent process 被重复启动。

---

## 3.5 Runtime 与老设备兼容策略

设备能力分层：

### Tier 1 — Low Resource

典型：

```text
128 MB RAM
单核/低频 CPU
较小 Flash
```

必须支持：

```text
LuCI-FCC 安装
Configuration
Basic Information
FCC Server 状态管理
```

不要求在设备本机运行全部 Coding Agent。

### Tier 2 — Standard

典型：

```text
256 MB RAM+
双核+
```

目标支持：

```text
Web Terminal
FCC Server
至少一个或多个 Agent
```

### Tier 3 — High Resource

典型：

```text
512 MB / 1 GB+ RAM
```

可以支持：

```text
多个 Agent
多个 Session
更完整的 FCC Runtime
```

**设备是否能够运行 Agent，不应影响 LuCI-FCC 本身的安装。**

---

## 3.6 前端构建规则

允许：

```text
Node.js / npm / pnpm
```

仅用于：

```text
CI
开发机
静态资源构建
```

例如：

```text
xterm.js
```

构建完成后，发布到：

```text
htdocs/luci-static/resources/fcc/
```

目标设备不需要 Node.js 才能打开 LuCI-FCC。

前端应尽量采用：

```text
ES6+ / 浏览器原生 API
```

但必须考虑 OpenWrt/LuCI 实际支持的浏览器环境，不应为了极少数语法便利引入大型 polyfill。

---

## 3.7 后端实现规则

系统管理操作必须集中在受控 helper 中，例如：

```text
/usr/bin/fcc-env
/usr/libexec/fcc/*
```

Lua Controller 不应直接拼接复杂 shell：

```text
错误：
os.execute("...用户输入...")
```

推荐：

```text
Lua Controller
    ↓
rpcd / controlled helper
    ↓
whitelisted action
    ↓
procd / tmux / FCC Runtime
```

所有参数必须：

```text
白名单
长度限制
字符限制
路径 canonicalization
权限检查
```

---

## 3.8 状态查询必须批量化

Basic Information 页面不得为每个 Agent 分别执行大量 shell 命令。

推荐提供：

```text
/usr/libexec/fcc/status
```

一次性返回：

```json
{
  "fcc": {},
  "server": {},
  "agents": {},
  "system_memory": {},
  "storage": {}
}
```

数据来源优先：

```text
/proc
ubus
procd
statvfs
实际 executable
```

避免：

```text
ps | grep
df | grep
每个 Agent 一次 shell
```

造成的额外 CPU 和 process fork 开销。

---

## 3.9 轻量化验收标准

Claude Code 在完成实现后必须验证：

1. `luci-app-fcc` 安装不会自动安装 Python/Node.js。
2. 无 FCC Runtime 时，LuCI-FCC 仍能打开三个 Tab。
3. 无 FCC Runtime 时，Basic Information 能显示“Not Installed / 未安装”状态，而不是页面报错。
4. Web Console 无活动 Session 时没有常驻 Agent process。
5. 页面关闭不会自动创建新的 Agent process。
6. 状态刷新不会产生大量短生命周期 shell process。
7. xterm.js 以静态资源方式发布，目标设备不需要 npm/node。
8. FCC Runtime 的 Python/Node/uv 不进入 LuCI package manifest。
9. 所有后台常驻进程都必须有明确的生命周期和用途。
10. 在至少一台低资源 OpenWrt/ImmortalWrt 测试设备上记录实际 RSS/CPU/Flash 占用。

---

# 4. Web 控制台

## 3.1 目标

Web 控制台负责：

- 选择 Agent
- 启动 Agent
- 连接已经存在的 Agent session
- 关闭 Agent
- 查看 session 状态
- 提供真实交互式 Terminal
- 支持 detach/reconnect
- 支持多个不同 Agent session

## 3.2 Agent 列表

UI 下拉框：

```text
Claude Code
Codex
Pi
OpenCode
Cline
Hermes
DeepSeek Harness
Grok Build
Muse Code
Aider
```

内部映射：

```text
claude  -> fcc-claude
codex   -> fcc-codex
pi      -> fcc-pi
opencode -> fcc-opencode
cline   -> fcc-cline
hermes  -> fcc-hermes
dsh     -> fcc-dsh
grok    -> fcc-grok
muse    -> fcc-muse
aider   -> fcc-aider
```

不要假设所有 Agent 在所有架构上都可用。

Runtime Manager 必须返回：

```text
installed
available
running
version
error
```

---

# 5. Web Terminal UI

推荐布局：

```text
┌─────────────────────────────────────────────────────────┐
│ Web Console                                             │
├─────────────────────────────────────────────────────────┤
│ Agent: [ Claude Code                              ▼ ]   │
│                                                         │
│ [Start / Connect]     [Close Session]                  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  xterm.js                                               │
│                                                         │
│  Claude Code                                            │
│  > Hello                                                │
│                                                         │
│  ...                                                    │
│                                                         │
│  > █                                                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

必须使用：

```text
xterm.js
WebSocket
PTY
```

不得使用：

```text
<textarea>
HTTP POST command execution
```

---

# 6. Terminal 功能要求

必须支持：

- ANSI escape sequences
- ANSI color
- cursor movement
- backspace
- Enter
- Ctrl+C
- Ctrl+D
- Ctrl+Z（如果 Agent/PTY 支持）
- Tab
- arrow keys
- Home/End
- PageUp/PageDown
- interactive prompt
- multiline input
- terminal resize
- disconnect/reconnect
- session persistence
- UTF-8
- CJK text

xterm.js 必须能够读取浏览器 terminal 的 resize 信息并传递到 PTY。

---

# 7. Session 管理

必须支持：

```text
create
attach
detach
close
list
status
```

例如：

```text
Claude Code
● Running
Session: claude-001
PID: 12345
```

用户关闭浏览器后：

```text
Browser closed
```

不能默认杀掉：

```text
fcc-claude
```

再次进入：

```text
Web Console
 -> Claude Code
 -> Connect
```

应连接到原 session。

---

# 8. Session Backend

第一优先方案：

```text
tmux
```

例如：

```bash
tmux new-session -d -s fcc-claude-001 fcc-claude
```

然后通过 backend 连接：

```text
Browser
  <-> WebSocket
  <-> Terminal Backend
  <-> tmux
  <-> fcc-claude
```

如果目标系统无法使用 tmux，则实现原生 PTY backend。

不得依赖 Python 的第三方 web terminal framework 才能运行 LuCI Terminal。

---

# 9. Agent Session 命名

不要直接使用用户输入作为 session 名。

统一：

```text
fcc-<agent>-<id>
```

例如：

```text
fcc-claude-001
fcc-codex-001
fcc-pi-001
fcc-opencode-001
```

ID 必须由 backend 生成。

---

# 10. Agent 关闭

用户点击：

```text
Close Session
```

必须先弹确认：

```text
Are you sure you want to close this session?
All unsaved terminal state will be lost.
```

中文：

```text
确定要关闭此会话吗？
未保存的终端状态将会丢失。
```

然后：

```text
kill session
```

不得误杀：

```text
fcc-server
```

---

# 11. FCC Server Manager

配置管理 Tab：

```text
Configuration
```

负责：

```text
start
stop
restart
status
```

页面：

```text
┌──────────────────────────────────────────────┐
│ FCC Server                                   │
├──────────────────────────────────────────────┤
│ Status       ● Running                       │
│ Version      6.x.x                           │
│ PID          12345                           │
│ Port         8082                            │
│ Address      127.0.0.1:8082                │
│ Uptime       02:31:12                        │
│ Memory       128 MB                          │
│                                              │
│ [Start] [Stop] [Restart]                    │
└──────────────────────────────────────────────┘
```

---

# 12. FCC Server 与 Agent 的生命周期

必须严格分离：

```text
fcc-server
    |
    +-- fcc-claude
    +-- fcc-codex
    +-- fcc-pi
    +-- fcc-opencode
    +-- ...
```

停止：

```text
fcc-claude
```

不得自动停止：

```text
fcc-server
```

停止：

```text
fcc-server
```

必须提示：

```text
Stopping FCC Server may affect active Coding Agent sessions.
```

但是否终止 Agent session，应由实现明确处理并显示结果。

---

# 13. FCC Admin

配置管理页面必须提供：

```text
[Open FCC Admin]
```

目标：

```text
http://<OpenWrt-LAN-IP>:8082/admin
```

不要把：

```text
http://127.0.0.1:8082/admin
```

直接作为浏览器跳转地址，因为浏览器中的 `127.0.0.1` 是用户电脑。

## 推荐实现

优先：

```text
FCC server bind:
0.0.0.0:8082
```

然后 OpenWrt firewall：

```text
LAN -> TCP/8082 ACCEPT
WAN -> TCP/8082 DROP
```

如果 FCC 当前版本不允许安全地监听 LAN，则实现 LuCI reverse proxy。

---

# 14. FCC Admin 的职责

不要在 LuCI 中复制 FCC Admin 的 Provider UI。

FCC Admin 负责：

```text
API Key
Provider
Model
Proxy Authentication
FCC-specific configuration
```

LuCI 只负责打开：

```text
/admin
```

这样可以避免：

```text
FCC Admin Schema
        vs
LuCI Schema
```

长期不一致。

---

# 15. 基本信息 / Runtime Monitor

第三个 Tab：

```text
Basic Information
```

必须显示：

## 14.1 Luci-FCC

```text
Luci-FCC Version
```

例如：

```text
0.1.0
```

该版本来自：

```text
PKG_VERSION
```

或安装包内的：

```text
/usr/share/luci-app-fcc/VERSION
```

## 14.2 FCC

显示：

```text
FCC Version
```

必须动态检测。

## 14.3 FCC Server

显示：

```text
Status
Version
PID
Uptime
Memory
Port
```

## 14.4 每个 Agent

显示：

```text
Name
Status
Version
PID
Uptime
Memory
```

---

# 16. 基本信息示例

```text
┌────────────────────────────────────────────────────────┐
│ Basic Information                                      │
├────────────────────────────────────────────────────────┤
│                                                        │
│ Luci-FCC                                               │
│ Version              0.1.0                             │
│                                                        │
│ FCC Runtime                                            │
│ Version              6.2.x                             │
│                                                        │
│ FCC Server                                             │
│ Status               ● Running                         │
│ Version              6.2.x                             │
│ PID                  12345                             │
│ Uptime               03:25:18                          │
│ Memory               128 MB                            │
│ Port                 8082                              │
│                                                        │
├────────────────────────────────────────────────────────┤
│ Coding Agents                                          │
├────────────────────────────────────────────────────────┤
│ Agent             Status       Version      Memory     │
│ Claude Code       ● Running    1.x.x        256 MB     │
│ Codex             ○ Stopped    0.x.x        --         │
│ Pi                ○ Stopped    0.x.x        --         │
│ OpenCode          ● Running    1.x.x        180 MB     │
│ Cline             ○ Stopped    2.x.x        --         │
│ Hermes            ○ Stopped    0.x.x        --         │
│ DeepSeek Harness  ○ Stopped    0.x.x        --         │
│ Grok Build        ○ Stopped    0.x.x        --         │
│ Muse Code         ○ Stopped    0.x.x        --         │
│ Aider             ○ Stopped    0.x.x        --         │
│                                                        │
├────────────────────────────────────────────────────────┤
│ System                                                  │
├────────────────────────────────────────────────────────┤
│ Architecture         x86_64                             │
│ Memory               1.2 GB / 2 GB                      │
│ Storage              2.1 GB / 8 GB                      │
│                                                        │
└────────────────────────────────────────────────────────┘
```

---

# 17. 内存监控

至少监控：

```text
FCC Server RSS
Agent RSS
System memory
```

Linux/OpenWrt 下优先读取：

```text
/proc/<PID>/status
```

中的：

```text
VmRSS
```

示例：

```text
VmRSS: 123456 kB
```

显示为：

```text
120.56 MB
```

不要仅通过 `ps` 的显示文本解析。

如果 Agent 有多个 child process：

```text
Agent
  ├── main process
  ├── child process
  └── helper process
```

第一版至少显示主 PID RSS。

如果实现成本允许，增加：

```text
Process Tree RSS
```

作为高级信息。

---

# 18. System Memory

读取：

```text
/proc/meminfo
```

显示：

```text
Used
Available
Total
```

推荐：

```text
Memory
1.2 GB / 2 GB
```

同时显示：

```text
FCC Server: 128 MB
Claude Code: 256 MB
```

这样用户可以区分：

```text
System memory
FCC memory
Agent memory
```

---

# 19. Storage

读取：

```text
statvfs
```

或者：

```bash
df
```

但 Lua API 不应依赖不稳定的 `df` 文本格式。

优先使用 Lua/POSIX statvfs 能力；如果当前 LuCI/OpenWrt 环境不适合，则使用可靠的 helper。

显示：

```text
Storage
2.1 GB / 8 GB
```

同时显示：

```text
Free
Used
Total
```

重点检查 FCC installation path。

---

# 20. Runtime Monitor 自动刷新

状态数据：

```text
1~2 seconds
```

刷新：

```text
Server Status
PID
Uptime
Memory
Agent Status
Agent PID
Agent Memory
System Memory
```

版本信息：

```text
30~60 seconds
```

或者页面打开时检测。

避免每秒执行所有：

```text
--version
```

命令。

---

# 21. Status API

实现：

```text
GET /admin/services/fcc/status
```

建议返回：

```json
{
  "luci_fcc": {
    "version": "0.1.0"
  },
  "fcc": {
    "installed": true,
    "version": "6.2.x"
  },
  "server": {
    "running": true,
    "pid": 12345,
    "version": "6.2.x",
    "uptime": 12345,
    "memory_rss_kb": 131072,
    "port": 8082
  },
  "system": {
    "memory_total_kb": 2097152,
    "memory_available_kb": 1048576,
    "storage_total_bytes": 8589934592,
    "storage_free_bytes": 4294967296
  },
  "agents": {
    "claude": {
      "name": "Claude Code",
      "command": "fcc-claude",
      "installed": true,
      "running": true,
      "pid": 12350,
      "version": "1.x.x",
      "memory_rss_kb": 262144
    },
    "codex": {
      "name": "Codex",
      "command": "fcc-codex",
      "installed": true,
      "running": false,
      "pid": null,
      "version": "0.x.x",
      "memory_rss_kb": 0
    }
  }
}
```

前端必须处理字段缺失、command 不存在和 version 检测失败。

---

# 22. Runtime Manager

提供：

```text
/usr/bin/fcc-env
```

统一管理 FCC Runtime。

命令：

```bash
fcc-env status
fcc-env version
fcc-env doctor
fcc-env install
fcc-env uninstall
fcc-env update
fcc-env start
fcc-env stop
fcc-env restart
```

Agent：

```bash
fcc-env agent list
fcc-env agent status <agent>
fcc-env agent version <agent>
fcc-env agent install <agent>
fcc-env agent remove <agent>
```

不要让 LuCI controller 自己执行复杂的安装逻辑。

LuCI 调：

```text
fcc-env
```

Runtime Manager 再执行实际操作。

---

# 23. FCC 更新

基本信息页面必须提供：

```text
Current FCC Version
6.2.x

Latest FCC Version
6.2.y

[Check Update]
[Update FCC]
```

更新功能必须：

1. 检查当前版本。
2. 检查最新可用版本。
3. 检查磁盘空间。
4. 检查当前是否有 Agent session。
5. 提示用户更新可能影响正在运行的 Agent。
6. 备份 FCC 配置/数据。
7. 停止 FCC Server。
8. 必要时停止/冻结相关 Agent。
9. 更新 FCC Runtime。
10. 校验安装结果。
11. 启动 FCC Server。
12. 健康检查。
13. 恢复可用状态。
14. 失败时尽可能回滚到更新前版本。

---

# 24. 更新不能影响 Luci-FCC

这是强制要求。

禁止：

```text
luci-app-fcc update
```

直接删除：

```text
/usr/lib/lua/luci/*
```

或者替换 LuCI 自身。

FCC 更新只允许影响：

```text
/opt/fcc/
```

或 UCI 中配置的 Runtime installation path。

---

# 25. 更新数据保护

更新前至少备份：

```text
FCC configuration
FCC data
FCC provider/model settings
```

如果 FCC 当前数据目录是：

```text
~/.fcc
```

则 OpenWrt Runtime 中统一映射到：

```text
<install_path>/data/.fcc
```

但必须根据当前上游 FCC 实际行为确认，不要凭旧版本假设。

备份：

```text
<install_path>/backup/
```

例如：

```text
backup/
└── fcc-2026-09-28-120000.tar.gz
```

保留最近 N 个备份。

---

# 26. FCC 更新源

不要在 LuCI 页面硬编码某个旧版本。

更新源应支持：

```text
GitHub Releases
PyPI
官方 FCC package metadata
```

优先使用 FCC 官方发布机制。

如果当前 FCC 没有稳定 Release API，则 Runtime Manager 应从官方 package metadata 查询。

更新器必须验证：

```text
version
checksum
download success
installation success
```

如果能获得 SHA256：

```text
SHA256 verification
```

必须启用。

---

# 27. Runtime 路径

默认：

```text
/opt/fcc
```

允许 UCI 配置：

```uci
config fcc 'main'
    option enabled '1'
    option install_path '/opt/fcc'
    option port '8082'
    option bind '127.0.0.1'
    option auto_start '1'
```

实际 Runtime：

```text
/opt/fcc/
├── runtime/
├── bin/
├── data/
├── cache/
├── logs/
├── sessions/
└── backup/
```

如果用户设置：

```text
/mnt/sda
```

实际使用：

```text
/mnt/sda/fcc
```

类似路径设计可以参考 `luci-app-openclaw`。

---

# 28. UCI

文件：

```text
/etc/config/fcc
```

最小配置：

```uci
config fcc 'main'
    option enabled '1'
    option install_path '/opt/fcc'
    option port '8082'
    option bind '127.0.0.1'
    option auto_start '1'
    option session_backend 'tmux'
```

Agent 配置可选：

```uci
config agent 'claude'
    option enabled '1'

config agent 'codex'
    option enabled '1'

config agent 'pi'
    option enabled '1'

config agent 'opencode'
    option enabled '1'

config agent 'cline'
    option enabled '1'

config agent 'hermes'
    option enabled '1'

config agent 'dsh'
    option enabled '1'

config agent 'grok'
    option enabled '1'

config agent 'muse'
    option enabled '1'

config agent 'aider'
    option enabled '1'
```

但是安装状态不能仅依赖 UCI。

真正状态：

```text
installed
available
running
```

由 Runtime Manager 动态检测。

---

# 29. API Key 安全

禁止：

```uci
option api_key 'sk-xxxxx'
```

禁止：

```text
log API Key
```

禁止：

```text
JSON status API 返回 API Key
```

禁止：

```text
浏览器 console.log API Key
```

FCC Admin 自己负责 credentials。

---

# 30. 安全模型

所有 LuCI API 必须：

- 使用 LuCI ACL/rpcd 权限。
- 所有 mutation API 要求 authenticated LuCI session。
- 所有 command 参数白名单化。
- 所有 filesystem path canonicalize。
- 禁止路径 traversal。
- 禁止任意 shell command。
- 禁止任意 executable path。
- WebSocket 连接必须经过 LuCI/uhttpd authentication boundary。
- Session ID 必须随机且不能由用户直接构造为任意 tmux session。
- Agent 名称必须从固定字典中选择。
- Runtime update URL 必须使用可信来源。
- 下载文件必须进行完整性验证。
- WAN 默认不得开放 FCC Admin port。

---

# 31. Controller

建议：

```text
luasrc/controller/fcc.lua
```

路由：

```text
/admin/services/fcc
/admin/services/fcc/console
/admin/services/fcc/config
/admin/services/fcc/info
/admin/services/fcc/status
/admin/services/fcc/server_start
/admin/services/fcc/server_stop
/admin/services/fcc/server_restart
/admin/services/fcc/agent_list
/admin/services/fcc/session_create
/admin/services/fcc/session_list
/admin/services/fcc/session_close
/admin/services/fcc/update_check
/admin/services/fcc/update
```

WebSocket route 如果当前 LuCI/uhttpd 架构无法直接由 Lua Controller 支持，则使用独立 terminal backend。

---

# 32. 推荐 Controller API

不要让页面直接执行 shell。

Controller：

```text
Controller
   ↓
fcc-env
   ↓
Runtime Manager
   ↓
system process
```

例如：

```lua
function server_start()
    return exec_safe("/usr/bin/fcc-env", "start")
end
```

实际实现必须根据 LuCI 当前 API 使用 `luci.sys`, `luci.util`, `ubus` 或受控 helper。

---

# 33. 页面文件

建议：

```text
luasrc/view/fcc/
├── console.htm
├── config.htm
└── info.htm
```

前端静态资源：

```text
htdocs/luci-static/resources/fcc/
├── xterm.js
├── xterm.css
└── fcc-terminal.js
```

如果 xterm.js 太大，必须评估是否作为独立 asset/package；不要让 LuCI package 无限膨胀。

---

# 34. LuCI 页面

## console.htm

负责：

```text
Agent dropdown
Start / Connect
Close
Session list
Terminal
WebSocket
```

## config.htm

负责：

```text
FCC Server status
Start
Stop
Restart
Open FCC Admin
```

## info.htm

负责：

```text
Luci-FCC version
FCC version
Server status
Server version
PID
Uptime
Memory
Agent status
Agent version
Agent PID
Agent memory
System memory
Storage
Update check
Update FCC
```

---

# 35. 版本信息

Luci-FCC 自己：

```text
VERSION
```

例如：

```text
0.1.0
```

Makefile：

```make
PKG_NAME:=luci-app-fcc
PKG_VERSION:=$(strip $(shell cat $(CURDIR)/VERSION))
PKG_RELEASE:=1
```

不要把 FCC runtime version 写进：

```text
PKG_VERSION
```

两者独立：

```text
Luci-FCC Version = 0.1.0
FCC Version = 6.2.x
```

---

# 36. OpenWrt Package

`Makefile` 必须兼容：

```text
OpenWrt 24.10
OpenWrt 25.12
```

不要依赖旧 LuCI feed 自动生成 Package 定义。

推荐显式：

```make
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/package.mk

define Package/luci-app-fcc
    SECTION:=luci
    CATEGORY:=LuCI
    SUBMENU:=3. Applications
    TITLE:=FCC AI Coding Agent Manager
    DEPENDS:=+luci-base +luci-compat +curl +ca-bundle +tmux
    PKGARCH:=all
endef
```

实际依赖必须根据最终实现检查。

如果 tmux 不是强依赖，则不要强制依赖。

---

# 37. Package 安装内容

至少：

```text
/etc/config/fcc
/etc/init.d/fcc

/usr/bin/fcc-env

/usr/lib/lua/luci/controller/fcc.lua

/usr/lib/lua/luci/view/fcc/console.htm
/usr/lib/lua/luci/view/fcc/config.htm
/usr/lib/lua/luci/view/fcc/info.htm

/usr/share/rpcd/acl.d/luci-app-fcc.json

/usr/share/luci-app-fcc/VERSION
```

以及：

```text
/usr/libexec/fcc/*
```

和静态资源。

---

# 38. Init Script

```text
/etc/init.d/fcc
```

使用：

```text
procd
```

负责 FCC Server。

必须支持：

```bash
/etc/init.d/fcc start
/etc/init.d/fcc stop
/etc/init.d/fcc restart
/etc/init.d/fcc status
/etc/init.d/fcc enable
/etc/init.d/fcc disable
```

启动前：

- 检查 Runtime。
- 检查 FCC executable。
- 检查 install path。
- 检查端口。
- 检查权限。
- 检查配置。
- 失败时写日志。

---

# 39. Log

统一：

```text
<install_path>/logs/
```

例如：

```text
fcc-server.log
fcc-runtime.log
fcc-update.log
fcc-terminal.log
```

LuCI 页面可以显示最近日志：

```text
[View Logs]
```

但默认不要把整个日志自动加载到页面。

---

# 40. Runtime 安装

不要直接照搬：

```bash
curl ... | sh
```

尤其不要在 LuCI API 中：

```bash
curl URL | sh
```

应该：

```text
Download
↓
Verify
↓
Extract
↓
Install
↓
Validate
↓
Enable
```

上游 FCC installer 可以作为行为参考，但 OpenWrt Runtime 必须有自己的 adapter。

---

# 41. Python Runtime

必须在实现阶段确认当前 FCC 要求。

当前上游 `pyproject.toml` 要求：

```text
Python >= 3.14.0
```

并且当前项目使用：

```text
py314
```

作为 Ruff target。

不要写死旧版：

```text
Python 3.14.7
```

除非当前上游再次明确要求固定 patch version。

OpenWrt 系统 Python 与 FCC Runtime Python 应解耦。

优先：

```text
FCC Runtime 自包含 Python
```

或者：

```text
OpenWrt Python >= required version
```

只有经过实际兼容性测试才能采用系统 Python。

---

# 42. Node Runtime

部分 Agent 依赖 Node.js/npm。

不要假设 OpenWrt 的 Node 版本永远满足 Agent。

Runtime Manager 应检测：

```bash
node --version
npm --version
```

并根据当前上游 installer / agent requirement 决定：

```text
system node
```

或：

```text
bundled node
```

优先复用系统满足版本要求的 Node，避免重复占用空间。

---

# 43. Agent 安装

默认不应该强制安装所有 Agent。

第一次安装可以：

```text
☑ Claude Code
☑ Codex
☑ Pi
☑ OpenCode
☐ Cline
☑ Hermes
☑ DeepSeek Harness
☑ Grok Build
☑ Muse Code
☑ Aider
```

但必须根据当前 FCC installer 的默认行为和目标架构调整。

用户也可以以后：

```text
Install Agent
```

---

# 44. Agent 版本检测

每个 Agent：

```text
fcc-claude --version
fcc-codex --version
...
```

但不同 CLI 可能输出格式不同。

实现统一：

```text
fcc-env agent version claude
```

返回标准：

```json
{
  "id": "claude",
  "name": "Claude Code",
  "installed": true,
  "version": "1.2.3"
}
```

如果无法检测：

```json
{
  "installed": true,
  "version": null,
  "version_error": "version command failed"
}
```

UI 显示：

```text
Unknown
```

不要显示假版本。

---

# 45. FCC Server Version

优先：

```bash
fcc-server --version
```

如果不支持：

1. 从 FCC package metadata 获取。
2. 从 installed distribution metadata 获取。
3. 从 `fcc-env` 内部记录获取。

必须明确来源。

---

# 46. Update UI

在“基本信息”增加：

```text
FCC Update

Current Version: 6.2.x
Latest Version: 6.2.y

[Check for Updates]
[Update FCC]
```

如果没有更新：

```text
You are using the latest FCC version.
```

如果有：

```text
A new FCC version is available.

Current: 6.2.x
Latest: 6.2.y

[Update]
```

更新过程显示：

```text
Downloading...
Verifying...
Stopping FCC Server...
Updating...
Starting FCC Server...
Health check...
Completed.
```

---

# 47. Update Lock

更新时创建：

```text
/tmp/fcc-update.lock
```

避免：

```text
两个浏览器同时点击 Update
```

导致两个更新进程。

完成后删除。

异常退出也要尽可能清理。

---

# 48. Install Lock

同理：

```text
/tmp/fcc-install.lock
```

防止重复安装。

---

# 49. Health Check

更新后必须检查：

```text
fcc-server process
port 8082
FCC health/admin endpoint
```

如果 FCC 提供明确 health endpoint，使用官方 endpoint。

否则至少：

```text
process exists
TCP 8082 listening
HTTP /admin returns expected response
```

---

# 50. Firewall

如果 FCC 使用：

```text
0.0.0.0:8082
```

必须提供 LAN-only firewall 规则。

不能默认：

```text
WAN -> 8082 ACCEPT
```

如果系统 firewall 不可安全修改，则默认 bind：

```text
127.0.0.1
```

并实现 LuCI reverse proxy。

---

# 51. ACL

创建：

```text
root/usr/share/rpcd/acl.d/luci-app-fcc.json
```

至少定义：

```text
read status
read config
execute server start/stop/restart
execute agent session operations
execute update
```

更新、卸载等高风险操作不能仅由前端按钮控制。

---

# 52. i18n

目录：

```text
po/
├── templates/fcc.pot
└── zh_Hans/fcc.po
```

必须支持：

```text
English
Simplified Chinese
```

所有 UI 文本都走：

```lua
_("...")
```

不要把中文直接写死到 Lua/HTML。

---

# 53. 推荐中文翻译

```text
Web Console        Web 控制台
Configuration      配置管理
Basic Information  基本信息
Coding Agent       Coding Agent
Claude Code        Claude Code
FCC Server         FCC Server
Status             状态
Running            运行中
Stopped            已停止
Installed          已安装
Not Installed      未安装
Version            版本
Memory             内存
Uptime             运行时间
PID                进程 ID
Start              启动
Stop               停止
Restart            重启
Connect            连接
Close Session      关闭会话
Open FCC Admin     打开 FCC Admin
Check for Updates  检查更新
Update FCC         更新 FCC
Storage            存储空间
System Memory      系统内存
```

---

# 54. 安装空间检查

安装前必须检查：

```text
install path
free space
```

不能只检查：

```text
/
```

如果：

```text
install_path=/mnt/sda/fcc
```

必须检查：

```text
/mnt/sda
```

所在 filesystem。

如果空间不足：

```text
Not enough storage space.
Required: XXX MB
Available: XXX MB
```

并阻止安装。

---

# 55. Runtime 与 LuCI 包分离

这是本项目的核心架构边界之一。

`luci-app-fcc` 必须保持为轻量级 LuCI 控制层；FCC Python/Node/uv/runtime/Agent 不属于 LuCI package 本体。

推荐：

```text
luci-app-fcc
```

负责：

```text
UI
Controller
Service
Runtime Manager
Session manager
```

Runtime：

```text
FCC Python
uv
Node
FCC
Agent
```

放到：

```text
/opt/fcc
```

或者用户指定路径。

这样 `.ipk/.apk` 不会因为 FCC runtime 过大而难以维护。

---

# 56. Package 架构

`luci-app-fcc` 应尽可能保持：

```text
PKGARCH:=all
```

因为 LuCI 控制层本身应是架构无关的。

但是：

```text
FCC Runtime
Node.js
Python
Agent binaries
```

可能具有架构相关性，必须独立处理，不能通过把 runtime 塞进 LuCI package 来“解决”架构问题。



推荐目录：

```text
luci-app-fcc/
├── Makefile
├── VERSION
├── README.md
├── DESIGN_SPEC.md
├── LICENSE
│
├── luasrc/
│   ├── controller/
│   │   └── fcc.lua
│   ├── model/
│   │   └── cbi/
│   │       └── fcc/
│   └── view/
│       └── fcc/
│           ├── console.htm
│           ├── config.htm
│           └── info.htm
│
├── htdocs/
│   └── luci-static/
│       └── resources/
│           └── fcc/
│               ├── xterm.js
│               ├── xterm.css
│               └── fcc-terminal.js
│
├── root/
│   ├── etc/
│   │   ├── config/
│   │   │   └── fcc
│   │   └── init.d/
│   │       └── fcc
│   │
│   ├── usr/
│   │   ├── bin/
│   │   │   └── fcc-env
│   │   └── libexec/
│   │       └── fcc/
│   │           ├── common.sh
│   │           ├── install.sh
│   │           ├── update.sh
│   │           ├── status.sh
│   │           ├── agent.sh
│   │           ├── session.sh
│   │           └── terminal.sh
│   │
│   └── usr/share/
│       ├── rpcd/acl.d/
│       │   └── luci-app-fcc.json
│       └── luci-app-fcc/
│           └── VERSION
│
├── po/
│   ├── templates/
│   │   └── fcc.pot
│   └── zh_Hans/
│       └── fcc.po
│
├── scripts/
│   ├── build-runtime.sh
│   ├── package-check.sh
│   └── test.sh
│
├── tests/
│   ├── test_lua.sh
│   ├── test_shell.sh
│   ├── test_packaging.sh
│   ├── test_security.sh
│   └── test_runtime.sh
│
└── .github/
    └── workflows/
        ├── build-openwrt-24.10.yml
        ├── build-openwrt-25.12.yml
        └── release.yml
```

实际文件可以根据 implementation 优化，但职责不能混乱。

---

# 57. Makefile

必须兼容 OpenWrt 24.10 / 25.12。

推荐显式 Package 定义，不依赖旧 LuCI feed 的隐式行为。

基本：

```make
include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-fcc
PKG_VERSION:=$(strip $(shell cat $(CURDIR)/VERSION))
PKG_RELEASE:=1

PKG_LICENSE:=GPL-3.0

include $(INCLUDE_DIR)/package.mk

define Package/luci-app-fcc
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=FCC AI Coding Agent Manager
  PKGARCH:=all
endef

define Package/luci-app-fcc/description
FCC Web Terminal, FCC Server Manager and Runtime Monitor
for OpenWrt / ImmortalWrt.
endef

...
$(eval $(call BuildPackage,luci-app-fcc))
```

依赖必须根据最终实际代码确定。

---

# 58. OpenWrt 24.10

必须生成：

```text
.ipk
```

例如：

```text
luci-app-fcc_0.1.0-1_all.ipk
```

CI 必须使用对应 OpenWrt 24.10 SDK / buildroot。

---

# 59. OpenWrt 25.12

必须生成：

```text
.apk
```

例如：

```text
luci-app-fcc-0.1.0-r1.apk
```

CI 必须使用对应 OpenWrt 25.12 SDK / buildroot。

**禁止把 IPK 改名为 APK。**

---

# 60. ImmortalWrt

不要为每一个 ImmortalWrt 固定版本写死代码。

支持：

```text
ImmortalWrt buildroot
```

如果 package ABI/API 兼容：

```text
package/luci-app-fcc
```

应能直接参与 ImmortalWrt build。

如果 ImmortalWrt 的 package manager / LuCI API 有差异，在 CI 中单独测试。

---

# 61. CI Matrix

第一阶段：

```text
OpenWrt 24.10
  x86_64
  aarch64

OpenWrt 25.12
  x86_64
  aarch64
```

建议 matrix：

```yaml
os:
  - openwrt-24.10
  - openwrt-25.12

arch:
  - x86_64
  - aarch64
```

LuCI package 是：

```text
PKGARCH=all
```

所以最终 package 本身通常不需要针对 CPU 编译。

Runtime 则必须架构相关。

---

# 62. GitHub Release

Tag：

```text
v0.1.0
```

自动 Release：

```text
luci-app-fcc_0.1.0-1_all.ipk
luci-app-fcc-0.1.0-r1.apk
```

Runtime：

```text
fcc-runtime-openwrt-24.10-x86_64.tar.gz
fcc-runtime-openwrt-24.10-aarch64.tar.gz
fcc-runtime-openwrt-25.12-x86_64.tar.gz
fcc-runtime-openwrt-25.12-aarch64.tar.gz
```

如果 Runtime 最终采用在线安装而不是预构建，则 Release 只发布 LuCI package 和 installer metadata。

---

# 63. Runtime 构建策略

优先设计：

```text
luci-app-fcc
       |
       +---- Runtime Installer
                 |
                 +---- Python
                 +---- uv
                 +---- FCC
                 +---- Node
                 +---- Agents
```

不要让：

```text
make package/luci-app-fcc/compile
```

每次都重新编译整个 FCC runtime。

这样 CI 快很多，package 也干净。

---

# 64. 当前 FCC 版本信息

设计时不要假定固定版本。

在本设计编写时，上游 `free-claude-code` 的 `pyproject.toml` 显示版本为：

```text
6.2.53
```

但这是**设计时参考值，不得写死进代码**。

运行时必须动态读取。

---

# 65. 上游 Agent 事实来源

当前上游 `pyproject.toml` 定义的 console scripts 包括：

```text
fcc-server
fcc-claude
fcc-codex
fcc-pi
fcc-opencode
fcc-cline
fcc-hermes
fcc-dsh
fcc-grok
fcc-muse
fcc-aider
```

因此 UI：

```text
DeepSeek Harness
```

内部使用：

```text
dsh
```

而不是错误地假设：

```text
fcc-deepseek
```

UI 名称与实际 executable 必须解耦。

---

# 66. 当前上游安装器

上游 installer 当前会处理多个 Agent，并定义：

```text
fcc-server
fcc-claude
fcc-codex
fcc-pi
fcc-opencode
fcc-cline
fcc-hermes
fcc-dsh
fcc-grok
fcc-muse
fcc-aider
```

OpenWrt Runtime Manager 可以复用上游安装器的逻辑思路，但不能直接：

```text
curl | sh
```

作为 LuCI 后端安装机制。

---

# 67. 依赖兼容性

FCC 当前 Python dependencies 较多。

必须实际测试：

```text
Python
FastAPI
uvicorn
httpx
pydantic
openai
grpc
aiohttp
...
```

在：

```text
OpenWrt musl
```

上的兼容性。

如果某个 Python wheel 没有 musl/aarch64：

1. 优先选择可用的纯 Python package。
2. 如果需要 native extension，评估交叉编译。
3. 如果 FCC 某 optional dependency 不需要，禁用 optional feature。
4. 不要为了一个 voice feature 把巨大的 ML runtime 强制加入。

---

# 68. Voice / GPU

第一版明确：

```text
voice_local
PyTorch GPU
CUDA
```

不属于核心功能。

如果上游 FCC 有 optional voice dependencies：

```text
grpcio
grpcio-tools
nvidia-riva-client
torch
transformers
accelerate
librosa
```

默认不要安装。

目标是：

```text
FCC proxy
Coding Agents
Web Terminal
```

先稳定。

---

# 69. OpenCode 注意事项

上游当前文档已经区分 OpenCode 版本行为。

实现时必须：

```text
fcc-opencode
```

而不是直接：

```text
opencode
```

FCC 官方文档明确说明：

```text
fcc-opencode
```

用于 coding/session；

普通：

```text
opencode
```

用于升级、service management、ACP、MCP setup 等场景。

因此 Web Terminal 中必须调用 FCC launcher。

---

# 70. Aider 注意事项

Web Console 选择：

```text
Aider
```

调用：

```text
fcc-aider
```

而不是：

```text
aider
```

这样才能通过 FCC 提供的模型/proxy。

---

# 71. DeepSeek Harness

UI：

```text
DeepSeek Harness
```

内部：

```text
fcc-dsh
```

不要创建：

```text
fcc-deepseek
```

假 executable。

---

# 72. Agent 可用性

如果 Agent executable 不存在：

```text
○ Not Installed
```

并提供：

```text
[Install]
```

安装完成：

```text
● Installed
```

启动后：

```text
● Running
```

退出后：

```text
○ Stopped
```

异常：

```text
⚠ Error
```

---

# 73. Error 状态

状态 API 必须能够返回：

```json
{
  "running": false,
  "installed": true,
  "error": {
    "code": "START_FAILED",
    "message": "fcc-codex exited with status 1"
  }
}
```

UI：

```text
Codex
⚠ Error

[View Log]
[Retry]
```

不要只显示：

```text
Stopped
```

导致用户不知道发生了什么。

---

# 74. Web Terminal 错误

如果 WebSocket 断开：

```text
Terminal connection lost.
Session is still running.
[Reconnect]
```

如果 session 已经结束：

```text
Session has exited.
Exit code: 0
[Start New Session]
```

如果 Agent crash：

```text
Agent exited unexpectedly.
[View Log]
[Restart]
```

---

# 75. Browser reconnect

页面刷新：

```text
window reload
```

不应该自动启动第二个：

```text
fcc-claude
```

而应该：

```text
list sessions
↓
find existing session
↓
connect
```

避免：

```text
Claude Code × 10
```

这种 session 泄漏。

---

# 76. Session 清理

Runtime Manager 定期检查：

```text
dead session
orphan tmux session
```

提供：

```text
fcc-env session cleanup
```

但不能自动杀掉未知用户创建的 tmux session。

只处理：

```text
fcc-*
```

命名空间。

---

# 77. Logs

所有操作：

```text
install
update
start
stop
agent install
agent start
agent stop
session create
session close
```

都必须记录。

敏感信息：

```text
API Key
Proxy token
Cookie
Authorization
```

必须脱敏。

---

# 78. Config Backup

FCC 更新前：

```text
backup
```

更新后：

```text
verify
```

如果失败：

```text
rollback
```

至少保留：

```text
last successful backup
```

---

# 79. Rollback

如果更新：

```text
download OK
install OK
server start FAILED
```

自动：

```text
stop
restore previous runtime
restore config
start
health check
```

最终：

```text
Update failed. Previous FCC version restored.
```

如果 rollback 失败：

```text
FCC Server remains stopped.
Please inspect logs.
```

但：

```text
Luci-FCC
```

必须仍然可以打开。

---

# 80. Doctor

实现：

```bash
fcc-env doctor
```

检查：

```text
Architecture
Kernel
OpenWrt version
Storage
Memory
Python
Node
uv
FCC
FCC Server
Port 8082
Agent executables
tmux
Permissions
DNS
HTTPS download
```

输出：

```text
[OK] Architecture
[OK] Storage
[OK] Python
[OK] FCC
[OK] fcc-server
[OK] tmux
[WARN] Codex not installed
```

LuCI 可提供：

```text
[Run Diagnostics]
```

---

# 81. Installation State

不要仅依赖：

```text
UCI enabled=1
```

维护：

```text
runtime metadata
```

例如：

```text
<install_path>/runtime.json
```

包含：

```json
{
  "fcc_version": "6.2.x",
  "python_version": "3.14.x",
  "node_version": "22.x",
  "installed_at": "...",
  "updated_at": "...",
  "agents": {
    "claude": true,
    "codex": true
  }
}
```

该文件不是唯一事实来源；实际 executable 检测优先。

---

# 82. First-run

安装 LuCI package 后：

```text
不要自动下载巨大 Runtime
```

第一次进入 FCC：

```text
Runtime not installed
```

用户主动：

```text
[Install FCC Runtime]
```

这样避免：

```text
apk/opkg install luci-app-fcc
```

突然下载几百 MB。

---

# 83. Uninstall

LuCI 卸载：

```text
luci-app-fcc
```

不应该默认删除：

```text
/opt/fcc/data
```

因为用户可能重新安装。

卸载 UI：

```text
Remove Luci-FCC only
```

另提供：

```text
Remove FCC Runtime
```

明确二次确认：

```text
This will remove FCC, Agents, cache and runtime data.
Continue?
```

---

# 84. Data preservation

默认保留：

```text
data
backup
```

如果用户选择：

```text
Remove all FCC data
```

才删除。

---

# 85. UI 风格

参考 LuCI 原生风格。

不要做一个完全脱离 LuCI 的 SPA。

允许：

```text
LuCI tabs
LuCI forms
LuCI status tables
LuCI modal
```

Terminal 区域使用：

```text
xterm.js
```

这样和 OpenWrt LuCI 风格一致。

---

# 86. 页面响应式

Terminal：

```text
width: 100%
height: calc(...)
```

支持：

```text
Desktop
Tablet
Mobile
```

移动端至少能：

```text
select Agent
connect
send text
disconnect
```

---

# 87. 不允许的设计

以下规则是硬性禁止项：

禁止：

```text
把 API Key 写入 UCI
```

禁止：

```text
把 Python / Node.js / npm / uv 作为 luci-app-fcc 的强制运行时依赖
```

禁止：

```text
为了 LuCI 页面引入 React / Vue / Svelte / Angular / Tailwind / Bootstrap 等大型前端 Framework
```

禁止：

```text
为了 Web Terminal 引入独立 Node.js/Python WebSocket Server
```

禁止：

```text
让 luci-app-fcc 启动一个常驻 Python/Node.js daemon 来提供普通 LuCI API
```

禁止：

```text
使用数据库或 Redis 保存 LuCI-FCC 的普通状态
```

禁止：

```text
高频轮询系统状态，例如 100 ms 级别持续刷新
```

禁止：

```text
每个 Agent 状态查询都单独 fork 一个 ps/grep/df shell pipeline
```

禁止：

```text
无 FCC Runtime 时让 LuCI-FCC 页面直接报错或无法打开
```

禁止：

```text
把所有 runtime 放进 LuCI package
```

禁止：

```text
每次打开 Web Console 都重新启动 Agent
```

禁止：

```text
关闭浏览器就杀 Agent
```

禁止：

```text
fcc-server 与 Agent 使用同一个生命周期
```

禁止：

```text
Controller 直接执行任意用户 shell
```

禁止：

```text
IPK 改名 APK
```

禁止：

```text
把所有 runtime 放进 LuCI package
```

禁止：

```text
硬编码 FCC 当前版本
```

禁止：

```text
硬编码某个 Agent 的版本
```

禁止：

```text
默认向 WAN 开放 8082
```

---

# 88. 测试

必须至少实现：

## Lua

```text
controller syntax
route registration
ACL
```

## Shell

```text
shellcheck
```

如果系统没有 shellcheck：

```text
skip with warning
```

但 CI 环境应该安装。

## Security

测试：

```text
command injection
path traversal
invalid agent
invalid session
invalid update URL
```

例如：

```text
agent=claude;reboot
```

必须失败。

```text
agent=../../etc/passwd
```

必须失败。

---

# 89. Packaging Test

必须检查最终 package 包含：

```text
/etc/config/fcc
/etc/init.d/fcc
/usr/bin/fcc-env
controller
views
ACL
VERSION
static assets
```

参考 `luci-app-openclaw` 的 package parity 思路，建立：

```text
tests/test_packaging.sh
```

确保：

```text
Makefile
local build
CI build
```

使用一致的安装清单。

---

# 90. OpenWrt 24.10 CI

CI 必须实际运行：

```text
OpenWrt 24.10 SDK
```

至少验证：

```text
make package/luci-app-fcc/compile V=s
```

产出：

```text
*.ipk
```

安装测试：

```bash
opkg install luci-app-fcc*.ipk
```

然后：

```bash
/etc/init.d/fcc status
```

---

# 91. OpenWrt 25.12 CI

使用：

```text
OpenWrt 25.12 build environment
```

产出：

```text
*.apk
```

安装测试：

```bash
apk add ./luci-app-fcc*.apk
```

然后：

```bash
/etc/init.d/fcc status
```

不能假设 24.10 的安装/卸载脚本完全适用于 25.12。

---

# 92. CI Matrix

至少：

```yaml
openwrt:
  - "24.10"
  - "25.12"

arch:
  - x86_64
  - aarch64
```

另外：

```text
LuCI package:
PKGARCH=all
```

因此 package 本身应尽可能 architecture-independent。

Runtime artifacts：

```text
architecture-specific
```

---

# 93. Release

Tag：

```text
v0.1.0
```

GitHub Release 至少：

```text
luci-app-fcc_0.1.0-1_all.ipk
luci-app-fcc-0.1.0-r1.apk
```

以及 Runtime artifacts（如果采用预构建 runtime）。

Release notes 自动包含：

```text
Luci-FCC version
supported OpenWrt versions
supported architectures
FCC tested version
agent support
known limitations
```

---

# 94. README 必须说明

用户安装：

```text
opkg install luci-app-fcc*.ipk
```

或：

```text
apk add ./luci-app-fcc*.apk
```

然后：

```text
LuCI
 -> Services
 -> FCC
```

第一次：

```text
Install FCC Runtime
```

配置：

```text
Configuration
 -> Open FCC Admin
```

使用：

```text
Web Console
 -> Select Agent
 -> Start
```

监控：

```text
Basic Information
```

更新：

```text
Basic Information
 -> Check Update
 -> Update FCC
```

---

# 95. 开发阶段划分

## Phase 1 — LuCI skeleton

完成：

```text
Makefile
UCI
init.d
controller
ACL
three tabs
i18n
VERSION
```

## Phase 2 — FCC Runtime

完成：

```text
fcc-env
install
status
version
start
stop
```

## Phase 3 — FCC Server

完成：

```text
server lifecycle
port detection
admin link
health check
```

## Phase 4 — Terminal

完成：

```text
xterm.js
WebSocket
PTY
tmux
session
reconnect
```

## Phase 5 — Agents

完成：

```text
Claude
Codex
Pi
OpenCode
Cline
Hermes
DSH
Grok
Muse
Aider
```

## Phase 6 — Monitor

完成：

```text
version
PID
uptime
RSS
system memory
storage
```

## Phase 7 — Update

完成：

```text
check
download
verify
backup
update
health check
rollback
```

## Phase 8 — CI

完成：

```text
24.10 IPK
25.12 APK
x86_64
aarch64
GitHub Release
```

---

# 96. MVP 验收标准

第一版必须做到：

### Web Console

- [ ] Agent dropdown
- [ ] Claude Code
- [ ] Codex
- [ ] Pi
- [ ] OpenCode
- [ ] Cline
- [ ] Hermes
- [ ] DeepSeek Harness
- [ ] Grok Build
- [ ] Muse Code
- [ ] Aider
- [ ] Start
- [ ] Connect
- [ ] Close
- [ ] Real interactive terminal
- [ ] xterm.js
- [ ] WebSocket
- [ ] PTY
- [ ] Session reconnect

### FCC Server

- [ ] Start
- [ ] Stop
- [ ] Restart
- [ ] Status
- [ ] Version
- [ ] PID
- [ ] Uptime
- [ ] Memory
- [ ] Port
- [ ] Open Admin

### Runtime Monitor

- [ ] Luci-FCC version
- [ ] FCC version
- [ ] FCC Server version
- [ ] Agent versions
- [ ] Agent status
- [ ] Agent PID
- [ ] Agent uptime
- [ ] Agent memory
- [ ] System memory
- [ ] Storage
- [ ] Update check
- [ ] FCC update

### Compatibility

- [ ] OpenWrt 24.10
- [ ] OpenWrt 25.12
- [ ] IPK
- [ ] APK
- [ ] x86_64
- [ ] aarch64
- [ ] English
- [ ] Simplified Chinese

---

# 97. Final Architecture

```text
                         OpenWrt / ImmortalWrt
                                  |
                           +------+------+
                           | luci-app-fcc |
                           +------+------+
                                  |
              +-------------------+-------------------+
              |                   |                   |
              v                   v                   v
       Web Console          FCC Server Manager    Runtime Monitor
              |                   |                   |
           xterm.js          start/stop/restart     versions
              |                   |                   |
          WebSocket           fcc-server              PID
              |                   |                   |
          PTY/tmux             :8082                  uptime
              |                   |                   |
              |              /admin                   memory
              |                   |                   |
              |                   v                   storage
              |             FCC Admin                 update
              |
     +--------+---------+
     |        |         |
   Claude   Codex      Pi
     |
 OpenCode
 Cline
 Hermes
 DSH
 Grok
 Muse
 Aider
```

---

# 98. 最终职责边界

```text
luci-app-fcc
│
├── UI
│
├── Authentication / ACL
│
├── Web Terminal
│
├── Session Manager
│
├── FCC Server Manager
│
├── Runtime Monitor
│
├── Runtime Installer
│
└── FCC Updater
```

FCC：

```text
free-claude-code
│
├── fcc-server
├── fcc-claude
├── fcc-codex
├── fcc-pi
├── fcc-opencode
├── fcc-cline
├── fcc-hermes
├── fcc-dsh
├── fcc-grok
├── fcc-muse
└── fcc-aider
```

FCC Admin：

```text
Provider
API Key
Model
Proxy Authentication
FCC configuration
```

三者不要互相重复实现。

---

# 99. Claude Code 开始执行时的第一步

进入仓库后，首先执行：

```bash
pwd
git status
find . -maxdepth 2 -type f | sort
```

然后检查上游：

```bash
git ls-remote https://github.com/Alishahryar1/free-claude-code.git HEAD
git ls-remote https://github.com/10000ge10000/luci-app-openclaw.git HEAD
```

如果网络允许，下载/检查当前源码。

然后：

```text
1. 分析当前仓库
2. 分析 upstream FCC
3. 分析 luci-app-openclaw
4. 输出 implementation checklist
5. 创建项目骨架
6. 实现 LuCI
7. 实现 Runtime Manager
8. 实现 FCC Server Manager
9. 实现 Terminal/session
10. 实现 Monitor
11. 实现 Update
12. 实现 i18n
13. 实现 tests
14. 实现 OpenWrt 24.10 CI
15. 实现 OpenWrt 25.12 CI
16. 本地构建验证
17. 修复所有 build/test errors
18. 更新 README
```

不要在分析完成后停下来等待确认；按照本文件继续执行。

---

# 100. 完成定义

当以下全部成立时，项目才算完成：

```text
[✓] LuCI 可以安装
[✓] Services -> FCC 可以打开
[✓] 三个 Tab 正常
[✓] 中英文正常
[✓] FCC Runtime 可以安装
[✓] FCC Server 可以启动
[✓] FCC Admin 可以打开
[✓] Claude Code 可以从浏览器启动
[✓] Codex 可以从浏览器启动
[✓] Pi 可以从浏览器启动
[✓] OpenCode 可以从浏览器启动
[✓] 其它已安装 Agent 可以从浏览器启动
[✓] Terminal 可以交互
[✓] Session 可以 reconnect
[✓] Agent 可以关闭
[✓] Server 可以 stop/start/restart
[✓] Luci-FCC version 正确
[✓] FCC version 正确
[✓] Agent versions 正确
[✓] PID 正确
[✓] Uptime 正确
[✓] RSS memory 正确
[✓] System memory 正确
[✓] Storage 正确
[✓] FCC update 可用
[✓] update failure 有保护
[✓] API Key 不进入 UCI
[✓] 无任意命令执行漏洞
[✓] OpenWrt 24.10 IPK 构建成功
[✓] OpenWrt 25.12 APK 构建成功
[✓] x86_64 构建成功
[✓] aarch64 构建成功
[✓] GitHub Actions 成功
```

---

# 101. 上游参考

实现过程中以以下仓库当前版本为事实来源：

1. Free Claude Code:
   https://github.com/Alishahryar1/free-claude-code

2. Free Claude Code `pyproject.toml`:
   https://github.com/Alishahryar1/free-claude-code/blob/main/pyproject.toml

3. Free Claude Code installer:
   https://github.com/Alishahryar1/free-claude-code/blob/main/scripts/install.sh

4. Free Claude Code README:
   https://github.com/Alishahryar1/free-claude-code/blob/main/README.md
   
5. Claude Code README:
   https://github.com/anthropics/claude-code/blob/main/README.md

6. LuCI OpenClaw reference:
   https://github.com/10000ge10000/luci-app-openclaw

7. LuCI OpenClaw Makefile:
   https://github.com/10000ge10000/luci-app-openclaw/blob/main/Makefile

8. LuCI OpenClaw README:
   https://github.com/10000ge10000/luci-app-openclaw/blob/main/README.md

---

# 102. 当前上游事实备注

设计时检查到的 FCC 当前源码信息：

- FCC 当前 package version 在 `pyproject.toml` 中为 `6.2.53`；该数字仅作为本设计生成时的参考，代码不得硬编码。
- 当前 `pyproject.toml` 的 Python requirement 为 `>=3.14.0`。
- 当前 console scripts 包含：
  `fcc-server`、`fcc-claude`、`fcc-codex`、`fcc-pi`、`fcc-opencode`、`fcc-cline`、`fcc-hermes`、`fcc-dsh`、`fcc-grok`、`fcc-muse`、`fcc-aider`。
- FCC 当前 README 使用 `fcc-claude`、`fcc-codex`、`fcc-pi`、`fcc-opencode`、`fcc-cline`、`fcc-hermes`、`fcc-dsh`、`fcc-grok`、`fcc-muse`、`fcc-aider` 启动对应 Agent。
- OpenClaw LuCI 项目目前已经包含 Web Console、Web PTY、状态 API、自定义 install path、runtime 管理和 package parity 测试等值得参考的实现。

这些信息必须在真正开发时重新从 upstream 检查，以避免 upstream 在开发期间发生变化。

---

# 103. 给 Claude Code 的最终指令

**现在开始实施本设计。**

不要只回答“可以实现”。

直接：

```text
分析当前仓库
↓
创建/修改文件
↓
实现代码
↓
运行测试
↓
运行 package build
↓
修复错误
↓
生成 CI
↓
更新 README
↓
最终报告
```

最终报告必须包含：

```text
1. 已创建/修改的文件
2. Web Console 实现方式
3. Session/PTY 实现方式
4. FCC Server 实现方式
5. Runtime 安装方式
6. FCC Update 实现方式
7. Memory Monitor 实现方式
8. Security 处理
9. OpenWrt 24.10 build result
10. OpenWrt 25.12 build result
11. x86_64 result
12. aarch64 result
13. 已知限制
14. 后续建议
```

**如果某项功能因 OpenWrt / FCC 当前版本技术限制无法实现，不要伪造“已完成”；明确指出具体原因，并提供实际可运行的替代实现。**

