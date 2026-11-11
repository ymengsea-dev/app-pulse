/// Keeps a live ranking calm: an item only passes another once it has led for two samples in a row.
public struct RankStabilizer<ID: Hashable & Sendable>: Sendable {
    private var order: [ID] = []
    private var previous: [ID: Double] = [:]

    public init() {}

    public mutating func update(values: [ID: Double]) -> [ID] {
        var next = order.filter { values[$0] != nil }
        let known = Set(next)
        let added = values.keys.filter { !known.contains($0) }.sorted { values[$0, default: 0] > values[$1, default: 0] }
        next.append(contentsOf: added)

        var swapped = next.count > 1
        while swapped {
            swapped = false
            for index in 0..<max(next.count - 1, 0) where shouldPass(next[index + 1], next[index], values) {
                next.swapAt(index, index + 1)
                swapped = true
            }
        }

        order = next
        previous = values
        return next
    }

    private func shouldPass(_ challenger: ID, _ leader: ID, _ values: [ID: Double]) -> Bool {
        let challengerNow = values[challenger, default: 0]
        let leaderNow = values[leader, default: 0]
        // An item with no history is judged on its current value alone.
        let challengerBefore = previous[challenger] ?? challengerNow
        let leaderBefore = previous[leader] ?? leaderNow
        return challengerNow > leaderNow && challengerBefore > leaderBefore
    }
}
