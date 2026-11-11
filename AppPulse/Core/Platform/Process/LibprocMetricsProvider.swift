import Darwin

/// Reads CPU time and memory with `proc_pid_rusage`. Processes owned by other users are skipped.
public struct LibprocMetricsProvider: ProcessMetricsProviding {
    private let nanosecondsPerMachTick: Double

    public init() {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        nanosecondsPerMachTick = timebase.denom > 0 ? Double(timebase.numer) / Double(timebase.denom) : 1
    }

    /// Lists every process. Other users' processes are included without figures, so they can still be shown.
    public func sample() throws -> [ProcessSample] {
        let samples = Self.allPIDs().map(readProcess)
        guard samples.contains(where: \.isReadable) else { throw PlatformError.dataUnavailable("proc_pid_rusage") }
        return samples
    }

    private func readProcess(_ pid: Int32) -> ProcessSample {
        var info = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        guard status == 0 else { return ProcessSample(pid: pid, cpuNanoseconds: nil, memoryBytes: nil) }

        // rusage reports CPU time in Mach ticks, which are not nanoseconds on Apple silicon.
        let ticks = Double(info.ri_user_time) + Double(info.ri_system_time)
        return ProcessSample(
            pid: pid,
            cpuNanoseconds: UInt64(ticks * nanosecondsPerMachTick),
            memoryBytes: info.ri_phys_footprint
        )
    }

    private static func allPIDs() -> [Int32] {
        let capacity = proc_listallpids(nil, 0)
        guard capacity > 0 else { return [] }
        // Leave room for processes that start between the two calls.
        var pids = [Int32](repeating: 0, count: Int(capacity) + 32)
        let count = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard count > 0 else { return [] }
        return Array(pids.prefix(Int(count)))
    }
}
