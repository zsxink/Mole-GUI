import Foundation
import Testing
@testable import Burrow

/// The English UI copy is the localization key, so a missing key must fall back to that copy
/// unchanged. These tests pin the mechanism the app relies on: only `zh-Hans.lproj` ships, every
/// other system language resolves to English, and `String(localized:)` interpolation produces the
/// `%@` / `%lld` keys the table carries.
struct LocalizationTests {

    /// A throwaway `.app` whose Resources hold just our `zh-Hans.lproj`. `Bundle(path:)` then sees
    /// the same layout `Bundle.main` sees in the real bundle, without launching another process.
    private func makeBundle() throws -> Bundle {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("BurrowLocalizationTests-\(UUID().uuidString).app")
        let lproj = root.appendingPathComponent("Contents/Resources/zh-Hans.lproj")
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceStringsURL(),
                                         to: lproj.appendingPathComponent("Localizable.strings"))
        guard let bundle = Bundle(path: root.path) else { throw TestError.bundle(root.path) }
        return bundle
    }

    /// Resolve the checked-in table relative to this source file, so the test works from any cwd.
    private func sourceStringsURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // BurrowTests
            .deletingLastPathComponent()          // Tests
            .deletingLastPathComponent()          // repo root
            .appendingPathComponent("Resources/zh-Hans.lproj/Localizable.strings")
    }

    private enum TestError: Error { case bundle(String) }

    private func withBundle<T>(_ body: (Bundle) throws -> T) throws -> T {
        let bundle = try makeBundle()
        defer { try? FileManager.default.removeItem(at: bundle.bundleURL) }
        return try body(bundle)
    }

    @Test func chineseHitsAndVerbatimFallback() throws {
        try withBundle { bundle in
            #expect(bundle.preferredLocalizations.first == "zh-Hans")
            #expect(bundle.localizedString(forKey: "Overview", value: "Overview", table: nil) == "总览")
            #expect(bundle.localizedString(forKey: "Clean", value: "Clean", table: nil) == "清理")
            #expect(bundle.localizedString(forKey: "Health score", value: "Health score", table: nil) == "健康度")
            // Not in the table (a Mole status word, a unit, a path): must come back unchanged.
            for key in ["charging", "11.27 GB", "~/Library/Caches"] {
                #expect(bundle.localizedString(forKey: key, value: key, table: nil) == key)
            }
        }
    }

    /// `String(localized:)` is what `localized(_:)` uses for `String`-typed UI copy. Its
    /// interpolation must resolve to the very same keys SwiftUI's `Text("… \(x) …")` looks up.
    @Test func interpolatedStringCopyResolvesFromTheTable() throws {
        try withBundle { bundle in
            let size = "1.2 GB"
            #expect(String(localized: "Clean \(size)?", bundle: bundle) == "清理 1.2 GB？")
            let count = 3, suffix = "s"
            #expect(String(localized: "Move \(count) installer\(suffix) to the Trash?", bundle: bundle)
                    == "将 3 个安装包移入废纸篓？")
            let load = "1.50", procs = 4
            #expect(String(localized: "Load \(load) · \(procs) procs", bundle: bundle)
                    == "负载 1.50 · 4 procs")
            // A missing interpolated key returns the fully materialized English sentence.
            #expect(String(localized: "Mystery \(size)?", bundle: bundle) == "Mystery 1.2 GB?")
        }
    }

    @Test func onlySimplifiedChineseIsLocalized() {
        let available = ["en", "zh-Hans"]
        func preferred(_ langs: [String]) -> [String] {
            Bundle.preferredLocalizations(from: available, forPreferences: langs)
        }
        for lang in ["zh-Hans-CN", "zh-Hans", "zh-CN", "zh-Hans-CN,en-US"] {
            #expect(preferred([lang]).first == "zh-Hans", "\(lang) should use Chinese")
        }
        // Traditional Chinese, English, and every other language fall back to English.
        for lang in ["zh-Hant-TW", "zh-Hant", "zh-HK", "zh-TW", "en-US", "en-GB",
                     "ja-JP", "fr-FR", "de-DE", "ko-KR", "ru-RU"] {
            #expect(preferred([lang]).first == "en", "\(lang) should fall back to English")
        }
    }

    @Test func tableHasNoDuplicateKeysOrLostNumbers() throws {
        let text = try String(contentsOf: sourceStringsURL(), encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #""((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;"#)
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        // Numeric placeholders must never disappear: dropping %lld loses a real number. A `%@`
        // used as an English plural suffix ("%lld app%@") is deliberately DROPPED in Chinese
        // values — keeping it would render "3 个应用s" — so only numeric slots are invariant.
        // Chinese values may use POSIX positional specifiers ("%1$lld", "%3$@") to skip the
        // dropped suffix arg; strip "%N$" so those still count as numeric placeholders.
        let number = try NSRegularExpression(pattern: #"%(?:\d+\$)?l?l?[df]"#)
        func count(_ s: String) -> Int {
            number.numberOfMatches(in: s, range: NSRange(s.startIndex..., in: s))
        }
        var keys: [String] = []
        for match in matches {
            let key = String(text[Range(match.range(at: 1), in: text)!])
            let value = String(text[Range(match.range(at: 2), in: text)!])
            keys.append(key)
            #expect(count(key) == count(value), "numeric placeholder lost in \(key)")
        }
        #expect(Set(keys).count == keys.count, "duplicate keys in Localizable.strings")
        #expect(keys.count > 300)
    }

    /// Professional abbreviations, units and macOS System Settings names stay English (D4); the
    /// separator in a composite copy is localized as a whole so no full-width colon leaks into the
    /// English fallback. These pin the exact values the UI review asked to keep.
    @Test func keepEnglishTermsAndLocalizedSeparators() throws {
        try withBundle { bundle in
            func L(_ key: String.LocalizationValue) -> String { String(localized: key, bundle: bundle) }
            let load = "1.74", procs = 963, size = "766.24 GB", label = "偏高"
            #expect(L("Load \(load) · \(procs) procs") == "负载 1.74 · 963 procs")
            #expect(L("\(size) free") == "766.24 GB 可用")
            #expect(L("Pressure: \(label)") == "内存压力：偏高")
            #expect(L("Memory pressure: \(label)") == "内存压力：偏高")
            #expect(bundle.localizedString(forKey: "Every app is already Apple-silicon only.",
                                          value: "Every app is already Apple-silicon only.", table: nil)
                    == "所有应用都已仅含 Apple-silicon 架构。")
            let help = bundle.localizedString(forKey: "Privacy & Security → Full Disk Access: turn on Burrow, then scan again",
                                              value: "Privacy & Security → Full Disk Access: turn on Burrow, then scan again", table: nil)
            #expect(help.contains("Privacy & Security → Full Disk Access"))
            #expect(!help.contains("完全磁盘访问权限"))
            #expect(!help.contains("隐私与安全性"))
        }
    }

    /// Chinese has no plural suffix, so the English `s` interpolation must be dropped. When a
    /// real value (`%@` byte size, or a second `%lld`) follows that suffix, the Chinese value uses
    /// positional specifiers to skip it — otherwise the value's `%@` grabs the suffix "s" (or the
    /// second `%lld` reads a string pointer as an integer). These pin both failure modes.
    @Test func pluralSuffixesNeverLeakIntoChinese() throws {
        try withBundle { bundle in
            func L(_ key: String.LocalizationValue) -> String { String(localized: key, bundle: bundle) }
            let n = 3, suffix = "s", bytes = "1.2 GB"
            let runs = 0, hidden = 5, items = 2, err = "permission denied"
            // Suffix last: the Chinese value simply has no %@, so the "s" arg is dropped.
            #expect(L("\(runs) run\(suffix)") == "0 次运行")
            #expect(L("\(n) app\(suffix)") == "3 个应用")
            #expect(L("\(items) item\(suffix)") == "2 项")
            // An integer after the dropped string suffix must stay an integer (positional %3$lld).
            #expect(L("\(runs) run\(suffix) · \(hidden) previews hidden") == "0 次运行 · 已隐藏 5 次预览")
            // A data %@ after the suffix must be the byte size, not the "s" (positional %3$@).
            #expect(L("\(n) app\(suffix) · \(bytes)") == "3 个应用 · 1.2 GB")
            #expect(L("\(items) item\(suffix), \(bytes). You can restore them from the Trash.")
                    == "2 项，1.2 GB。可从废纸篓恢复。")
            #expect(L("\(n) file\(suffix) could not be moved to the Trash: \(err)")
                    == "3 个文件无法移入废纸篓：permission denied")
        }
    }

    /// A `String` fragment that is fed as a `%@` argument into another localized sentence must
    /// ALREADY be Chinese — otherwise the outer sentence translates but its argument stays English.
    /// Likewise a whole English sentence built with `+` or assigned to a `String` variable misses
    /// every interpolation key. These pin the six display sites the independent code review found.
    @Test func stringFragmentsAreLocalizedBeforeInterpolation() throws {
        try withBundle { bundle in
            func L(_ key: String.LocalizationValue) -> String { String(localized: key, bundle: bundle) }
            func N(_ key: String) -> String { NSLocalizedString(key, bundle: bundle, comment: "") }
            let bytes = "1.2 GB", names = "a.dmg, b.pkg", section = "caches", n = 3, suffix = "s"
            // M1: RunSheet.count() must return a localized fragment, not "3 apps"/"3 steps".
            #expect(L("\(n) step\(suffix)") == "3 个步骤")
            #expect(L("\(n) app\(suffix)") == "3 个应用")
            #expect(L("Freed \(bytes) · \(L("\(n) app\(suffix)"))") == "已释放 1.2 GB · 3 个应用")
            #expect(L("\(L("\(n) step\(suffix)")) done") == "已完成 3 个步骤")
            // M2: "Working on X" must be built with an interpolation, not materialized first.
            #expect(L("Working on \(section)") == "正在处理 caches")
            // M3: AnalyzePage "N more" tile name.
            #expect(L("\(12) more") == "另有 12 项")
            // M4: AnalyzePage trash error (whole sentence, not a String concatenation).
            #expect(L("\("BigFolder") could not be moved to the Trash. It may belong to macOS or another user.")
                    == "BigFolder 无法移入废纸篓，可能属于 macOS 或其他用户。")
            // M5: InstallersPage `+` concatenation must become a single localizedFormat.
            #expect(L("\(n) file\(suffix) could not be moved to the Trash: \(names)")
                    == "3 个文件无法移入废纸篓：a.dmg, b.pkg")
            // M6: ProjectsPage confirmation key must exist (no half-English dialog).
            #expect(L("Move \(n) build folder\(suffix) to the Trash?") == "将 3 个构建目录移入废纸篓？")
            // The materialized-English variants must NOT silently look Chinese.
            #expect(N("3 apps").contains("apps"))
            #expect(N("12 more").contains("more"))
        }
    }
}
