# Spec Delta

## Purpose

定义 Burrow 主窗口界面文案依据 macOS 系统首选语言自动呈现简体中文或回退英文的可观察行为，覆盖可见文字、辅助功能文本、数值单位与引擎数据的边界。

## ADDED Requirements

### Requirement: 系统语言驱动界面语言
系统 SHALL 依据 macOS 首选语言列表决定主窗口界面语言，且 MUST NOT 在 App 内提供任何语言切换开关或写入 `AppleLanguages` 用户默认值。

#### Scenario: 首选语言为简体中文
- **WHEN** 系统首选语言为 `zh-Hans`、`zh-Hans-CN` 或 `zh-CN` 时启动 App
- **THEN** 主窗口所有已收录文案 SHALL 显示为简体中文

#### Scenario: 首选语言为繁体中文
- **WHEN** 系统首选语言为 `zh-Hant`、`zh-Hant-TW`、`zh-HK` 或 `zh-TW` 时启动 App
- **THEN** 主窗口 SHALL 显示全部现有英文文案，MUST NOT 显示简体中文

#### Scenario: 首选语言为其他语言
- **WHEN** 系统首选语言为英文、日文、法文、德文、韩文、俄文等任何其他语言时启动 App
- **THEN** 主窗口 SHALL 显示全部现有英文文案

#### Scenario: 首选语言列表含中文与英文
- **WHEN** 首选语言列表为 `zh-Hans-CN, en-US` 时启动 App
- **THEN** 主窗口 SHALL 显示简体中文

### Requirement: 未收录文案回退英文原文
系统 SHALL 在翻译表缺少对应 key 时显示该 key 本身（即英文原文），MUST NOT 显示空字符串、占位符或 "Missing translation" 之类的调试文字。

#### Scenario: 翻译表缺项
- **WHEN** 界面渲染一条未写入 `zh-Hans.lproj/Localizable.strings` 的文案
- **THEN** 该文案 SHALL 原样显示其英文原文

#### Scenario: 英文回退
- **WHEN** 系统语言不是简体中文且渲染任一文案
- **THEN** 该文案 SHALL 原样显示其英文原文

### Requirement: 主窗口可见文案本地化
侧栏页面标题与副标题、各页面按钮、标签、开关、选择器、卡片标题与说明、空状态、状态提示、确认对话框标题与正文、运行面板标题与按钮、工具提示 SHALL 跟随界面语言切换。

#### Scenario: 侧栏与页面头部
- **WHEN** 中文系统下打开主窗口
- **THEN** 侧栏十个页面项及页面头部的标题与副标题 SHALL 为中文

#### Scenario: 确认对话框
- **WHEN** 中文系统下触发任一破坏性操作的确认对话框
- **THEN** 对话框标题、正文与两个按钮文案 SHALL 为中文，且 `Cancel` 按钮 SHALL 保持可取消行为

#### Scenario: 运行面板
- **WHEN** 中文系统下打开运行面板（含预览/回放）
- **THEN** 面板标题、状态、快捷应答按钮标签 SHALL 为中文，且发给 Mole 的按键字符 MUST NOT 改变

#### Scenario: 退出告警
- **WHEN** 中文系统下 Mole 仍在运行时请求退出
- **THEN** `NSAlert` 的标题、说明与两个按钮文案 SHALL 为中文

### Requirement: 辅助功能与工具提示本地化
`.help`、`.accessibilityLabel`、`.accessibilityValue`、`.accessibilityHint`、`.accessibilityAction(named:)` 传入的 Burrow 自有文案 SHALL 跟随界面语言切换。

#### Scenario: 中文系统的辅助功能文本
- **WHEN** 中文系统下 VoiceOver 读取任一带无障碍标签的控件
- **THEN** 该标签 SHALL 为中文

### Requirement: 数值与单位保持原样
数字格式、小数分隔符、字节单位（`GB`/`MB`/`KB`/`TB`/`B`）、`MB/s`、`%`、`W` 与 `en_US_POSIX` 字节格式输出 SHALL 在两种界面语言下保持一致，MUST NOT 因本地化改变。

#### Scenario: 字节数值渲染
- **WHEN** 任一界面语言下显示 `11270000000` 字节
- **THEN** 显示 SHALL 为 `11.27 GB`，且点阵数字渲染 MUST NOT 出错

### Requirement: 插值与复数文案语义正确
含插值、计数与复数的文案 SHALL 在中文下按中文语序与量词呈现，且 MUST NOT 因为翻译丢失数值或产生英文复数后缀。

#### Scenario: 计数文案
- **WHEN** 中文系统下显示形如 `3 selected`、`1 app` 的计数文案
- **THEN** 数值 SHALL 完整保留，文案 SHALL 使用中文量词且不含孤立的英文 `s` 后缀

#### Scenario: 带参数文案
- **WHEN** 中文系统下显示形如 `Load 1.50 · 4 procs` 的带参数文案
- **THEN** 所有参数值 SHALL 完整保留且位置符合中文语序

### Requirement: 引擎与协议字符串保持英文
Mole 命令名与参数、解析锚点、PTY 提示匹配词、JSON key、UserDefaults key、页面标识符、窗口 id、`-startPage` 参数值、文件路径与文件夹名、品牌名、专业缩写、Mole CLI 返回的英文内容 SHALL 保持英文，MUST NOT 进入翻译表。

#### Scenario: 扫描解析不受影响
- **WHEN** 中文系统下执行一次 dry-run 扫描
- **THEN** 解析结果 SHALL 与英文系统下完全一致，MUST NOT 因界面语言改变而漏解析或误判

#### Scenario: 自动应答不受影响
- **WHEN** 中文系统下运行面板显示中文快捷应答按钮
- **THEN** 按钮发送的按键字符 SHALL 与英文系统下完全一致

#### Scenario: 启动参数不受影响
- **WHEN** 中文系统下以 `-startPage settings` 启动
- **THEN** App SHALL 打开设置页，页面标识符 MUST NOT 被本地化

#### Scenario: Mole 输出保持英文
- **WHEN** 中文系统下显示清理分区名、条目名、历史记录命令名或状态词
- **THEN** 这些来自 Mole 的内容 SHALL 保持英文原文

### Requirement: 系统提供的文案不重复翻译
`error.localizedDescription`、`.formatted(.relative)`、`Duration.formatted` 等由系统依据 locale 生成的文案 SHALL 交由系统处理，MUST NOT 写入翻译表覆盖。

#### Scenario: 相对日期
- **WHEN** 中文系统下显示相对日期或运行时长
- **THEN** 文案 SHALL 由系统按当前 locale 生成，且 MUST NOT 出现中英混杂的重复翻译
