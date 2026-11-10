import Domain
import Testing
@testable import Platform

struct SignatureCheckerTests {
    @Test func appleSystemToolIsApple() {
        #expect(SecCodeSignatureChecker.check("/bin/ls") == .apple)
    }

    @Test func missingFileIsUnknown() {
        #expect(SecCodeSignatureChecker.check("/no/such/program") == .unknown)
    }

    @Test func plainTextFileIsUnsigned() {
        // A script has no signature of its own.
        #expect(SecCodeSignatureChecker.check("/etc/hosts") == .unsigned)
    }

    @Test(arguments: [
        ("Developer ID Application: Google LLC (EQHXZ8M8AV)", "Google LLC"),
        ("Apple Development: Jane Doe (ABCDE12345)", "Jane Doe"),
        ("Apple Mac OS Application Signing", "App Store"),
        ("Some Other Name", "Some Other Name"),
    ])
    func developerNameComesFromTheCertificate(summary: String, expected: String) {
        #expect(SecCodeSignatureChecker.developerName(fromCertificateSummary: summary) == expected)
    }
}
