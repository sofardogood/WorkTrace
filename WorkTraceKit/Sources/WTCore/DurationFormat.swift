import Foundation

/// Locale-aware, human-readable durations that keep seconds visible for short
/// spans, so sub-minute activity never collapses to "0m". Bilingual by design:
///
///   < 1 minute  → "42s"    / "42秒"
///   < 1 hour    → "3m 15s" / "3分15秒"   (seconds dropped when zero)
///   >= 1 hour   → "1h 24m" / "1時間24分" (minutes dropped when zero)
///
/// Pure and deterministic so it can be unit-tested in both languages.
public enum DurationFormat {
    private static func isJapanese(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "ja"
    }

    /// Short duration string for the given locale. Negative inputs clamp to 0.
    public static func short(_ seconds: TimeInterval, locale: Locale = .current) -> String {
        let total = max(0, Int(seconds.rounded()))
        let ja = isJapanese(locale)

        if total < 60 {
            return ja ? "\(total)秒" : "\(total)s"
        }
        if total < 3600 {
            let m = total / 60, s = total % 60
            if s == 0 { return ja ? "\(m)分" : "\(m)m" }
            return ja ? "\(m)分\(s)秒" : "\(m)m \(s)s"
        }
        let h = total / 3600, m = (total % 3600) / 60
        if m == 0 { return ja ? "\(h)時間" : "\(h)h" }
        return ja ? "\(h)時間\(m)分" : "\(h)h \(m)m"
    }
}
