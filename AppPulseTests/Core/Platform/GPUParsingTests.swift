import Foundation
import Testing
@testable import AppPulse

struct GPUParsingTests {
    @Test func readsPIDFromCreator() {
        #expect(IOKitGPUMetricsProvider.parseCreatorPID("pid 437, WindowServer") == 437)
    }

    @Test func handlesProcessNamesWithSpaces() {
        #expect(IOKitGPUMetricsProvider.parseCreatorPID("pid 86011, Code Helper") == 86011)
    }

    @Test(arguments: ["", "pid , name", "process 5, name", "pid 5"])
    func rejectsUnexpectedCreatorText(text: String) {
        #expect(IOKitGPUMetricsProvider.parseCreatorPID(text) == nil)
    }

    @Test func sumsAllQueues() {
        let usage: [[String: Any]] = [
            ["API": "Metal", "accumulatedGPUTime": NSNumber(value: 100)],
            ["API": "Metal", "accumulatedGPUTime": NSNumber(value: 250)],
            ["API": "Metal"],
        ]
        #expect(IOKitGPUMetricsProvider.totalGPUTime(usage) == 350)
    }
}
