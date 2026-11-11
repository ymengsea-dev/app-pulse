import Foundation

/// Plain-language text for figures shown to the user.
enum UsageFormat {
    static func percent(_ fraction: Double) -> String {
        let value = fraction * 100
        if value > 0, value < 0.1 { return "<0.1%" }
        if value < 10 { return String(format: "%.1f%%", value) }
        return String(format: "%.0f%%", value)
    }

    /// Binary units, so a 16 GB Mac reads as 16 GB, the same as in About This Mac.
    static func memory(_ bytes: UInt64) -> String {
        scaled(Double(bytes), base: 1024, suffix: "")
    }

    static func speed(_ bytesPerSecond: Double) -> String {
        scaled(bytesPerSecond, base: 1000, suffix: "/s")
    }

    static func count(_ count: Int, _ singular: String) -> String {
        "\(count) \(singular)\(count == 1 ? "" : "es")"
    }

    private static func scaled(_ value: Double, base: Double, suffix: String) -> String {
        let units = [(4.0, "TB"), (3.0, "GB"), (2.0, "MB"), (1.0, "KB")]
        for (power, name) in units where value >= pow(base, power) {
            let scaled = value / pow(base, power)
            return String(format: scaled < 10 ? "%.1f %@%@" : "%.0f %@%@", scaled, name, suffix)
        }
        return String(format: "%.0f B%@", value, suffix)
    }
}
