import Domain
import Foundation
import Testing
@testable import Platform

struct NettopParserTests {
    private func fixture() throws -> String {
        let url = try #require(Bundle.module.url(forResource: "nettop-sample", withExtension: "txt", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func readsEveryProcessAndIgnoresBadLines() throws {
        let samples = NettopParser.parse(try fixture())
        #expect(samples.map(\.pid) == [1, 408, 507, 664, 70112])
    }

    @Test func readsCounters() throws {
        let samples = NettopParser.parse(try fixture())
        let chrome = try #require(samples.first { $0.pid == 70112 })
        #expect(chrome.bytesIn == 9_133_794)
        #expect(chrome.bytesOut == 752_807)
    }

    @Test func readsIPv4QuicAndIPv6Remotes() throws {
        let samples = NettopParser.parse(try fixture())
        let chrome = try #require(samples.first { $0.pid == 70112 })
        #expect(chrome.connections.contains(NetworkConnection(remoteAddress: "198.51.100.16", remotePort: 443)))
        #expect(chrome.connections.contains(NetworkConnection(remoteAddress: "198.51.100.27", remotePort: 443)))
        #expect(chrome.connections.contains(NetworkConnection(remoteAddress: "2001:db8:1::1", remotePort: 443)))
    }

    @Test func keepsIPv6ZoneForTheFilterToReject() throws {
        let samples = NettopParser.parse(try fixture())
        let chrome = try #require(samples.first { $0.pid == 70112 })
        let linkLocal = try #require(chrome.connections.first { $0.remoteAddress.hasPrefix("fe80") })
        #expect(linkLocal.remoteAddress == "fe80::944d:8048:2045:58f6%utun4")
        #expect(!ExternalAddressFilter.isExternal(linkLocal.remoteAddress))
    }

    @Test func listenersHaveNoRemoteConnection() throws {
        let samples = NettopParser.parse(try fixture())
        #expect(try #require(samples.first { $0.pid == 1 }).connections.isEmpty)
        #expect(try #require(samples.first { $0.pid == 507 }).connections.isEmpty)
    }

    @Test func onlyTheLatestReadingCounts() {
        let output = """
        ,bytes_in,bytes_out,
        app.5,10,20,
        ,bytes_in,bytes_out,
        app.5,30,40,
        """
        #expect(NettopParser.parse(output) == [NetworkSample(pid: 5, bytesIn: 30, bytesOut: 40, connections: [])])
    }

    @Test func emptyOutputGivesNoSamples() {
        #expect(NettopParser.parse("").isEmpty)
    }
}
