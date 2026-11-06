# Design

## Context

见 proposal.md - Why。现状：`Package.swift` 只有一个 `.executableTarget`，无 `resources:`、无 `Bundle.module`；`scripts/bundle.sh` 只把可执行文件、`Vendor/mole`、`LICENSE`、`Burrow.icns` 拷进 `.app`，生成的 `Info.plist` 无 `CFBundleDevelopmentRegion`；仓库无任何 `.lproj`、`Localizable.strings`、`NSLocalizedString` 或显式 `LocalizedStringKey`。约 300～340 条 Burrow 自写界面文案分布在 20 个 Swift 文件，其中约 112 处为 `Text("…")` / `Button("…")` 字面量，其余为 `String` 类型属性、插值句、复数拼接、格式化串与 `NSAlert` 文本。

实测结论（本机 macOS 27.2 / Swift 6.4.2，系统首选语言 `zh-Hans-CN`）：

- 从 `Contents/MacOS` 启动的二进制，其 `Bundle.main` 会自动发现 `Contents/Resources/zh-Hans.lproj/Localizable.strings`。
- 只放 `zh-Hans.lproj` 且不建 `en.lproj` 时，`Bundle.main.preferredLocalizations` 在 `zh-Hans-CN` 下为 `zh-Hans`，在 `zh-Hant-TW` / `ja-JP` / `en-US` 下为 `en`；`localizedString(forKey:)` 相应返回中文或英文原文。这正是「不支持的语言回退英文」的天然行为，无需写语言探测代码。
- `CFBundleDevelopmentRegion = en` 使 `developmentLocalization` 明确为 `en`，回退路径确定。
- UTF-8 的 `.strings` 可被正确读取，无需 UTF-16。
- `NSLocalizedString("Overview")` 与 `String(localized: "Overview")` 都能查到该表；`String(localized: "Load \(x) · \(n) procs")` 正确解析 `%@` / `%lld` 占位符并返回中文。
- SwiftUI 插值生成的 key：字符串 → `%@`，整数 → `%lld`，浮点 → `%lf`（例：`"Load \(String(format:)) · \(procs) procs"` → `Load %@ · %lld procs`，`"\(n) app\(suffix)"` → `%lld app%@`）。翻译表 key 与 value 必须用同样占位符。

## Goals / Non-Goals

**Goals:**

- 用最小改动让主窗口 UI 与菜单栏文案跟随系统语言，零新依赖、零 Xcode、不改 `Package.swift`。
- 保持英文回退、未收录 key 回退英文原文。
- 保护所有引擎/协议字符串，确保扫描解析、PTY 自动应答、启动参数完全不受影响。
- 现有 `ParserTests.swift` 的英文解析断言不被破坏。

**Non-Goals:**

- 不提供 App 内语言开关，不写 `AppleLanguages`。
- 不做繁体中文、不做第三种语言。
- 不建 `en.lproj`，不引入 String Catalog / `.xcstrings` / `.stringsdict`（中文无复数变形，复数后缀在翻译时消解）。
- 不翻译 Mole CLI 输出的原文内容（分区名、条目名、历史命令名、状态词）。
- 不本地化 Info.plist 里的产品名与版权声明。
- 不改 `Engine/` 的解析与格式化逻辑，不改 `Vendor/mole/`。
- 不做界面截图评审（本次仅文案，不改布局与视觉）。

## Decisions

### D1: 手工放置 `.lproj`，不走 SwiftPM 资源打包
在 `scripts/bundle.sh` 中把 `Resources/` 下的 `.lproj` 拷入 `Contents/Resources/`，位置必须在 `codesign` 之前。

- 理由：`Text("…")` 与 `NSLocalizedString` 默认查 `Bundle.main`，而 `Bundle.main` 的 `resourceURL` 就是 `Contents/Resources`；SwiftPM 的 `resources:` 会生成 `Burrow_Burrow.bundle` 与 `Bundle.module`，既到不了 `.app`，也不会被 `Text("…")` 查到。
- 备选：给 `Package.swift` 加 `resources:` + `Bundle.module` 并逐处改 `bundle:` 参数 —— 改动面大且与 SwiftUI 默认行为相悖，否决。
- `cp -R Resources/. "$APP/Contents/Resources/"` 用尾部 `/.` 保证 `.lproj` 直接落在 `Resources/` 下。`dmg.sh` 的 `ditto "$APP"` 与发布用的 `ditto -c -k --keepParent` 会原样带上，无需改动。

