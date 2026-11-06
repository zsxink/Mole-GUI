# Tasks

## 1. 本地化基础设施

- [x] 1.1 新建 `Resources/zh-Hans.lproj/Localizable.strings`（UTF-8），先放入少量探针 key，并确认 `plutil -lint` 通过；验证：`plutil -lint Resources/zh-Hans.lproj/Localizable.strings` 输出 OK
- [x] 1.2 修改 `scripts/bundle.sh`：在资源拷贝段增加 `cp -R Resources/. "$APP/Contents/Resources/"`（必须位于 `codesign` 之前），在生成的 `Info.plist` 增加 `CFBundleDevelopmentRegion = en`；验证：`scripts/bundle.sh` 成功且 `build/Burrow.app/Contents/Resources/zh-Hans.lproj/Localizable.strings` 存在、`plutil -p build/Burrow.app/Contents/Info.plist | grep CFBundleDevelopmentRegion` 输出 `en`
- [x] 1.3 新增 `Tests/BurrowTests/LocalizationTests.swift`，用 Swift Testing 断言：临时 `.app` bundle 内 `Bundle.main` 在 `zh-Hans` 偏好下查表命中中文、在 `en`/`zh-Hant`/`ja` 偏好下回退英文原文、缺失 key 回退原文、含 `%@`/`%lld` 的 key 正确插值；验证：该测试在 `swift test` 中通过
- [x] 1.4 写一个校验脚本 `scripts/check-strings.sh`：提取 `Sources/Burrow` 中 UI 字面量与 `.strings` 的 key 做差集、检查重复 key、检查 key/value 占位符一致性、检查禁翻清单未被误收；验证：脚本对当前翻译表输出明确的缺失/多余 key 列表且无语法错误

## 2. 主窗口静态文案（字面量，只填表不改源码）

- [x] 2.1 翻译侧栏与页面头部：`Page.title` / `Page.subtitle` 的 20 条文案、`CommandMenu("Go")`、`Check for Updates…`；验证：`-startPage overview -snapshot` 截图中文系统下侧栏为中文，英文回退下为英文
- [x] 2.2 翻译 Overview / Clean / Uninstall 三页的按钮、标签、开关、卡片标题、空状态与状态提示；验证：三页 `-snapshot` 截图中文系统下无残留英文 UI 文案
- [x] 2.3 翻译 Optimize / Analyze / Projects / Installers 四页的按钮、标签、卡片、空状态与上下文菜单；验证：四页 `-snapshot` 截图中文系统下无残留英文 UI 文案
- [x] 2.4 翻译 Slim / History / Settings 三页的按钮、标签、开关、选择器、About 文案与空状态；验证：三页 `-snapshot` 截图中文系统下无残留英文 UI 文案
- [x] 2.5 翻译运行面板 `RunSheet` 的标题、状态、日志空状态、快捷应答按钮标签（`Yes`/`No`/`Skip`/`Space`/`Enter`/`Cancel` 等显示标签，按键字符不动）；验证：回放模式 `-replayRun` 截图中文系统下按钮为中文，且 `ParserTests` 中 `QuickReply.options(...).map(\.label)` 断言仍为英文并通过
- [x] 2.6 运行 `scripts/check-strings.sh` 与 `swift test`；验证：无重复 key、无占位符不匹配、`ParserTests` 全绿

## 3. 主窗口动态文案（String 类型需包装）

