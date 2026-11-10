import Domain

/// Reads per-process traffic by running `nettop` once per sample.
public struct NettopMetricsProvider: NetworkMetricsProviding {
    private let runner = CommandRunner()

    public init() {}

    public func sample() async throws -> [NetworkSample] {
        let output = try await runner.run(
            "/usr/bin/nettop",
            arguments: ["-L", "1", "-n", "-x", "-J", "bytes_in,bytes_out"],
            timeoutSeconds: 5
        )
        let samples = NettopParser.parse(output)
        guard !samples.isEmpty else { throw PlatformError.dataUnavailable("nettop") }
        return samples
    }
}