### D2: 英文原文即 key，不建 `en.lproj`
翻译表只写 `zh-Hans.lproj/Localizable.strings`；key 为现有英文文案，value 为中文。查不到即显示 key 本身。

- 理由：回退逻辑由 Foundation 免费提供，避免了显式 `CFBundleLocalizations` 与自建回退链。实测繁体中文也正确回退英文。

### D3: 两个辅助函数分别处理纯 key 与插值句，不大改类型签名
`LocalizedText.swift` 提供三个入口，都基于 `Bundle.main`、查同一张表：

- `Text(localized: someString)`：`Text` 的扩展，等价于 `Text(LocalizedStringKey(someString))`。给 `String` 变量用，因为 `Text(stringVar)` 走的是逐字初始化器、不会查表。
- `localized(_ key: String) -> String`：用 `NSLocalizedString`，处理纯 key（字面量或 `page.title` 这类 `String` 变量）。缺 key 原样返回。
- `localizedFormat(_ value: String.LocalizationValue) -> String`：用 `String(localized:)`，专门处理**带运行时插值**的句子。

**关键陷阱（实测）**：不能只用一个 `localized` 名字做重载。若同时存在 `localized(_: String)` 与 `localized(_: String.LocalizationValue)`，任何含运行时值的插值调用（如 `localized("\(size) free")`）会因重载决议优先落到 `String` 版本，把整句英文实体化成 key，从而**静默错过**表里 `"%@ free"` 这条。`@_disfavoredOverload` 与泛型 `StringProtocol` 重载都救不回来。因此插值句必须用**独立的函数名** `localizedFormat(...)`，强制选中 `String.LocalizationValue` 版本。`String.LocalizationValue` 生成的 `%@` / `%lld` / `%lf` key 与 SwiftUI `Text("… \(x) …")` 完全一致（已逐字节验证），所以一条翻译同时服务字面量与插值两处。全仓库 44 处插值调用统一用 `localizedFormat`。

- 理由：实测 `String(localized:)` 与 SwiftUI 共用同一张表与同一套占位符，无需把 30 个组件签名从 `String` 改成 `LocalizedStringKey`（那会牵动所有调用点与测试）。
- 例外：`ConfirmAction` 的 `.alert(_ title: String, …)` 与 `NSAlert` 的 `messageText` / `addButton(withTitle:)` 收 `String`，必须显式包装。
- 插值句按 SwiftUI 生成的 `%@` / `%lld` / `%lf` 写 key；中文语序在 value 中调整。复数拼接（`"\(n) app\(suffix)"`）用 `%lld app%@` 形式的 key，中文 value 丢掉英文复数后缀 `%@` 槽位并改用中文量词（保留它会渲染成 `3 个应用s`）。
- **复数后缀的两个坑（截图评审发现并修正）**：`String(localized:)` 的替代是**按位置**把参数喂给 value 的占位符，不是按名字。① 后缀是最后一个 `%@` 时，value 少一个 `%@` 即可，多余的字符串参数被安全丢弃（`0 次运行`）。② 后缀后面还有真实数据 `%@`（字节数/错误串）或第二个 `%lld` 时，value 的占位符会**抓错参数**——拿到后缀 `"s"` 而不是字节数，或把字符串指针当整数读出乱码。此时 value 必须用**全量 POSIX 位置占位符**跳过后缀槽：key `%lld app%@ · %@` 的参数是 `[count, suffix, bytes]`，value 写 `%1$lld 个应用 · %3$@`（`%1$`=count、`%3$`=bytes，跳过 `%2$` 后缀）。混合型 `%lld run%@ · %lld …` 同理写 `%1$lld … %3$lld`。**位置占位符必须全用或全不用**，只给一半会失效。校验脚本的数值占位符正则已兼容 `%N$` 前缀；`LocalizationTests.pluralSuffixesNeverLeakIntoChinese` 覆盖了这些用例。

