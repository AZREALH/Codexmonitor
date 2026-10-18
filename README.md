# Codex Monitor

一个用于查看 Codex 订阅额度的 macOS 菜单栏面板原型。首版计划支持启动读取、手动刷新和退出；不实现自动监测。

项目已完成 Task1.1 环境验证、Task1.2 应用壳和 Task1.3 菜单栏面板。Task2.2 示例额度面板已通过布局、滚动及刷新人工验收，尚未连接 Codex。需求、设计及任务见 [proposal.md](proposal.md)、[design.md](design.md)、[task.md](task.md)。

## 开发环境

2026-10-18 在当前 Mac 实际检查：

| 项目 | 实测结果 |
|---|---|
| 系统 | macOS 27.0.1，Build 26A434 |
| 架构 | arm64（Apple Silicon） |
| 开发工具目录 | `/Applications/Xcode.app/Contents/Developer` |
| Xcode | 27.1，Build 27A9275 |
| Apple Swift | 6.4，swiftlang-6.4.0.34.1 |
| macOS SDK | 27.0 |
| Swift Package Manager | Swift 6.4.0-dev |

检查命令：

```sh
sw_vers
uname -m
xcode-select -p
xcodebuild -version
swift --version
xcrun --sdk macosx --show-sdk-version
swift package --version
```

当前所需工具已存在，本任务未安装软件或修改系统开发工具配置。只确认当前系统可用，尚未验证更低系统版本。

## 构建路径

首版选择 **Swift Package Manager 可执行工程 + SwiftUI / AppKit**，不引入第三方依赖或工程生成工具。已建立 `Package.swift`、源码和 XCTest 测试入口；Task5.1 再生成本机可启动的 `.app`。当前部署配置为 macOS 27.0，实际仅在 27.0.1 验证。

在当前项目目录的普通终端中运行：

```sh
swift build
swift test
swift run CodexMonitor
```

启动后屏幕上方菜单栏出现仪表盘图标，悬停显示“Codex Monitor”。点击展开示例额度面板，顶部可切换正常、缺失字段、空列表及长列表。点击“刷新”只更新示例时间和底部计数；点击外部或再次点击图标收起，应用继续运行。点击面板内“退出”结束应用。不显示 Dock 图标或独立桌面窗口，不支持拖动。

本机临时预览包位于 `.build/Preview/CodexMonitor.app`，可用 `open .build/Preview/CodexMonitor.app` 打开；这是当前验证产物，干净克隆后尚无一键打包步骤，正式构建交付留待 Task5.1。

受限代理环境下，需将 SwiftPM 与编译器缓存放到允许写入的位置。本次临时工程验证使用：

```sh
# task_pkg 指向包含 Package.swift 的临时验证工程，不是当前仓库。
CLANG_MODULE_CACHE_PATH="$task_pkg/module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$task_pkg/module-cache" \
swift build --package-path "$task_pkg" --disable-sandbox \
  --cache-path "$task_pkg/cache" \
  --config-path "$task_pkg/config" \
  --security-path "$task_pkg/security"
"$task_pkg/.build/debug/EnvironmentCheck"
```

`--disable-sandbox` 仅用于避免当前受限代理环境中的 SwiftPM 嵌套沙箱冲突，不是普通终端构建的默认要求，也不改变代理本身的权限。

## Task1.1 验证结果

| 检查 | 实际结果 |
|---|---|
| 最小 Swift 程序编译与执行 | 通过；导入 SwiftUI、AppKit，创建 `NSHostingView<Text>`，输出 `SwiftUI + AppKit OK; host: NSHostingView<Text>`，退出码 0 |
| 最小 SwiftPM 可执行工程 | 通过；临时工程无第三方依赖，构建完成，输出 `Codex Monitor: SwiftPM build and run OK`，退出码 0 |
| 默认缓存路径限制 | 初次 SwiftPM 构建因用户目录缓存写入受限失败；重定向缓存后通过 |
| 工具诊断 | 出现文件事件、缓存和嵌套沙箱相关警告；未阻止最终编译和运行，不据此推断 GUI 行为已验证 |

验证源码与产物位于 `/private/tmp`，未作为项目正式源码提交。临时 manifest 使用的部署版本仅用于编译探测，不代表项目兼容承诺。

## Task1.2 验证结果

- 工程构建通过；XCTest 执行 1 项测试，0 失败：实际创建窗口、重复显示复用相同窗口、占位标题和内容存在、关闭最后窗口的退出策略生效。
- 真实应用连续启动两次，分别通过 `--smoke-test` 检查只有一个可见窗口，再调用标准 `NSApplication.terminate` 退出，两次退出码均为 0。每个进程均已由测试等待回收。
- 自动启动检查命令：`swift run CodexMonitor --smoke-test`。此参数只验证应用壳，会显示后自动退出；日常查看窗口不要加此参数。
- 受限代理内使用上一节的缓存重定向参数执行 `swift test`，构建及测试通过。完整 GUI 启动在受限环境中超过 15 秒，测试已结束该子进程；在允许访问桌面会话的环境中两次启动退出均成功。
- 本次没有连接 Codex、创建额度缓存或安装应用。窗口可见性由实际 AppKit 状态检查，尚未进行人工视觉审查或桌面层级验证。

