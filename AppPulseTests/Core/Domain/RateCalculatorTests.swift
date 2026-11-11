import Testing
@testable import AppPulse

struct RateCalculatorTests {
    @Test func firstReadingReportsZero() {
        var calculator = RateCalculator<Int32>()
        #expect(calculator.rates(counters: [1: 500], elapsedSeconds: 2) == [1: 0])
    }

    @Test func secondReadingReportsPerSecondRate() {
        var calculator = RateCalculator<Int32>()
        _ = calculator.rates(counters: [1: 500], elapsedSeconds: 2)
        #expect(calculator.rates(counters: [1: 900], elapsedSeconds: 2) == [1: 200])
    }

    @Test func counterGoingBackwardsReportsZero() {
        var calculator = RateCalculator<Int32>()
        _ = calculator.rates(counters: [1: 500], elapsedSeconds: 2)
        #expect(calculator.rates(counters: [1: 100], elapsedSeconds: 2) == [1: 0])
    }

    @Test func zeroElapsedTimeReportsNothing() {
        var calculator = RateCalculator<Int32>()
        #expect(calculator.rates(counters: [1: 500], elapsedSeconds: 0).isEmpty)
    }

    @Test func resetForgetsPreviousCounters() {
        var calculator = RateCalculator<Int32>()
        _ = calculator.rates(counters: [1: 500], elapsedSeconds: 2)
        calculator.reset()
        #expect(calculator.rates(counters: [1: 900], elapsedSeconds: 2) == [1: 0])
    }
}
