#!/bin/bash
set -euo pipefail

# 从任意目录调用都构建同一个项目；构建缓存与产物均被 Git 忽略。
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
scratch_dir="$project_dir/.build/app-build"
app_path="$project_dir/build/CodexMonitor.app"
cd "$project_dir"

swift build --configuration release --scratch-path "$scratch_dir"
binary_dir="$(swift build --configuration release --scratch-path "$scratch_dir" --show-bin-path)"
mkdir -p "$project_dir/build"
stage_dir="$(mktemp -d "$project_dir/build/.app-stage.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
bundle_dir="$stage_dir/CodexMonitor.app"
mkdir -p "$bundle_dir/Contents/MacOS"
cp "$binary_dir/CodexMonitor" "$bundle_dir/Contents/MacOS/CodexMonitor"
chmod 755 "$bundle_dir/Contents/MacOS/CodexMonitor"

# LSUIElement 让 Finder 启动时也保持菜单栏应用，不显示 Dock 图标。
# 最低系统版本与 Package.swift 保持一致；当前仅交付本机架构。
cat > "$bundle_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>CodexMonitor</string>
    <key>CFBundleIdentifier</key><string>local.codexmonitor.app</string>
    <key>CFBundleName</key><string>Codex Monitor</string>
    <key>CFBundleDisplayName</key><string>Codex Monitor</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>27.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# 临时目录里完成校验与本机签名，再替换交付产物；不需要开发者证书。
plutil -lint "$bundle_dir/Contents/Info.plist"
codesign --force --sign - "$bundle_dir"
codesign --verify --strict "$bundle_dir"
rm -rf "$app_path"
mv "$bundle_dir" "$app_path"
printf 'Application: %s\n' "$app_path"
