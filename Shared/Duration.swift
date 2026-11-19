import Foundation

enum DurationFormat {
    /// Parses "90", "90m", "2h", "1h30m", "45s", "1d". A bare number means minutes.
    static func parse(_ input: String) -> TimeInterval? {
        let text = input.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { return nil }

        var total: Double = 0
        var number = ""

        for char in text {
            if char.isNumber || char == "." {
                number.append(char)
                continue
            }
            guard let value = Double(number) else { return nil }
            switch char {
            case "s": total += value
            case "m": total += value * 60
            case "h": total += value * 3600
            case "d": total += value * 86400
            default: return nil
            }
            number = ""
        }
        if !number.isEmpty {
            guard let value = Double(number) else { return nil }
            // "90" -> 90 minutes, "1h30" -> 1h 30m
            total += value * 60
        }
        return total > 0 ? total : nil
    }

    /// 3725 -> "1h 2m", 125 -> "2m 5s", 42 -> "42s"
    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        if m > 0 { return sec > 0 && m < 10 ? "\(m)m \(sec)s" : "\(m)m" }
        return "\(sec)s"
    }
}
