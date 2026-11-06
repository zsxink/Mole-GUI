#!/bin/bash
# Sanity checks for Resources/zh-Hans.lproj/Localizable.strings.
# The English UI copy IS the key: SwiftUI's Text("literal"), localized("literal") and
# String(localized:) all look it up in Bundle.main. A key that is absent simply falls back to
# English, so a MISSING key is not an error — a DUPLICATE key, a lost numeric placeholder, or a
# translated protocol/engine word is. The "missing" list is advisory: it shows untranslated copy.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

TABLE="Resources/zh-Hans.lproj/Localizable.strings"
SRC="Sources/Burrow"

if [[ ! -f "$TABLE" ]]; then
  echo "✗ $TABLE not found" >&2
  exit 1
fi

status=0

# 1. Syntax: plutil understands both UTF-8 and UTF-16 .strings files.
if plutil -lint "$TABLE" >/dev/null 2>&1; then
  echo "✓ plutil -lint"
else
  echo "✗ plutil -lint failed:"; plutil -lint "$TABLE"; status=1
fi

python3 -I - "$TABLE" "$SRC" <<'PY'
import re, sys, glob, os
from collections import Counter

table_path, src = sys.argv[1], sys.argv[2]
text = open(table_path, encoding='utf-8').read()

pair_re = re.compile(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.M)
pairs = pair_re.findall(text)

# --- duplicate keys ---
keys = [k for k, _ in pairs]
dups = [k for k, c in Counter(keys).items() if c > 1]
if dups:
    print("✗ duplicate keys:")
    for d in dups: print("   ", repr(d))
else:
    print(f"✓ {len(keys)} keys, no duplicates")

# --- placeholders must survive, WITH THEIR TYPE, in order -------------------
# A dropped %lld loses a real number; a %lf turned into %lld reads garbage; a reordered or
# dropped real-data %@ silently shifts the positional substitution.
#   * %@ is NOT invariant: it is often an English plural-suffix slot ("%lld app%@") that Chinese
#     deliberately drops. Keeping it would render "3 个应用s". Those keys are exempted below.
#   * Values may use POSIX positional specifiers ("%1$lld", "%3$@") to SKIP a dropped plural-suffix
#     %@ arg: the value's %@ would otherwise grab the suffix "s" instead of the real data. Strip the
#     "%N$" prefix so "%3$@" still counts as the same slot type.
slot = re.compile(r'%(?:(\d+)\$)?(l?l?[df]|@)')
def slots(s):
    return [(int(pos) if pos else i + 1, typ) for i, (pos, typ) in enumerate(slot.findall(s))]
def expected(k, v):
    ks, vs = slots(k), slots(v)
    if len(ks) == len(vs) and all(a == b for a, b in zip(ks, vs)):
        return None  # exact
    # Legitimate plural-suffix drop: an English "%lld …%@" key carries a trailing/intermediate "s"
    # slot that Chinese has no use for. The value then has one fewer %@ (dropped entirely, or
    # skipped via positional %N$). Numeric slots — including their ORDER — must be untouched.
    # (The suffix noun may itself contain a space: "build folder%@", "removed app%@"…)
    if len(ks) - len(vs) == 1:
        k_types = [t for _, t in ks]
        v_types = [t for _, t in vs]
        numeric_ok = [t for t in k_types if t != '@'] == [t for t in v_types if t != '@']
        dropped_one_at = k_types.count('@') - v_types.count('@') == 1
        # A REAL-DATA %@ after the plural suffix must survive. When the key has two or more %@,
        # the surviving one must be POSITIONAL (e.g. "%3$@") so it skips the dropped "s" arg;
        # a bare "%@" would consume the suffix instead of the byte size / error string.
        key_at = [(pos, t) for pos, t in ks if t == '@']
        val_at = [(pos, t) for pos, t in vs if t == '@']
        has_real_data_after_suffix = len(key_at) >= 2
        surviving_is_positional = bool(re.search(r'%\d+\$@', v))
        suffix_drop_ok = (not has_real_data_after_suffix) or surviving_is_positional
        if numeric_ok and dropped_one_at and suffix_drop_ok:
            return None
    return (ks, vs)
bad = [(k, v, expected(k, v)) for k, v in pairs if expected(k, v) is not None]
if bad:
    print("✗ placeholder type/order mismatch (key -> value):")
    for k, v, _ in bad: print("   ", repr(k), '->', repr(v))
else:
    print("✓ placeholder types and order preserved (plural-suffix drops exempted)")

# --- deny-list: engine/protocol words must never be KEYS -------------------
deny = [
    "--dry-run", "--json", "--limit", "--watch", "--with-data", "--permanent",
    "health_score", "health_score_msg", "cpu_model", "rx_rate_mbs", "tx_rate_mbs",
    "LANG", "LC_ALL", "TERM", "NO_COLOR", "MOLE_DRY_RUN",
    "startPage", "replayRun", "snapshotTray", "showInMenuBar", "offerLeftovers",
    "Would apply", "DRY RUN", "System caches need sudo",
    "Select Artifacts to Purge", "is enabled", ".config/mole",
    "clean", "uninstall", "optimize", "purge", "slim", "status", "history", "analyze",
    # Folder names are protected (spec §83 / design D4): a bare "Downloads" key would also
    # rewrite Mole-derived Tag values whose artifact kind happens to be that word. Exception:
    # "Logs"/"Cache"/"Window state" are Leftover.Kind display labels, not path segments — they
    # are legitimately localizable UI copy, so they stay out of this list.
    "Home", "Downloads", "Documents", "Library", "Applications", "Drives", "Desktop",
    "Caches", "Application Support", "Keychains", "Mail", "Messages", "iCloud",
]
hits = [d for d in deny if d in keys]
if hits:
    print("✗ deny-list keys present:")
    for h in hits: print("   ", repr(h))