### D3b: 传进 `String` 类型组件的文案必须是「显示就绪」的
`HeroCard` / `EmptyState` / `QuickAction` 这类组件把 `detail` / `text` / `label` 声明为 `String`，内部用 `Text(localized: x)` 查表。这只在 `x` **恰好等于某个 key** 时生效：
- 静态字面量（`"Nothing to clean right now."`）：是 key → 正常翻译。
- 已经本地化的中文串：查不到 → 原样显示（相当于幂等，安全）。
- **插值字面量或拼接串**（`"Search \(n) apps"`、`tally + "Files listed twice..."`）：插值在传入前就被实体化成整句英文，`Text(localized:)` 把整句当 key 查 → **必然 miss、残留英文**。

修正规则：这些调用点必须先用 `localizedFormat(...)` / `localized(...)` 把 Burrow 自写部分翻好再传入；Mole 数据（tally、error、分区名）保持原样拼接。`HeroCard.progress` 内部是逐字 `Text(progress)`（不再查表），所以静态/动态 progress 串**必须**在调用点包好 `localized(...)` / `localizedFormat(...)`。`.help()` 传字面量会自动走 `LocalizedStringKey`，但 `String` 三元表达式（`.help(scanning ? "A" : "B")`）走逐字重载，需要显式 `localized(...)`。截图评审据此修了 Clean / Installers / Leftovers / Projects / Slim / Analyze / Uninstall 七处。

### D3c: 标点、语序与专业词由整句 value 决定，不在源码里拼
截图评审发现的最后一类问题都不是「漏翻」，而是把语言相关部件留在了 Swift 里：

- **分隔符**：`Pressure` 与 `Memory pressure` 的等级标签原本拼成 `"\(localized("Pressure"))：\(localized(p.label))"`。硬编码的全角 `：` 会随英文回退一起显示成 `Pressure：High`。改为一条整句 key `"Pressure: %@"`（托盘同理 `"Memory pressure: %@"`），英文回退自然得到 `Pressure: High`，中文 value 才用 `内存压力：%@`。规则：分隔符属于整句文案，必须进表，不能在调用点拼接。
- **语序**：`"%@ free" = "可用 %@"` 把中文词插在数字与单位之间，渲染成 `766.24 可用 GB`。改为 `"%@ 可用"`（`766.24 GB 可用`），并让托盘与 Overview 一样走 `localizedFormat("\(unit) free")`；原先五条 `"GB free" = "可用 GB"` 之类的死条目随之删除。
- **专业词 / 系统专名**：D4 明列 `procs`、`cycles`、`Apple-silicon`、`Full Disk Access`、`Privacy & Security` 保留英文，翻译表里却有 `负载 %@ · %lld 个进程`、`%lld 次循环`、`Apple 芯片架构`、`完全磁盘访问权限` 等 value。已逐条改回英文专名（描述词 `负载` 仍翻）。`cycles` 那条是恒等条目（源码本来就把 `12 cycles` 当数据逐字显示），直接删掉以免误导。
- **量词与空格**：`"Changed %@ · %@"` 的 `%@ 有变动` 多一个空格，改成 `%@有变动`；`隐藏 %3$lld 次预览` 改成更自然的 `已隐藏 %3$lld 次预览`。

`Tests/BurrowTests/LocalizationTests.keepEnglishTermsAndLocalizedSeparators` 固定了这些 value；`scripts/check-strings.sh` 的禁翻清单继续兜底。

### D3d: 独立复核补出的六处漏翻与两处校验缺口
归档后的独立代码复核用真实表探针逐条复现了六处残留英文，全部是 D3b 的变体——**英文片段在传入显示层前已实体化成 `String`**，于是插值 key 永远命中不到：

- `RunSheet.count()` 返回 `"3 apps"` / `"3 steps"`，作为 `%@` 参数喂进 `Freed … · %@` / `%@ done`，外层翻了、参数没翻。修：在 `count()` 内用 `localizedFormat("\(n) app\(suffix)")` 先翻片段；补表项 `%lld step%@`。
- `RunSheet.activity` 的 `.running` 分支把 `"Working on \(section)"` 存进 `String copy`，最后 `localized(copy)` 以整句英文为 key。修：该分支直接 `localizedFormat("Working on \(section.lowercased())")`；`progress.now`（Mole spinner 原文）保持逐字。
- `AnalyzePage` 的 `"\(rest.count) more"` 瓦片名、`"\(entry.name) could not be moved…"` 错误句，都是 `String` 后走逐字 `Text`/`Label`。修：调用点用 `localizedFormat(...)`。
- `InstallersPage` 的失败提示用 `+` 拼接，强制 `String` 重载。修：改成单条 `localizedFormat("\(n) file\(s) …: \(names)")`。
- `ProjectsPage` 的 `Move %lld build folder%@ to the Trash?` 表项缺失（唯一一条 `localizedFormat` key 未收录）。修：补表项。

