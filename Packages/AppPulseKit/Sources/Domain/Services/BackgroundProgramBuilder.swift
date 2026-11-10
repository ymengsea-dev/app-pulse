/// Picks out the processes that run without a window or Dock icon, and combines them by program file.
public enum BackgroundProgramBuilder {
    public static func build(
        _ processes: [ProcessUsage],
        foregroundBundleIdentifiers: Set<String>,
        signers: [String: CodeSigner]
    ) -> [BackgroundProgram] {
        var programs: [String: BackgroundProgram] = [:]

        for process in processes {
            // Without a path there is nothing to check or show, as for the kernel itself.
            guard let path = process.owner.executablePath else { continue }
            if let identifier = process.owner.app.bundleIdentifier, foregroundBundleIdentifiers.contains(identifier) {
                continue
            }

            var program = programs[path] ?? BackgroundProgram(
                path: path,
                name: process.owner.processName,
                bundlePath: process.owner.app.bundlePath,
                signer: signers[path]
            )
            program.processCount += 1
            program.cpuFraction += process.cpuFraction
            program.memoryBytes += process.memoryBytes
            program.networkBytesPerSecond += process.downloadBytesPerSecond + process.uploadBytesPerSecond
            program.isReadable = program.isReadable || process.isReadable
            programs[path] = program
        }
        return Array(programs.values)
    }
}
