import SwiftUI

/// The English UI copy is the localization key. `Text` given a `String` variable uses its
/// verbatim initializer and skips the lookup, so views that hold copy in a `String` property
/// wrap it in `LocalizedStringKey`. A key missing from the table (Mole's own output, a unit, a
/// path) falls back to the string itself, so this is safe for anything that reaches the screen.
extension Text {
    /// `Text(localized: someString)` — the `String`-typed counterpart of `Text("literal")`.
    init(localized key: String) {
        self.init(LocalizedStringKey(key))
    }
}

/// Lookup for a plain key (a literal, or a `String` variable such as `page.title`).
/// `NSLocalizedString` resolves against `Bundle.main` and returns the key when it is absent.
func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "Burrow UI copy")
}

/// Lookup for INTERPOLATED copy. This MUST be a separate name: an overload
/// `localized(_: String.LocalizationValue)` loses overload resolution to the `String` one for
/// anything containing a runtime value ("\(size) free"), which silently materializes the whole
/// English sentence as the key and misses the "%@ free" entry. A `String.LocalizationValue`
/// produces exactly the `%@` / `%lld` / `%lf` key SwiftUI's `Text("… \(x) …")` uses, so one
/// translation serves both call sites.
func localizedFormat(_ value: String.LocalizationValue) -> String {
    String(localized: value)
}