**校验升级**：原 `check-strings.sh` 的数值校验只比 `%lld` 数量，禁翻检查只做 key 精确匹配、完全不看 value，且 `localized("…\(")` 的 grep 抓不到 `localized(变量)`。现改为：① 占位符按**类型 + 顺序**比较，仅豁免「key 比 value 多一个复数后缀 `%@` 且数值槽不变」；当 key 有两个以上 `%@` 时，value 里幸存的真实数据 `%@` 必须是位置化的 `%3$@`（否则会抓到复数 `"s"`）；② D4 专业词/系统专名逐条检查 **value** 是否逐字保留，并扫描已知中文替代词（`个进程`、`完全磁盘访问权限` 等）；品牌名 `Mole`/`Burrow` 允许在通顺中文里省略，但不允许造中文替代。两项守卫都用「故意注入违规」验证过会报错、干净表通过。`LocalizationTests.stringFragmentsAreLocalizedBeforeInterpolation` 固定了六处的实际中文值。

另顺手把托盘 Clean 快捷键的无障碍标签改成整句 key `"Clean %@ · %@"`（中文 `清理%@ · %@`、英文回退自然带空格），消除了「中文词 + 英文逗号」。

`Engine/Reports.swift` 里 `Needs your password` / `Kept, check it yourself` 是 Burrow 对 Mole 数据行的重写，按 Non-Goals「不改 `Engine/`」保留。

### D3e: 文件夹名不得进表，`Tag` 改为逐字显示（独立 UI 复核）
归档后的独立 Opus 截图评审（`--strict` 规格符合性）发现一处 MUST FIX 的规格偏差：翻译表里收录了 `Whole Mac` `Home` `Downloads` `Documents` `Library` `Applications` `Drives` `Your home folder` 八条**文件夹名** key。这违反 D4「文件路径与文件夹名 MUST NOT 进入翻译表」与 spec §83，且不只是洁癖问题——`Tag(text:)` 有一处调用点喂的是 Mole 数据（`ProjectsPage` 的 `artifact.kind`，其值可能是 `path.lastPathComponent`，例如恰好叫 `Downloads`）。`Tag` 内部原本用 `Text(localized: text)` 查表，于是任何与 UI key 同名的 Mole 派生值都会被**静默改写**成中文；反过来，磁盘地图的位置胶囊也会被翻成中文，与 Mole 卡片标题、路径（`~`、`/Applications`、`~/Library`）不一致。

修法分三层，都是让「数据来源」决定要不要查表：

- **删表**：移除上述八条文件夹名 key；重叠说明句改成整句 value，但把 `~`、`~/Library`、`~/Downloads` 作为路径原样保留（`这些位置相互重叠（~ 已包含 ~/Library 和 ~/Downloads）…`）。
- **`Tag` 逐字化**：`Theme.Tag` 内部 `Text(localized: text)` → `Text(text)`。约定调用方传入「显示就绪」的串（已本地化、或 Mole 数据），组件本身不再查表，从根上消除同名碰撞。
- **调用点补齐**：7 处原本传英文**字面量**的 `Tag(text: "…")`（`Shared` 的 `Manual`/`Skipped`、`HistoryPage` 的 `Preview`/`Interrupted`、`AnalyzePage` 的 `Clean can remove`、`SettingsPage` 的 `On`/`Off`）显式包 `localized(...)`；`AnalyzePage` 的位置胶囊 `Button(place.0)` 与 `placeLabel` 也改回逐字路径。其余 8 处本就传 `localizedFormat(...)` 或 Mole 数据，无需改。

守卫升级：`scripts/check-strings.sh` 的 deny 清单加入这些文件夹名（`Logs`/`Cache`/`Window state` 例外——它们是 `Leftover.Kind` 的 UI 分类标签而非路径片段，合法可翻）。故意注入一条 `"Downloads" = "下载";` 验证脚本会报错、干净表通过。改 `Tag` 后面最大的回归风险是「其他页中文标签退回英文」，已重出 overview/history/settings/projects/clean 五张截图逐页确认：`关`、`11.47 GB 可清理`、`正在扫描 0:10`、`已隐藏 9 次预览` 等仍为中文，Mole 数据 tag（`target`、`node_modules`）与状态词（`Excellent`、`discharging`）按 D4 保持英文。

