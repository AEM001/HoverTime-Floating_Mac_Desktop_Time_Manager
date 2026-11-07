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
- 透明背景，适合浅色壁纸的墨灰、石板灰、灰绿和雾蓝配色
- 可选实心字或透明字心的细描边，支持实时外观预览
- 悬浮窗口宽高随字号和时间长度一起缩放
- 点击悬浮时间即可打开紧凑控制面板
- 支持拖动位置，并自动记住位置
- 可选点击穿透模式
- 全局秒数开关，三个模式统一生效
- 倒计时时间只能通过加减按钮选择，分钟按 5 分钟步进
- 字号按 5pt 为单位增减
- 可开启每隔 N 分钟的轻提醒脉冲
- 菜单栏控制，可选是否显示 Dock 图标
- 倒计时结束时支持 macOS 通知和提示音，并自动恢复设定时长；开启 Auto-repeat 才会继续下一轮

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

执行 `zsh build-app.sh`，输出到 `dist/HoverTime.app`（macOS 15+，Apple silicon / Intel）。

### 远端交叉编译

当前构建使用 `ssh my` 的 `~/code/macos-cross-build`，按该目录及
`projects/HoverTime/README.zh-CN.md` 的说明操作。同步 `HoverTime/` 后运行
`./build.sh HoverTime`，再运行子项目的 `./package-app.sh`。
当前取回的 `dist/HoverTime.app` 为 ARM64 版本。

在本机运行 `bash Tests/run-regressions.sh`，会使用同一远端工具链编译回归测试，
再在本机验证倒计时、菜单对象稳定性、窗口缩放及界面渲染。测试使用独立设置并屏蔽系统通知。

### 基本操作

- 按住悬浮时间拖动；单击打开快速控制，再次单击收起。
- 在快速控制中直接切换模式，启动、暂停或重置计时。
- 重新显示会保留位置，菜单栏的 Recenter at Top 可找回窗口。
- 启用 Click-through 后窗口会忽略鼠标；在菜单栏取消勾选即可恢复拖动。
- 时钟设置中的 Time zone 可选择本地时间或 UTC−12:00 至 UTC+14:00（15 分钟步进）；时间与日期同步切换并自动保存。固定 UTC 偏移不随夏令时变化。

这个项目也可以不依赖 `xcodebuild`，直接用 `swiftc` 编译到 app bundle。当前已验证的目标版本是 `arm64-apple-macosx15.0`。

## 项目结构

| 文件 | 作用 |
| --- | --- |
| `HoverTimeApp.swift` | 应用入口和 SwiftUI Scene |
| `AppDelegate.swift` | 悬浮窗口、Dock 显示、应用生命周期 |
| `FloatingPanel.swift` | 置顶透明 `NSPanel` |
| `TimerManager.swift` | 时钟、倒计时、正计时、提醒和持久化 |
| `ContentView.swift` | 透明悬浮时间、字形描边与文字尺寸测量 |
| `CompactControlPanel.swift` | 临时快速控制面板 |
| `SettingsView.swift` | 完整设置窗口 |
| `MenuBarView.swift` | 原生菜单栏和稳定的 Mode 子菜单 |

## Release

当前版本说明见 [RELEASE.md](RELEASE.md)。


### 快速外观与背景适配

点击悬浮时间，在卡片式快捷面板中切换模式、颜色、字号和字体。新的 Harbor、Amber、Iris、Pine、Lagoon 使用成对的深浅色，默认搭配细描边及可关闭的保护底衬。

“Adaptive background” 是可选功能，首次打开会请求 macOS 屏幕录制权限；授权后可能需要重新启动。每 30 秒仅采样悬浮区域为 16×16 像素，排除本应用窗口，不保存图像。使用最近五分钟亮度中位数和切换缓冲阈值，至少间隔两分钟才变色；移动后重新学习。关闭功能时停止定时器，悬浮窗隐藏时跳过采样。权限不足或采样失败时保持固定配色，建议保留保护底衬。背景适配根据亮度选择配色的深浅版本，不逐帧追随背景。