## Task1.3 菜单栏面板验证记录

用户在桌面版排查后提出改为类似系统电池的交互，项目已切换方向：菜单栏图标加点击展开面板，停止桌面层级和拖动实现。

- `MenuBarPanel.swift` 使用 `NSStatusItem` 和 `NSPopover`；点击图标切换展开／收起，点击外部自动收起；不显示 Dock 图标。
- XCTest 在实际桌面会话中执行 1 项，0 失败；验证初始收起状态和两次展开／收起。必须初始化测试应用并等待系统布局，不能仅凭测试进程退出码判断通过。
- 实际 `CodexMonitor --smoke-test` 检查菜单栏展开、收起及标准退出，输出 `SMOKE PASS: menu bar popover opened and closed; terminating normally`，退出码 0。
- 首次启动检查发现图标尚未完成系统布局，已让检查延迟 0.3 秒后执行；正常运行不受此检查参数影响。
- 最新预览通过 macOS 正常应用启动方式运行；用户于 2026-10-18 确认“打开、按钮和收起都正常”，核心交互通过人工验收，Task1.3 已完成。退出流程由自动启动检查验证，不声称另有人工退出验证。
- 旧桌面版虽曾通过窗口配置测试，用户反馈可点击但不能拖动，因此未通过桌面验收；这些测试已由当前菜单栏行为测试替换。

以上为 Task1.3 当时的验证记录。当前已在 Task3.1 验证 Codex 路径和真实读取，菜单栏界面已由 Task2.2 替换为示例额度面板。

Task2.1 已完成数据与计算规则；Task2.2 展示面板随后完成。Task3.1 验证真实读取，界面尚未接入。

### 菜单栏面板收起修正（待复验）

