import Darwin
import Domain

/// Looks up reverse-DNS names and remembers the answers for the session.
public actor CachingReverseDNSResolver: HostNameResolving {
    private static let cacheLimit = 2000
    private var cache: [String: String?] = [:]

    public init() {}

    public func hostName(forAddress address: String) async -> String? {
        if let cached = cache[address] { return cached }
        // getnameinfo blocks, so keep it off the actor.
        let name = await Task.detached(priority: .utility) { Self.lookUp(address) }.value
        if cache.count >= Self.cacheLimit { cache.removeAll() }
        cache[address] = .some(name)
        return name
    }

    private static func lookUp(_ address: String) -> String? {
        var ipv4 = sockaddr_in()
        ipv4.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        ipv4.sin_family = sa_family_t(AF_INET)
        if inet_pton(AF_INET, address, &ipv4.sin_addr) == 1 {
            return withUnsafePointer(to: &ipv4) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    nameInfo($0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }

        var ipv6 = sockaddr_in6()
        ipv6.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        ipv6.sin6_family = sa_family_t(AF_INET6)
        if inet_pton(AF_INET6, address, &ipv6.sin6_addr) == 1 {
            return withUnsafePointer(to: &ipv6) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    nameInfo($0, socklen_t(MemoryLayout<sockaddr_in6>.size))
                }
            }
        }
        return nil
    }

    private static func nameInfo(_ address: UnsafePointer<sockaddr>, _ length: socklen_t) -> String? {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let status = getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NAMEREQD)
        guard status == 0 else { return nil }
        return String(cString: host)
    }
}
