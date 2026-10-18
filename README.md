# Codex Monitor

一个用于查看 Codex 订阅额度的 macOS 菜单栏面板原型。首版计划支持启动读取、手动刷新和退出；不实现自动监测。

项目已完成 Task1.1 环境验证、Task1.2 应用壳和 Task1.3 菜单栏面板。当前显示开发占位内容，尚未连接 Codex。需求、设计及任务见 [proposal.md](proposal.md)、[design.md](design.md)、[task.md](task.md)。

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

启动后屏幕上方菜单栏出现仪表盘图标，悬停显示“Codex Monitor”。点击展开占位面板，点击“检查交互”可增加次数；点击外部或再次点击图标收起，应用继续运行。点击面板内“退出”结束应用。不显示 Dock 图标或独立桌面窗口，不支持拖动。

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

Codex 路径和订阅额度读取仍未验证。占位面板的“检查交互”按钮用于当前原型验证，后续替换为额度面板功能。

下一步为 Task2.1：定义最小额度数据与比例计算规则，尚未开始。

### 菜单栏面板收起修正（待复验）

用户补充反馈：点击外部收起不及时，点击其他菜单栏组件不能收起。系统 transient 行为不保证覆盖菜单和所有面板，参见 [Apple 说明](https://developer.apple.com/de/documentation/appkit/nspopover/behavior-swift.enum/transient)。

修复版在面板展开期间监听本应用及其他应用的鼠标按下事件，外部点击时关闭；内部按钮和自身菜单栏图标继续正常处理。面板关闭后移除监听，不记录点击内容，不监听键盘。构建及 1 项 XCTest 通过（重复关闭后可重新展开），实际启动检查通过；其他组件和外部点击的实际体验仍待用户复验。修改保留未暂存，确认后再暂存或提交。

### 图标再次点击收起修正（待复验）

用户确认外部收起已正常，随后反馈再次点击图标无法收起。修复版将系统 transient 自动关闭改为 applicationDefined，由图标和点击监听统一控制关闭，避免系统先关闭、图标回调再次打开的冲突。测试改为触发真实状态栏按钮 action，打开、重复关闭、再次打开及图标关闭均通过；实际启动检查通过。最新版已启动，等待用户复验图标连续点击、外部点击和内部按钮。代码保留必要注释，所有修改未暂存、未提交。

### 图标事件顺序修正（待复验）

用户复验后反馈图标仍无法关闭，上一轮不能判定修复完成。本轮让图标响应鼠标按下，并按屏幕坐标排除自身图标区域：即使菜单栏事件没有携带按钮窗口，也不会被外部监听提前关闭。测试新增“图标坐标经过监听 → 按钮 action → 收起”的回归路径，并验证真实外部坐标仍会关闭；测试及实际启动检查通过，预览已更新，等待物理点击复验。全部改动仍未暂存、未提交。

2026-10-18 最终复验：用户确认再次点击自身图标可收起，外部点击收起此前也已确认正常；本轮菜单栏修复已获提交授权。
