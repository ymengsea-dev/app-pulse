import Domain
import Foundation

/// Turns `nettop -x -J bytes_in,bytes_out` text into samples. Lines it cannot read are ignored.
enum NettopParser {
    private static let connectionPrefixes = ["tcp4 ", "tcp6 ", "udp4 ", "udp6 ", "quic4 ", "quic6 "]

    static func parse(_ output: String) -> [NetworkSample] {
        var samples: [NetworkSample] = []
        var current: (pid: Int32, bytesIn: UInt64, bytesOut: UInt64, connections: [NetworkConnection])?

        func flush() {
            if let current {
                samples.append(NetworkSample(
                    pid: current.pid,
                    bytesIn: current.bytesIn,
                    bytesOut: current.bytesOut,
                    connections: current.connections
                ))
            }
            current = nil
        }

        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            if line.hasPrefix(",") {
                // A header starts a new reading. Only the latest one counts.
                flush()
                samples.removeAll()
            } else if connectionPrefixes.contains(where: line.hasPrefix) {
                if let connection = parseConnection(line) {
                    current?.connections.append(connection)
                }
            } else if let process = parseProcess(line) {
                flush()
                current = (process.pid, process.bytesIn, process.bytesOut, [])
            }
        }
        flush()
        return samples
    }

    /// Reads `name.pid,bytes_in,bytes_out,`. The name can contain dots and spaces.
    private static func parseProcess(_ line: String) -> (pid: Int32, bytesIn: UInt64, bytesOut: UInt64)? {
        guard let (label, bytesIn, bytesOut) = splitCounters(line),
              let dot = label.lastIndex(of: "."),
              let pid = Int32(label[label.index(after: dot)...]) else { return nil }
        return (pid, bytesIn, bytesOut)
    }

    /// Reads `tcp4 local<->remote,bytes_in,bytes_out,`. Rows with no remote end return nil.
    private static func parseConnection(_ line: String) -> NetworkConnection? {
        guard let (label, _, _) = splitCounters(line),
              let space = label.firstIndex(of: " "),
              let arrow = label.range(of: "<->") else { return nil }
        let isIPv6 = label[..<space].hasSuffix("6")
        return parseEndpoint(String(label[arrow.upperBound...]), isIPv6: isIPv6)
    }

    /// IPv4 endpoints look like `1.2.3.4:443`. IPv6 endpoints look like `2001:db8::1.443`.
    private static func parseEndpoint(_ endpoint: String, isIPv6: Bool) -> NetworkConnection? {
        let separator: Character = isIPv6 ? "." : ":"
        guard let index = endpoint.lastIndex(of: separator) else { return nil }
        let address = String(endpoint[..<index])
        guard address != "*", let port = Int(endpoint[endpoint.index(after: index)...]) else { return nil }
        return NetworkConnection(remoteAddress: address, remotePort: port)
    }

    /// Splits the trailing `,in,out,` columns from the label. Empty counters read as 0.
    private static func splitCounters(_ line: String) -> (label: Substring, bytesIn: UInt64, bytesOut: UInt64)? {
        let parts = line.dropLast(line.hasSuffix(",") ? 1 : 0).split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return nil }
        let label = line[line.startIndex..<parts[parts.count - 3].endIndex]
        return (label, UInt64(parts[parts.count - 2]) ?? 0, UInt64(parts[parts.count - 1]) ?? 0)
    }
}
