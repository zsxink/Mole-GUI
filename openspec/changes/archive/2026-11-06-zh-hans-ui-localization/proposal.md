# Proposal

## Why

Burrow 目前所有界面文案都是硬编码英文，作者本人日常使用简体中文 macOS 系统，需要界面语言能跟随系统自动切换。当前仓库没有任何本地化基础设施，系统语言设置为中文时窗口与菜单栏依旧全英文。

## What Changes

- 新增简体中文本地化资源，App 启动时按 macOS 系统首选语言自动选择界面语言，App 内不提供语言开关。
- 系统首选语言命中简体中文（`zh-Hans` / `zh-CN` 等）时，主窗口 UI 与菜单栏（含菜单栏托盘）显示简体中文。
- 系统首选语言为其他任何语言（含繁体中文 `zh-Hant` / `zh-HK` / `zh-TW`、英文、日文等）时，界面回退为现有英文文案。
- 翻译表中未收录的文案一律回退显示英文原文，不显示占位符或空白。
- 主窗口 UI 覆盖：侧栏页面标题与副标题、各页面按钮/标签/开关/选择器、卡片标题与说明、空状态、确认对话框、运行面板、工具提示（`.help`）、无障碍标签、退出时的 NSAlert。
- 菜单栏覆盖：应用菜单（"Check for Updates…"、"Go" 菜单及其十个页面项）、`MenuBarExtra` 托盘卡片与托盘菜单（"Open Burrow"、"Settings…"、"Quit Burrow"、"Clean" 等）、托盘内的指标标签与状态词。
- 数值、单位、专业词汇、品牌名以及 Mole CLI 返回的英文内容保持英文（详见 design.md 的禁翻清单）。

## Capabilities

### New Capabilities
- `ui-localization`: 主窗口界面文案按系统语言展示简体中文或回退英文的行为契约
- `menu-bar-localization`: 应用菜单与菜单栏托盘文案按系统语言展示简体中文或回退英文的行为契约

### Modified Capabilities
<!-- 无既有 spec，openspec/specs/ 为空 -->

## Impact

- 新增 `Resources/zh-Hans.lproj/Localizable.strings`（翻译表）。
- 修改 `scripts/bundle.sh`：把 `.lproj` 拷入 `Contents/Resources`，并在生成的 `Info.plist` 中声明 `CFBundleDevelopmentRegion = en`。
- 修改 `Sources/Burrow/` 中承载 UI 文案的 `String` 类型属性与调用点（`AppModel.swift`、`RootView.swift`、`BurrowApp.swift`、`Features/*.swift`、`Design/Theme.swift`），使其参与本地化查表。
- `Package.swift`、`scripts/dmg.sh`、`scripts/appcast.sh`、`scripts/demo-video.sh`、`Vendor/mole/` 均不改。
- `Engine/` 内的解析锚点、命令名、JSON key、PTY 提示匹配词、字节格式化保持英文，不受影响。
- `Tests/BurrowTests/ParserTests.swift` 中依赖英文解析结果的断言不改动；新增本地化查表与回退的测试。
