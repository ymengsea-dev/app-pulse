import Domain
import Foundation
import IOKit

/// Reads GPU figures from IORegistry. These keys are undocumented and exist on Apple silicon only.
public struct IOKitGPUMetricsProvider: GPUMetricsProviding {
    public init() {}

    public func sample() throws -> GPUSample {
        var services: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &services) == KERN_SUCCESS else {
            throw PlatformError.dataUnavailable("IOAccelerator")
        }
        defer { IOObjectRelease(services) }

        var nanoseconds: [Int32: UInt64] = [:]
        var deviceBusy: Double?
        var foundUsageData = false

        while case let service = IOIteratorNext(services), service != 0 {
            defer { IOObjectRelease(service) }

            if let stats = Self.property(service, "PerformanceStatistics") as? [String: Any],
               let utilization = stats["Device Utilization %"] as? NSNumber {
                deviceBusy = max(deviceBusy ?? 0, utilization.doubleValue / 100)
            }

            var clients: io_iterator_t = 0
            guard IORegistryEntryGetChildIterator(service, kIOServicePlane, &clients) == KERN_SUCCESS else { continue }
            defer { IOObjectRelease(clients) }

            while case let client = IOIteratorNext(clients), client != 0 {
                defer { IOObjectRelease(client) }
                guard let usage = Self.property(client, "AppUsage") as? [[String: Any]] else { continue }
                foundUsageData = true
                guard let creator = Self.property(client, "IOUserClientCreator") as? String,
                      let pid = Self.parseCreatorPID(creator) else { continue }
                nanoseconds[pid, default: 0] += Self.totalGPUTime(usage)
            }
        }

        guard foundUsageData else { throw PlatformError.dataUnavailable("AppUsage") }
        return GPUSample(nanosecondsByPID: nanoseconds, deviceBusyFraction: deviceBusy)
    }

    /// Parses text such as `pid 437, WindowServer`.
    static func parseCreatorPID(_ creator: String) -> Int32? {
        guard creator.hasPrefix("pid "), let comma = creator.firstIndex(of: ",") else { return nil }
        return Int32(creator[creator.index(creator.startIndex, offsetBy: 4)..<comma])
    }

    static func totalGPUTime(_ usage: [[String: Any]]) -> UInt64 {
        usage.reduce(0) { total, entry in
            total + ((entry["accumulatedGPUTime"] as? NSNumber)?.uint64Value ?? 0)
        }
    }

    private static func property(_ entry: io_registry_entry_t, _ key: String) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }
}
