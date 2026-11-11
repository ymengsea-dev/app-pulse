import Testing
@testable import AppPulse

struct ExternalAddressFilterTests {
    @Test(arguments: [
        "8.8.8.8", "203.0.113.10", "172.32.0.1", "100.128.0.1", "2606:4700:4700::1111", "::ffff:8.8.8.8",
    ])
    func publicAddressesAreExternal(address: String) {
        #expect(ExternalAddressFilter.isExternal(address))
    }

    @Test(arguments: [
        "127.0.0.1", "10.0.0.1", "172.16.0.1", "172.31.255.255", "192.168.1.1", "169.254.1.1", "100.64.0.1",
        "224.0.0.251", "0.0.0.0", "255.255.255.255",
        "::", "::1", "fe80::1", "fe80::1%utun4", "fd00::1", "ff02::fb", "::ffff:192.168.1.1",
        "*", "not an address", "",
    ])
    func localAndInvalidAddressesAreNotExternal(address: String) {
        #expect(!ExternalAddressFilter.isExternal(address))
    }
}
