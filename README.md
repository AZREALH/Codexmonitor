# Codex Monitor

一个用于查看 Codex 订阅额度的 macOS 桌面面板原型。首版计划支持启动读取、手动刷新和退出；不实现自动监测。

项目已完成 Task1.1 环境验证和 Task1.2 应用壳。当前可以启动一个普通占位窗口，尚未连接 Codex，也未设置桌面层级。需求、设计及任务见 [proposal.md](proposal.md)、[design.md](design.md)、[task.md](task.md)。

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

窗口显示“开发占位”，没有额度数据。通过应用菜单“退出 Codex Monitor”、Command-Q 或关闭最后一个窗口退出。此阶段仍使用命令启动，不是双击 `.app`。

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

下一步为 Task1.3：实现并验证仅桌面可见的窗口行为。Codex 路径与订阅额度读取仍未验证。
