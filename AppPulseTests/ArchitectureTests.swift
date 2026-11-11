import Foundation
import Testing

/// All layers share one module, so the compiler cannot keep them apart.
/// This test reads the source folders and fails when a layer uses a type from a layer it must not depend on.
struct ArchitectureTests {
    private static let layerPaths: [String: [String]] = [
        "Domain": ["Core/Domain"],
        "Application": ["Core/Application"],
        "Platform": ["Core/Platform"],
        "Presentation": ["Features", "Shared", "App/RootView.swift"],
    ]

    private static let allowedDependencies: [String: Set<String>] = [
        "Domain": [],
        "Application": ["Domain"],
        "Platform": ["Domain"],
        "Presentation": ["Application", "Domain"],
    ]

    private static var appFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AppPulse")
    }

    private static func swiftFiles(in layer: String) throws -> [URL] {
        var files: [URL] = []
        for path in layerPaths[layer, default: []] {
            let url = appFolder.appendingPathComponent(path)
            if url.pathExtension == "swift" {
                files.append(url)
                continue
            }
            let found = try #require(FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil))
            for case let file as URL in found where file.pathExtension == "swift" {
                files.append(file)
            }
        }
        return files
    }

    /// Source text with `//` comments removed, so a type named in a comment does not count as a use.
    private static func code(of file: URL) throws -> String {
        let text = try String(contentsOf: file, encoding: .utf8)
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in line.range(of: "//").map { String(line[..<$0.lowerBound]) } ?? String(line) }
            .joined(separator: "\n")
    }

    private static func identifiers(in code: String) -> Set<String> {
        Set(code.split { !($0.isLetter || $0.isNumber || $0 == "_") }.map(String.init))
    }

    /// Names of the types declared at the top level of a layer.
    private static func declaredTypes(in layer: String) throws -> Set<String> {
        let keywords: Set<Substring> = ["struct", "class", "enum", "protocol", "actor", "typealias"]
        var names: Set<String> = []
        for file in try swiftFiles(in: layer) {
            for line in try code(of: file).split(separator: "\n") where !(line.first?.isWhitespace ?? true) {
                let words = line.split(separator: " ")
                guard let index = words.firstIndex(where: keywords.contains), index + 1 < words.count else { continue }
                let name = words[index + 1].prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                if !name.isEmpty { names.insert(String(name)) }
            }
        }
        return names
    }

    @Test(arguments: ["Domain", "Application", "Platform", "Presentation"])
    func layerOnlyUsesWhatItMay(layer: String) throws {
        let allowed = Self.allowedDependencies[layer, default: []]
        var forbidden: [String: String] = [:]
        for other in Self.layerPaths.keys where other != layer && !allowed.contains(other) {
            for name in try Self.declaredTypes(in: other) { forbidden[name] = other }
        }

        for file in try Self.swiftFiles(in: layer) {
            for name in Self.identifiers(in: try Self.code(of: file)) {
                if let other = forbidden[name] {
                    #expect(Bool(false), "\(layer)/\(file.lastPathComponent) must not use \(other) type \(name)")
                }
            }
        }
    }

    @Test func domainHasNoFrameworkDependencies() throws {
        for file in try Self.swiftFiles(in: "Domain") {
            let text = try Self.code(of: file)
            for framework in ["SwiftUI", "AppKit", "IOKit"] {
                #expect(!text.contains("import \(framework)"), "Domain/\(file.lastPathComponent) must not import \(framework)")
            }
        }
    }

    @Test func everyLayerHasSources() throws {
        for layer in Self.layerPaths.keys {
            #expect(try !Self.swiftFiles(in: layer).isEmpty, "\(layer) has no Swift files; check layerPaths")
        }
    }
}
