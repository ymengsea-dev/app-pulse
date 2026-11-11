import Testing
@testable import AppPulse

struct UsageFormatTests {
    @Test(arguments: [
        (0.0, "0.0%"), (0.0004, "<0.1%"), (0.034, "3.4%"), (0.34, "34%"), (1.0, "100%"),
    ])
    func percent(fraction: Double, expected: String) {
        #expect(UsageFormat.percent(fraction) == expected)
    }

    @Test func memoryUsesBinaryUnits() {
        #expect(UsageFormat.memory(500) == "500 B")
        #expect(UsageFormat.memory(1_572_864) == "1.5 MB")
        #expect(UsageFormat.memory(17_179_869_184) == "16 GB")
    }

    @Test func speedUsesDecimalUnits() {
        #expect(UsageFormat.speed(0) == "0 B/s")
        #expect(UsageFormat.speed(2_100_000) == "2.1 MB/s")
    }

    @Test func singularAndPlural() {
        #expect(UsageFormat.count(1, "process") == "1 process")
        #expect(UsageFormat.count(12, "process") == "12 processes")
    }
}
