# HoverTime Desktop Timer

HoverTime 是一款 macOS 桌面悬浮时间工具，支持时钟、倒计时和正计时。它会保持在桌面最上层，但不会占用太多注意力，适合写作、编程、演示、录屏、直播或全屏工作时使用。

[English README](README.md)

## 截图

![悬浮时钟](show/Screenshot%202026-06-20%20at%2012.38.21.png)

![倒计时控制](show/Screenshot%202026-06-20%20at%2012.38.36.png)

![外观设置](show/Screenshot%202026-06-20%20at%2012.38.42.png)

![提醒和 Dock 设置](show/Screenshot%202026-06-20%20at%2012.38.48.png)

![桌面计时工作流](show/Screenshot%202026-06-20%20at%2012.39.02.png)

## 功能

- macOS 桌面悬浮计时窗口
- 支持时钟、倒计时、正计时
- 可跨 Spaces 和全屏应用显示
- 更克制、低干扰的字体和配色
- 点击悬浮时间即可打开紧凑控制面板
- 支持拖动位置，并自动记住位置
- 可选点击穿透模式
- 全局秒数开关，三个模式统一生效
- 倒计时时间只能通过加减按钮选择，分钟按 5 分钟步进
- 字号按 5pt 为单位增减
- 可开启每隔 N 分钟的轻提醒脉冲
- 菜单栏控制，可选是否显示 Dock 图标
- 倒计时结束时支持 macOS 通知和提示音

## 为什么做它

很多计时器要么藏在菜单栏里，很容易被忽略；要么是一个完整窗口，会打断当前工作。HoverTime 的目标是做一个轻量、持久、安静的桌面叠层：你随时能看见它，但它不会抢走注意力。

适合这些场景：

- 专注工作和类 Pomodoro 计时
- 演讲或录课时显示倒计时
- 直播和屏幕录制
- 全屏应用中保持时钟可见
- 简单的正计时记录

## 构建

### 环境要求

- macOS 15 或更高版本
- Xcode 或 Apple Command Line Tools with Swift

### 使用 Xcode

1. 打开 `HoverTime.xcodeproj`
2. 选择 `HoverTime` scheme
3. 按 `Cmd+R` 运行

### 手动打包

这个项目也可以不依赖 `xcodebuild`，直接用 `swiftc` 编译到 app bundle。当前已验证的目标版本是 `arm64-apple-macosx15.0`。

## 项目结构

| 文件 | 作用 |
| --- | --- |
| `HoverTimeApp.swift` | 应用入口和 SwiftUI Scene |
| `AppDelegate.swift` | 悬浮窗口、Dock 显示、应用生命周期 |
| `FloatingPanel.swift` | 置顶透明 `NSPanel` |
| `TimerManager.swift` | 时钟、倒计时、正计时、提醒和持久化 |
| `ContentView.swift` | 悬浮时间显示和紧凑控制面板 |
| `SettingsView.swift` | 完整设置窗口 |
| `MenuBarView.swift` | 菜单栏操作 |

## Release

当前版本说明见 [RELEASE.md](RELEASE.md)。
