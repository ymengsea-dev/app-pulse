/// Turns cumulative counters into per-second rates.
/// A key seen for the first time, or a counter that went backwards, reports a rate of 0.
public struct RateCalculator<Key: Hashable & Sendable>: Sendable {
    private var previous: [Key: UInt64] = [:]

    public init() {}

    public mutating func rates(counters: [Key: UInt64], elapsedSeconds: Double) -> [Key: Double] {
        defer { previous = counters }
        guard elapsedSeconds > 0 else { return [:] }

        var rates: [Key: Double] = [:]
        rates.reserveCapacity(counters.count)
        for (key, value) in counters {
            guard let last = previous[key], value >= last else {
                rates[key] = 0
                continue
            }
            rates[key] = Double(value - last) / elapsedSeconds
        }
        return rates
    }

    public mutating func reset() {
        previous = [:]
    }
}
