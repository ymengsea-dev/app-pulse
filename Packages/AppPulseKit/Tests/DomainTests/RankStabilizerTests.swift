import Testing
@testable import Domain

struct RankStabilizerTests {
    @Test func firstUpdateSortsHighestFirst() {
        var stabilizer = RankStabilizer<String>()
        #expect(stabilizer.update(values: ["a": 1, "b": 3, "c": 2]) == ["b", "c", "a"])
    }

    @Test func oneSampleLeadDoesNotReorder() {
        var stabilizer = RankStabilizer<String>()
        _ = stabilizer.update(values: ["a": 3, "b": 1])
        #expect(stabilizer.update(values: ["a": 1, "b": 3]) == ["a", "b"])
    }

    @Test func twoSampleLeadReorders() {
        var stabilizer = RankStabilizer<String>()
        _ = stabilizer.update(values: ["a": 3, "b": 1])
        _ = stabilizer.update(values: ["a": 1, "b": 3])
        #expect(stabilizer.update(values: ["a": 1, "b": 3]) == ["b", "a"])
    }

    @Test func newItemTakesItsRankImmediately() {
        var stabilizer = RankStabilizer<String>()
        _ = stabilizer.update(values: ["a": 3, "b": 1])
        #expect(stabilizer.update(values: ["a": 3, "b": 1, "c": 5]) == ["c", "a", "b"])
    }

    @Test func removedItemDisappears() {
        var stabilizer = RankStabilizer<String>()
        _ = stabilizer.update(values: ["a": 3, "b": 1])
        #expect(stabilizer.update(values: ["b": 1]) == ["b"])
    }

    @Test func emptyInputIsSafe() {
        var stabilizer = RankStabilizer<String>()
        #expect(stabilizer.update(values: [:]).isEmpty)
    }
}
