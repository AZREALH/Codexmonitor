# Codex Monitor

一个用于查看 Codex 订阅额度的 macOS 桌面面板原型。首版计划支持启动读取、手动刷新和退出；不实现自动监测。

项目目前仅完成 Task1.1 环境验证，尚无应用工程或可启动面板。需求、设计及任务见 [proposal.md](proposal.md)、[design.md](design.md)、[task.md](task.md)。

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

首版选择 **Swift Package Manager 可执行工程 + SwiftUI / AppKit**，不引入第三方依赖或工程生成工具。Task1.2 将创建 `Package.swift`、源码和测试入口；Task5.1 再生成本机可启动的 `.app`。

工程建立后，普通终端的预期构建命令为 `swift build`，测试命令为 `swift test`。当前仓库还没有 `Package.swift`，此处不是已可执行的项目启动说明；项目测试入口留待 Task1.2 验证。

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

下一步为 Task1.2：创建可运行应用壳。窗口显示、桌面层级、测试 target、Codex 路径与订阅额度读取均尚未验证；当前没有安装或启动额度监测应用。