- [x] 3.1 包装 `AppModel.Page.title/subtitle` 与 `RootView` 的 `Text(page.title)` / `Text(page.subtitle)` / `.help`，使页面标题参与查表；验证：中文系统下侧栏与页面头部为中文，`-startPage settings` 等标识符仍可被解析
- [x] 3.2 包装 `EmptyState` / `HeroCard` / `Tag` / `SelectionBar` / `PillPicker` / `ScanQuickAction` / `ScanButton` 等自定义组件内部的 `Text(x)`（改为 `Text(LocalizedStringKey(x))` 或等价包装）；验证：各组件调用点在中文系统下显示中文，`-snapshot` 截图复查
- [x] 3.3 重构 `ConfirmAction` 与 `.confirmation()`：`title`/`message`/`button` 用 `String(localized:)` 包装，复数拼接改为 `%lld` 格式 key，中文 value 使用中文量词；验证：七个页面的确认对话框标题、正文、按钮均为中文且数值完整，`Cancel` 行为不变
- [x] 3.4 包装 `BurrowApp.swift` 的 `NSAlert`（`messageText`、`informativeText`、两个 `addButton(withTitle:)`）；验证：中文系统下退出告警为中文，退出/继续行为不变
- [x] 3.5 处理插值与格式化串：SwiftUI 插值 key 按 `%@`/`%lld`/`%lf` 写表；`String(format:)` 系列（`Drawing %.1f W`、`%.2f MB/s out`、`Load … · … procs`、`MB/s in`、`step(s) to run`、`+ " free"` 等）改为可本地化形式，中文 value 调整语序但保留 `%`/`W`/`MB/s`/`GB` 等单位；验证：`scripts/check-strings.sh` 占位符校验通过，`-snapshot` 截图数值与单位在两种语言下一致
- [x] 3.6 包装 `RemovalWatcher` 浮层面板的标题、正文与按钮（`String` 返回值），以及 `MoleError.errorDescription` 的显示；验证：中文系统下浮层文案为中文，`localizedDescription` 由系统处理不重复翻译
- [x] 3.7 处理 `Leftover.Kind.rawValue`、`MemoryPressure.label`、`HistoryResult.Session.baseCommand.capitalized` 等「既是显示又是身份/排序」的值：新增本地化显示属性，保留 rawValue 与排序逻辑；验证：`ParserTests.swift:107` 的 `title == "Clean"` 断言不变且通过，中文系统下这些标签显示为中文
- [x] 3.8 包装 `.help` / `.accessibilityLabel` / `.accessibilityValue` / `.accessibilityHint` / `.accessibilityAction(named:)` 中传入变量的 Burrow 自有文案；验证：中文系统下 VoiceOver 文本为中文且数值完整
- [x] 3.9 运行 `swift test` 与全部十页 `-snapshot`（中文系统默认）；验证：`ParserTests` 全绿，十页截图无残留英文 UI 文案、无占位符泄漏、无布局溢出

## 4. 菜单栏与托盘

- [x] 4.1 翻译应用菜单：`CommandGroup` 的 `Check for Updates…`、`CommandMenu("Go")` 及十个页面项（依赖 3.1 的 `page.title`）；验证：中文系统下应用菜单为中文，`⌘` 快捷键与英文系统一致
- [x] 4.2 翻译 `MenuBarExtra` 托盘卡片：`Open Burrow`、`Settings…`、`Quit Burrow`、`Clean`、`More`、分区标题与说明；产品名 `Burrow` 保持原样；验证：`-snapshotTray 1` 截图中文系统下为中文且 `Burrow` 未变
- [x] 4.3 翻译托盘指标标签（`Battery`/`Memory`/`Network`/`Disk`/`Free space`/`Used`/`Total` 等描述词），保留 `CPU`、`RAM`、`GB`、`MB/s`、`%` 等缩写与单位；验证：托盘截图中描述词为中文、数值与单位在两种语言下完全一致
- [x] 4.4 处理托盘状态词与无障碍文本：Burrow 自有的 `Normal`/`High`/`Critical` 压力等级、`Reading the disk…` 等状态本地化；Mole JSON 返回的 `charging`、`health_score_msg` 保持英文；验证：VoiceOver 文本中文且数值完整，引擎状态词仍为英文
- [x] 4.5 验证托盘操作不受语言影响；验证：中文系统下点击托盘 `Clean`、页面项、`Settings…`、`Quit Burrow` 均触发与英文系统相同的动作（仅观察，不确认任何 Mole 提示、不执行真实清理）

## 5. 全量校验与回退验证

- [x] 5.1 用 `-AppleLanguages "(ja-JP)"` 与 `"(zh-Hant-TW)"` 分别启动主窗口与托盘快照；验证：所有文案回退英文，且与改动前英文界面一致
- [x] 5.2 用 `-AppleLanguages "(zh-Hans-CN)"` 复跑十页与托盘快照；验证：中文覆盖率达标、禁翻清单内容（Mole 命令、JSON 字段、路径、单位、品牌名）全部保持英文
- [x] 5.3 运行 `scripts/check-strings.sh`、`swift test`（沙箱外，带 `-Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing`）与 `scripts/bundle.sh`；验证：全部通过，且 `build/Burrow.app/Contents/Resources/zh-Hans.lproj` 在签名后的 bundle 内
- [x] 5.4 检查空闲 CPU（`top -pid`）与 CLAUDE.md 安全规则；验证：无因本地化引入的持续重绘，测试期间未运行真实 Mole 操作、未写 owner 的 Mole 配置目录、退出后无残留 `Burrow.app/Contents/Resources/mole` 进程
- [x] 5.5 更新 `README.md` 与 `CLAUDE.md` 说明界面语言跟随系统（简体中文/英文回退）与翻译表位置；验证：文档所述命令与实际一致

## 6. 归档

- [x] 6.1 全部任务勾选后运行 `openspec validate zh-hans-ui-localization --strict`；验证：无错误
- [x] 6.2 运行 `openspec archive zh-hans-ui-localization`；验证：两个 capability 的 spec 进入 `openspec/specs/`，变更移入 `openspec/changes/archive/`