### D4: 严格禁翻清单
以下内容 MUST NOT 进入翻译表（拼写以代码为准）：

- **Mole 命令与参数**：`clean` `optimize` `purge` `slim` `status` `history` `analyze` `uninstall` `touchid` `enable` `disable` `--dry-run` `--json` `--limit` `--list` `--watch` `--interval` `--with-data` `--permanent` `--version` `2s` `200`。
- **解析锚点**：`====` `Potential space:` `Items` `Categories` `DRY RUN` `Whitelist` `protected` `Would free` `Would apply` `unchanged` `Skipped` `of Intel code` `is enabled` `System caches need sudo` `Select Artifacts to Purge` `Select apps to slim` `Files to be removed:` `Personal data to remove:` `Personal data kept:` `enter confirm` `esc cancel` `Could not inspect` `; kept` `Dry run incomplete/complete` `System:` `Review only:` `Last used`。
- **PTY 提示匹配词**：`password` `enter` `esc` `y/n` `skip` `space` `quit` `confirm` `continue`。
- **JSON key**：`health_score` `health_score_msg` `cpu_model` `total_ram` `used_percent` `swap_used` `rx_rate_mbs` `tx_rate_mbs` `memory_bytes` `cycle_count` `system_power` `adapter_power` `battery_temp` `cpu_temp` `disk_io` `disk_size` `os_version` `per_core` `core_count` `p_core_count` `e_core_count` `load1` `read_rate` `write_rate` `time_left` `trash_size` `top_processes` `is_dir` `last_access` `scan_status` `large_files` `started_at` `ended_at` `failed_tasks` `bundle_id` `uninstall_name` `sessions` `deletions`。
- **UserDefaults / 启动参数 / 标识符**：`showInMenuBar` `ApplePersistenceIgnoreState` `startPage` `tour` `replayRun/Title/Plan` `snapshot` `snapshotTray/Delay/Size` `scanPreview` `history.showPreviews` `clean.includeSystem` `offerLeftovers` `main` `rect`，十个 page rawValue（`overview`…`settings`），窗口 id。
- **环境变量 / 路径键**：`LANG`/`LC_ALL`=`en_US.UTF-8`、`TERM`、`PATH`、`NO_COLOR`、`MOLE_DRY_RUN`、`uz.khan.burrow`、`.config/mole/*`、`.cache/mole/*`。
- **点阵字形与字节格式**：`DotMatrix.swift` 字形表、`ByteSize.format` 的 `en_US_POSIX`（`11.27 GB` 的空格与小数点是点阵渲染器输入），`Int64.metric` / `Int64.bytesText`。
- **文件/系统路径与文件夹名**：`~/Library/…`、`Caches` `Logs` `Application Support` `Keychains` `Mobile Documents` `CloudStorage` `Mail` `Messages` `Containers` `Group Containers` `Accounts` `AddressBook` `FileProvider` `MobileSync` `CallHistoryDB` `CallHistoryTransactions` `Knowledge` `CloudDocs` `iCloud` `Dock` `DifferentialPrivacy` `Photos` `Calendars` `WebKit` `Downloads` `Desktop` `Documents` `Applications`。
- **Info.plist 元数据**：产品名 `Burrow`、`GPL-3.0. Engine: Mole by tw93.`、`SUFeedURL` 等所有 key 与值。
- **专业缩写（保留英文）**：`CPU`、`RAM`、`GPU`、`SSD`、`APFS`、`DNS`、`sudo`、`Intel`、`Apple-silicon`、`CLI`、`JSON`、`API`、`ID`、`URL`、`PTY`/`TTY`、`ANSI`、`UTF-8`、`HTTP`、`SSH`、`VPN`、`Homebrew`/`Brew`、`LaunchDaemons`、`Sparkle`。
- **单位与数值（保留英文）**：`GB` `MB` `KB` `TB` `B` `MB/s` `%` `W` `cycles` `procs` `cores`，所有数字格式。
- **品牌 / 系统专名（保留英文）**：`Mole`、`Burrow`、`Touch ID`、`Finder`、`Spotlight`、`Gatekeeper`、`iCloud`、`macOS`、`GitHub`、`GPL-3.0`、`tw93`、`Full Disk Access`、`Privacy & Security`、`Trash`（macOS 术语，界面中可视情况写「废纸篓」）。
- **Mole 返回的英文状态词与内容**：`charging`、`Normal`、`Critical`、`health_score_msg`、`Old Downloads (90d+)`、清理分区/条目名、历史命令名、`summary` / `notes` 原文行、Mole JSON 里的 `Battery.status/health`。
- **系统生成文案**：`error.localizedDescription`、`.formatted(.relative)`、`Duration.formatted`，交由系统 locale 处理。

