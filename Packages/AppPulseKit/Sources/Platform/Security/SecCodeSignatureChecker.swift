import Domain
import Foundation
import Security

/// Checks program signatures with Apple's code-signing API, and remembers each answer for the session.
public actor SecCodeSignatureChecker: CodeSignatureChecking {
    private var cache: [String: CodeSigner] = [:]

    public init() {}

    public func signer(forPath path: String) async -> CodeSigner {
        if let cached = cache[path] { return cached }
        // Checking reads the file and can take tens of milliseconds, so keep it off the actor.
        let signer = await Task.detached(priority: .utility) { Self.check(path) }.value
        cache[path] = signer
        return signer
    }

    /// Created once. Matches only code signed by Apple itself.
    nonisolated(unsafe) private static let appleRequirement: SecRequirement? = {
        var requirement: SecRequirement?
        SecRequirementCreateWithString("anchor apple" as CFString, [], &requirement)
        return requirement
    }()

    static func check(_ path: String) -> CodeSigner {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode else { return .unknown }

        // The executable is checked against its signature. Bundle resources are skipped, as they are slow to hash.
        let flags = SecCSFlags(rawValue: kSecCSDoNotValidateResources)
        let status = SecStaticCodeCheckValidity(code, flags, nil)
        if status == errSecCSUnsigned { return .unsigned }
        guard status == errSecSuccess else { return .invalid }

        if let apple = appleRequirement, SecStaticCodeCheckValidity(code, flags, apple) == errSecSuccess {
            return .apple
        }

        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let info = information as? [String: Any] else { return .unknown }

        if let rawFlags = info[kSecCodeInfoFlags as String] as? UInt32,
           SecCodeSignatureFlags(rawValue: rawFlags).contains(.adhoc) {
            return .adHoc
        }
        if let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
           let leaf = certificates.first,
           let summary = SecCertificateCopySubjectSummary(leaf) as String? {
            return .developer(developerName(fromCertificateSummary: summary))
        }
        if let team = info[kSecCodeInfoTeamIdentifier as String] as? String {
            return .developer(team)
        }
        return .adHoc
    }

    /// Turns "Developer ID Application: Google LLC (EQHXZ8M8AV)" into "Google LLC".
    static func developerName(fromCertificateSummary summary: String) -> String {
        if summary.hasPrefix("Apple Mac OS Application Signing") { return "App Store" }
        var name = summary
        for prefix in ["Developer ID Application: ", "Apple Development: ", "Apple Distribution: ", "Mac Developer: "]
        where name.hasPrefix(prefix) {
            name.removeFirst(prefix.count)
        }
        if name.hasSuffix(")"), let open = name.lastIndex(of: "(") {
            name = String(name[..<open]).trimmingCharacters(in: .whitespaces)
        }
        return name.isEmpty ? summary : name
    }
}