else:
    print("✓ no deny-list / protocol keys")

# --- D4 value check: protected terms must survive INSIDE Chinese values -----
# Exact-key matching above cannot catch a translated *value*: "负载 %@ · %lld 个进程" is a
# perfectly-formed key/value pair that still rewrites the protected abbreviation `procs`.
# For each protected term that appears in a key, the corresponding value must keep it verbatim
# (ASCII). Also catch the known Chinese substitutions for macOS/brand/architecture names.
# Abbreviations, units, architecture names and macOS proper names must be kept VERBATIM when
# they appear in a key. Brand names (Mole/Burrow) may be dropped for a natural Chinese sentence —
# what matters is that they are never REPLACED with a Chinese coinage (checked separately below).
protected = [
    "CPU", "RAM", "GPU", "SSD", "APFS", "DNS", "sudo", "Intel", "Apple-silicon",
    "CLI", "JSON", "API", "ID", "URL", "PTY", "TTY", "ANSI", "UTF-8", "HTTP",
    "SSH", "VPN", "Homebrew", "Brew", "LaunchDaemons", "Sparkle",
    "MB/s", "GB", "MB", "KB", "TB", "cycles", "procs", "cores",
    "Touch ID", "Finder", "Spotlight", "Gatekeeper", "iCloud",
    "macOS", "GitHub", "GPL-3.0", "tw93", "Full Disk Access", "Privacy & Security",
    "Telegram", "Apple M", "Excellent", "charging", "discharging",
]
substitutions = ["英特尔", "芯片架构", "访达", "聚焦", "个进程", "次循环",
                 "完全磁盘访问权限", "隐私与安全性", "苹果芯片", "鼹鼠", "burrow软件"]
violations = []
for k, v in pairs:
    for term in protected:
        if term in k and term not in v:
            violations.append((k, v, f"dropped protected term {term!r}"))
    for sub in substitutions:
        if sub in v and sub not in k:
            violations.append((k, v, f"Chinese substitution {sub!r}"))
if violations:
    print("✗ D4 protected-term violations in VALUES:")
    for k, v, why in violations[:20]: print("   ", repr(k), '->', repr(v), '|', why)
else:
    print("✓ D4 protected terms kept English in every value")

# --- advisory: English UI literals in source with no table key ---
# Collect double-quoted literals from Swift sources, skip obvious data/code strings, then diff.
lit_re = re.compile(r'"((?:[^"\\]|\\.)*)"')
code_ext = (".swift",)
literals = set()
for path in glob.glob(src + "/**/*" + ".swift", recursive=True):
    for line in open(path, encoding='utf-8'):
        for m in lit_re.finditer(line):
            s = m.group(1)
            # Heuristic: UI copy contains a space or starts with a capital and is not a path,
            # identifier, symbol name, key name or a format/percent token.
            if len(s) < 3 or len(s) > 160: continue
            if s.startswith(("~/", "/", "http", "x-apple", "com.", ".", "_")): continue
            if re.match(r'^[a-z_]+[A-Z]', s) and ' ' not in s: continue  # camelCase identifier
            if '%' in s and ' ' not in s: continue                          # format token
            if re.fullmatch(r'[A-Za-z0-9._\-/]+', s) and ' ' not in s: continue  # single token
            if not re.search(r'[A-Za-z]{3}', s): continue
            literals.add(s)
table_keys = set(keys)
missing = sorted(literals - table_keys)
# Pure interpolation-format keys are produced at runtime, not literal in source; this list is
# advisory only. Show a bounded sample.
print(f"ℹ advisory: {len(missing)} English literals have no matching key (fallback is English).")
for m in missing[:40]:
    print("   ", repr(m))

sys.exit(1 if (dups or bad or hits or violations) else 0)
PY
py=$?

echo "--- validate helper mechanism in source ---"
# Every Text(localized:) / localized() / localizedFormat() site should compile; swift build is the
# real check. Print counts for a quick sanity signal, and fail if any INTERPOLATED copy is still
# routed through localized() — that overload silently materializes the English sentence as the key
# and misses the "%@ …" table entry (see design.md D3). Those MUST use localizedFormat().
wrapped=$(grep -rEo "Text\(localized:|localizedFormat\(|localized\(" "$SRC" --include="*.swift" | wc -l | tr -d ' ')
echo "ℹ $wrapped localized()/localizedFormat()/Text(localized:) call sites"
if grep -rEn 'localized\("[^"]*\\\(' "$SRC" --include="*.swift" >/dev/null 2>&1; then
  echo "✗ interpolated copy routed through localized() (should be localizedFormat):"
  grep -rEn 'localized\("[^"]*\\\(' "$SRC" --include="*.swift"
  status=1
else
  echo "✓ no interpolated copy routed through localized()"
fi

exit $(( status | py ))