**可翻的灰区（按用户确认的规则）**：描述性界面标签翻成中文（`Battery`→电池、`Memory`→内存、`Network`→网络、`Disk`→磁盘、`Health score`→健康度、`Load`→负载、`Pressure`→内存压力、`Free space`→可用空间、`Used`→已用、`Total`→总量、`purgeable`→可清理），缩写与单位保持英文。

### D5: 测试断言保护
`ParserTests.swift` 断言 `ByteSize.format == "11.27 GB"`、Mole 分区名、`QuickReply.options(...).map(\.label) == ["Continue","Skip"]` 等。策略：本地化只作用于**显示层**，底层 `label` / `baseCommand.capitalized` / 解析结果保留英文值；`QuickReply` 按钮显示处包装本地化，测试断言的模型值不变。这样无需修改既有断言，也不需要在测试里强制英文 locale。

### D6: 验证方式
- `swift build` 与 `swift test`（按 CLAUDE.md 带 `-Xswiftc -plugin-path -Xswiftc /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing`，且在沙箱外运行）。
- `scripts/bundle.sh` 后检查 `Contents/Resources/zh-Hans.lproj/Localizable.strings` 存在。
- 用 `-AppleLanguages "(zh-Hans-CN)"` 与 `-AppleLanguages "(ja-JP)"` / `"(zh-Hant-TW)"` 分别启动 `-snapshot`，对比截图确认中文与英文回退。
- 校验翻译表：key 语法（`plutil -lint` 或解析）、占位符与源码一致、无重复 key、禁翻清单未被误收。
- 遵守 CLAUDE.md 安全规则：不运行任何真实 Mole 操作、不按任何清理/卸载/优化按钮、不确认任何 Mole 提示、不写 `~/.config/mole` 等目录。

## Risks / Trade-offs

- [翻译表 key 与源码字面量不同步] → 用脚本提取源码中的 UI 字面量与 `.strings` key 做差集校验，纳入任务组验证。
- [插值 key 的占位符与 value 不匹配导致显示错乱或崩溃] → 校验脚本只把 `%lld`/`%lf` 数值槽位当不变量（中文会刻意丢掉英文复数后缀 `%@`）；另写脚本把源码里 44 处 `localizedFormat("…\(…)…")` 按 SwiftUI 规则推导成 `%@`/`%lld` key，逐条确认表内命中（结果：0 处缺失）。
- [插值句误落到 `localized(_: String)` 重载，整句英文被当 key、静默漏翻] → 用独立函数名 `localizedFormat` 强制选中 `String.LocalizationValue`；`grep` 确认无 `localized("…\(")` 残留。
- [`String` 类型文案漏包装，中文界面残留英文] → 按盘点出的 30 个 `String` 显示属性逐个核对，截图复查每一页与托盘。
- [误翻解析锚点或 PTY 匹配词，导致扫描/自动应答静默失效] → D4 禁翻清单作为硬边界；解析相关文件（`Engine/`）完全不改；现有 `ParserTests` 全绿作为回归保护。
- [`.strings` 编码或格式错误导致整表失效] → UTF-8 + `plutil -lint`，并在 App 内验证至少一个 key 命中。
- [codesign 之后才拷资源会被签名 seal 排除] → 拷贝语句放在 `bundle.sh` 的 `codesign` 之前。
- [托盘/菜单文案在 offscreen snapshot 模式下不易覆盖] → 用 `-snapshotTray 1` 单独出托盘截图。

## Migration Plan

纯增量：新增资源与翻译表、新增少量包装代码、不改数据模型与用户默认值。回滚即删除 `zh-Hans.lproj` 与 `bundle.sh` 的改动，界面回到全英文，无状态迁移成本。发布时需重新生成 `Burrow.zip` 与签名（资源变化会改变 zip 字节），`scripts/appcast.sh` 照常运行。
