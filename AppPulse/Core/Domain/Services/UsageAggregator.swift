/// Combines per-process usage into per-app usage.
/// Load that no readable process accounts for goes to the system row, so figures add up to the machine's total.
public enum UsageAggregator {
    public static func aggregate(_ processes: [ProcessUsage], load: SystemLoad) -> [AppUsage] {
        var apps: [String: AppUsage] = [AppIdentity.system.id: AppUsage(identity: .system)]

        for process in processes {
            let identity = process.owner.app
            var app = apps[identity.id] ?? AppUsage(identity: identity)
            app.cpuFraction += process.cpuFraction
            app.memoryBytes += process.memoryBytes
            app.gpuFraction += process.gpuFraction
            app.downloadBytesPerSecond += process.downloadBytesPerSecond
            app.uploadBytesPerSecond += process.uploadBytesPerSecond
            app.processes.append(process)
            apps[identity.id] = app
        }

        normalizeGPU(&apps)
        assignRemainders(&apps, load: load)

        return apps.values.map { app in
            var app = app
            app.cpuFraction = min(app.cpuFraction, 1)
            app.memoryFraction = load.physicalMemoryBytes > 0
                ? min(Double(app.memoryBytes) / Double(load.physicalMemoryBytes), 1)
                : 0
            return app
        }
    }

    /// GPU queues overlap, so summed time can exceed the wall clock. Scale it back to 100%.
    private static func normalizeGPU(_ apps: inout [String: AppUsage]) {
        let total = apps.values.reduce(0) { $0 + $1.gpuFraction }
        guard total > 1 else { return }
        for id in apps.keys {
            apps[id]?.gpuFraction /= total
            for index in apps[id]?.processes.indices ?? 0..<0 {
                apps[id]?.processes[index].gpuFraction /= total
            }
        }
    }

    private static func assignRemainders(_ apps: inout [String: AppUsage], load: SystemLoad) {
        guard var system = apps[AppIdentity.system.id] else { return }
        let realApps = apps.values.filter { !$0.identity.isSystem }

        if let busy = load.cpuBusyFraction {
            let remainder = busy - realApps.reduce(0) { $0 + $1.cpuFraction }
            system.cpuFraction = max(system.cpuFraction, remainder)
        }
        if let busy = load.gpuBusyFraction {
            let remainder = busy - realApps.reduce(0) { $0 + $1.gpuFraction }
            system.gpuFraction = max(system.gpuFraction, remainder)
        }
        if let used = load.memoryUsedBytes {
            let attributed = realApps.reduce(UInt64(0)) { $0 + $1.memoryBytes }
            if used > attributed {
                system.memoryBytes = max(system.memoryBytes, used - attributed)
            }
        }
        apps[AppIdentity.system.id] = system
    }
}
