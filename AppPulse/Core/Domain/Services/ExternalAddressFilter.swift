import Foundation

/// Decides whether an IP address is on the public internet.
public enum ExternalAddressFilter {
    public static func isExternal(_ address: String) -> Bool {
        let host = address.split(separator: "%", maxSplits: 1).first.map(String.init) ?? address

        var ipv4 = in_addr()
        if inet_pton(AF_INET, host, &ipv4) == 1 {
            return withUnsafeBytes(of: &ipv4) { isExternalIPv4(Array($0)) }
        }

        var ipv6 = in6_addr()
        if inet_pton(AF_INET6, host, &ipv6) == 1 {
            return withUnsafeBytes(of: &ipv6) { isExternalIPv6(Array($0)) }
        }

        return false
    }

    private static func isExternalIPv4(_ bytes: [UInt8]) -> Bool {
        let (a, b) = (bytes[0], bytes[1])
        switch a {
        case 0, 10, 127: return false
        case 100 where (64...127).contains(b): return false // Carrier-grade NAT
        case 169 where b == 254: return false // Link-local
        case 172 where (16...31).contains(b): return false
        case 192 where b == 168: return false
        case 224...255: return false // Multicast and reserved
        default: return true
        }
    }

    private static func isExternalIPv6(_ bytes: [UInt8]) -> Bool {
        if bytes[0..<10].allSatisfy({ $0 == 0 }), bytes[10] == 0xFF, bytes[11] == 0xFF {
            return isExternalIPv4(Array(bytes[12...])) // IPv4-mapped
        }
        if bytes[0..<15].allSatisfy({ $0 == 0 }), bytes[15] <= 1 { return false } // Unspecified and loopback
        if bytes[0] == 0xFE, bytes[1] & 0xC0 == 0x80 { return false } // Link-local
        if bytes[0] & 0xFE == 0xFC { return false } // Unique local
        if bytes[0] == 0xFF { return false } // Multicast
        return true
    }
}