用户补充反馈：点击外部收起不及时，点击其他菜单栏组件不能收起。系统 transient 行为不保证覆盖菜单和所有面板，参见 [Apple 说明](https://developer.apple.com/de/documentation/appkit/nspopover/behavior-swift.enum/transient)。

修复版在面板展开期间监听本应用及其他应用的鼠标按下事件，外部点击时关闭；内部按钮和自身菜单栏图标继续正常处理。面板关闭后移除监听，不记录点击内容，不监听键盘。构建及 1 项 XCTest 通过（重复关闭后可重新展开），实际启动检查通过；其他组件和外部点击的实际体验仍待用户复验。修改保留未暂存，确认后再暂存或提交。

### 图标再次点击收起修正（待复验）

用户确认外部收起已正常，随后反馈再次点击图标无法收起。修复版将系统 transient 自动关闭改为 applicationDefined，由图标和点击监听统一控制关闭，避免系统先关闭、图标回调再次打开的冲突。测试改为触发真实状态栏按钮 action，打开、重复关闭、再次打开及图标关闭均通过；实际启动检查通过。最新版已启动，等待用户复验图标连续点击、外部点击和内部按钮。代码保留必要注释，所有修改未暂存、未提交。

### 图标事件顺序修正（待复验）

用户复验后反馈图标仍无法关闭，上一轮不能判定修复完成。本轮让图标响应鼠标按下，并按屏幕坐标排除自身图标区域：即使菜单栏事件没有携带按钮窗口，也不会被外部监听提前关闭。测试新增“图标坐标经过监听 → 按钮 action → 收起”的回归路径，并验证真实外部坐标仍会关闭；测试及实际启动检查通过，预览已更新，等待物理点击复验。全部改动仍未暂存、未提交。

2026-10-18 最终复验：用户确认再次点击自身图标可收起，外部点击收起此前也已确认正常；本轮菜单栏修复已获提交授权。

## Task2.1 额度数据验证

新增 `QuotaSnapshot.swift`：`QuotaItem` 表达一行额度，`QuotaSnapshot` 保存一次查询结果，`ReadError` 提供固定错误说明和可选限流重试时刻。仅依赖 Foundation，不执行网络请求或改变面板。

剩余比例按 `max(0, 100 - usedPercent)` 计算；缺失、负数、NaN 和无穷大显示为未知，不当作满额或零额度。超过 100% 的已用值保留，剩余为零；缺失重置时刻不补造默认值。

2026-10-18 构建成功，新增 5 项数据测试与已有菜单栏回归共 6 项 XCTest 全部通过，0 失败。实现和测试已附简洁中文注释；本任务改动保留未暂存，等待用户确认。

## Task2.2 示例额度面板

- `PanelView.swift` 仅接收快照、示例标识和刷新／退出回调，显示名称、剩余比例、进度条、本地重置时刻及查询时刻；不创建子进程或读取额度。
- `ExamplePanelView.swift` 临时提供四种明确标注的示例场景：正常 75%／20%、未知字段、空列表和十条长名称额度。通过顶部分段按钮切换，长列表内部滚动。正式数据接入时替换演示容器。
- 旧 `PlaceholderView.swift` 已由上述视图替换；刷新只更新示例查询时间和刷新次数，退出调用应用退出入口。
- 构建成功，现有 6 项数据／菜单栏 XCTest 通过，实际启动展开收起检查通过。用户于 2026-10-18 确认“四种场景和刷新都正常”，布局、滚动与刷新人工验收通过；退出回调已接线，未单独记录用户退出验证。
- 新版已启动在菜单栏，所有 Task2.2 改动保留未暂存、未提交。

Task2.2 及单实例修复已提交为 `b77e4c2`。Task3.1 已完成真实读取验证，下一项为 Task3.2：解析协议消息帧。

## 重复菜单栏图标修正

原先只保证一个进程里创建一份菜单栏入口，重复运行可执行程序或不同预览入口仍可能各自显示图标。现新增 `SingleInstance.swift`，在创建应用和图标前获取同一用户临时目录中的非阻塞文件锁；已有实例时直接退出，锁无法建立则报错退出，不继续创建图标。空锁文件不删除，锁随文件描述符关闭／进程结束释放，避免文件仍存在就误判为正在运行。

验证：8 项 XCTest（含 2 项单实例测试）全部通过；真实进程持锁后连续启动另外 3 次均被拒绝，首实例仍运行；结束首实例后重新启动及展开收起检查成功。最新预览已正常启动。改动附必要中文注释，未暂存、未提交。

以后预览更新先退出已运行的本项目应用，再替换并启动；日常启动使用 `open .build/Preview/CodexMonitor.app`，不使用强制多开参数。

## Task3.1 本机只读协议验证

2026-10-18，通过已有订阅登录完成一次真实额度查询。查询来自临时探测进程，应用界面仍为示例数据。

| 项目 | 实测结果 |
|---|---|
| Codex 路径 | `/Users/shihanxi/.vscode-insiders/extensions/openai.chatgpt-26.1007.21434-darwin-arm64/bin/macos-aarch64/codex` |
| 版本 | `codex-cli 0.162.0-alpha.17.2` |
| 来源 | VS Code Insiders 的 Codex 扩展附带；扩展升级可能改变路径，不要求另装 CLI |
| 启动 | `codex app-server --listen stdio://`，临时目录作为工作目录，stderr 与 stdout 分离 |
| 传输 | 每行一条 JSON，换行分帧，响应按 id 匹配；本次忽略 2 条通知 |
| 认证 | `account/read` 返回账户类型 chatgpt，复用已有登录 |
| 额度 | 1 个额度桶，主／次窗口均有有效非负已用比例；周期分钟数和重置时间戳均为整数 |
| 时间 | 启动至额度读取共 2.622 秒，低于整次 20 秒截止时间 |
| 清理 | 本次 PID 51772 已回收，进程组另行检查无存活进程 |

### 已验证的最小消息顺序

依据 [OpenAI 官方 App Server 文档](https://learn.chatgpt.com/docs/app-server)，以下消息已在上述本机版本实际验证，不需要开启实验能力：

```json
{"id":1,"method":"initialize","params":{"clientInfo":{"name":"codex_monitor_probe","title":"Codex Monitor Probe","version":"0.1.0"}}}
{"method":"initialized","params":{}}
{"id":2,"method":"account/read","params":{"refreshToken":false}}
{"id":3,"method":"account/rateLimits/read","params":{}}
```

按顺序等待每个请求成功，初始化响应后发送 initialized，再检查订阅身份，再查询额度。没有调用登录／登出、Token 获取、thread/start、turn/start 或积分消费接口。应用不主动读取认证文件或强制刷新凭据；认证加载和网络认证由 Codex 自身完成。

本次额度响应包含 rateLimits 和 rateLimitsByLimitId，另有首版不用的 accountId、ordinaryUsageAllowed、rateLimitResetCredits、rateLimitUpsell。后续忽略未使用字段，不将账户标识或响应正文写入日志。

[字段示例](docs/fixtures/rate-limits.example.json) 仅保留所需结构，所有额度桶 ID、百分比、周期和时间均为人为构造，**不是实际账号额度或完整真实响应**。主／次窗口使用 usedPercent、windowDurationMins 和 resetsAt；多桶视图与兼容单桶视图不重复展示。

临时脚本位于 `/private/tmp/codex-monitor-task31.py`，少于 100 行，使用本机 Python 3.9 的 asyncio.wait_for 设置整次截止时间，结束后回收专用进程。未保存原始认证或额度响应；不维护第二套正式客户端。此次只验证成功路径，异常、分片及正式客户端由后续任务实现。

本任务文档及构造样例未暂存、未提交。
