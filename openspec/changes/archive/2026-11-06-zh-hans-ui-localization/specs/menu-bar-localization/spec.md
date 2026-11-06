# Spec Delta

## Purpose

定义 Burrow 应用菜单与菜单栏托盘（含 `MenuBarExtra` 弹出卡片、托盘菜单命令、指标标签与状态词）依据 macOS 系统首选语言呈现简体中文或回退英文的可观察行为。

## ADDED Requirements

### Requirement: 应用菜单文案跟随系统语言
`CommandGroup` / `CommandMenu` 内的菜单标题与菜单项 SHALL 跟随界面语言切换，键盘快捷键 MUST NOT 改变。

#### Scenario: 中文系统的应用菜单
- **WHEN** 中文系统下打开应用菜单
- **THEN** `Check for Updates…`、`Go` 菜单标题及其十个页面项 SHALL 为中文

#### Scenario: 英文回退下的应用菜单
- **WHEN** 系统语言为繁体中文或其他任何语言时打开应用菜单
- **THEN** 菜单 SHALL 显示全部现有英文文案

#### Scenario: 快捷键保持不变
- **WHEN** 中文系统下打开 `Go` 菜单
- **THEN** 每个页面项的 `⌘` 数字快捷键 SHALL 与英文系统下完全一致

### Requirement: 托盘卡片可见文案本地化
`MenuBarExtra` 弹出卡片中的标题、按钮、分区标题、说明、状态提示、空状态 SHALL 跟随界面语言切换。

#### Scenario: 中文系统的托盘卡片
- **WHEN** 中文系统下点开菜单栏托盘
- **THEN** `Open Burrow`、`Settings…`、`Quit Burrow`、`Clean` 等按钮与卡片内说明文字 SHALL 为中文

#### Scenario: 产品名保持原样
- **WHEN** 任一界面语言下点开菜单栏托盘
- **THEN** 产品名 `Burrow` SHALL 保持原样，MUST NOT 被翻译

### Requirement: 托盘指标标签本地化且单位保持英文
托盘指标卡片的标签词 SHALL 跟随界面语言切换；`CPU`、`RAM`、`GB`、`MB/s`、`%` 等专业缩写与单位 SHALL 保持英文。

#### Scenario: 中文系统的指标标签
- **WHEN** 中文系统下查看托盘的 `Battery`、`Memory`、`Network`、`Disk`、`Free space` 等指标
- **THEN** 描述性标签 SHALL 为中文（电池、内存、网络、磁盘、可用空间），而 `CPU`、`GB`、`MB/s`、`%` 等缩写与单位 SHALL 保持英文

#### Scenario: 指标数值不变
- **WHEN** 任一界面语言下查看托盘指标数值
- **THEN** 数值与单位 SHALL 完全一致，MUST NOT 因语言改变

### Requirement: 托盘状态词本地化
Burrow 自有的状态词（内存压力等级、扫描中、读取中等）SHALL 跟随界面语言切换；Mole JSON 返回的状态词 SHALL 保持英文。

#### Scenario: 内存压力标签
- **WHEN** 中文系统下内存压力为 `High` 或 `Critical` 时查看托盘
- **THEN** 压力等级 SHALL 显示为中文，且颜色语义 MUST NOT 改变

#### Scenario: 引擎状态词
- **WHEN** 中文系统下托盘显示 Mole 返回的 `charging`、`Normal`、`health_score_msg` 等状态词
- **THEN** 这些状态词 SHALL 保持英文原文

### Requirement: 托盘无障碍文本本地化
托盘卡片的 `.accessibilityLabel` / `.accessibilityHint` / `.accessibilityValue` 中 Burrow 自有文案 SHALL 跟随界面语言切换，且 MUST NOT 丢失其中的数值。

#### Scenario: 中文系统的托盘无障碍文本
- **WHEN** 中文系统下 VoiceOver 读取托盘指标行
- **THEN** 标签 SHALL 为中文且数值完整保留

### Requirement: 托盘菜单行为不受语言影响
托盘菜单项触发的窗口跳转、设置页打开、退出 App、清理请求 SHALL 在两种界面语言下行为一致。

#### Scenario: 中文系统的托盘操作
- **WHEN** 中文系统下点击托盘的 `Clean` 或任一页面项
- **THEN** SHALL 触发与英文系统下相同的动作，MUST NOT 因文案本地化而失效
