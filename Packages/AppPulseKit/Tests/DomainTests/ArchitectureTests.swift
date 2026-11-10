import Foundation
import Testing

/// SwiftPM lets a target import any module already built, so the compiler alone does not enforce the layers.
struct ArchitectureTests {
    private static let projectModules: Set<String> = ["Domain", "Application", "Platform", "Presentation"]

    private static let allowedImports: [String: Set<String>] = [
        "Domain": [],
        "Application": ["Domain"],
        "Platform": ["Domain"],
        "Presentation": ["Application", "Domain"],
    ]

    private static var sourcesFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources")
    }

    private static func projectImports(in layer: String) throws -> [(file: String, module: String)] {
        let folder = sourcesFolder.appendingPathComponent(layer)
        let files = try #require(FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil))
        var found: [(file: String, module: String)] = []

        for case let file as URL in files where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for line in text.split(whereSeparator: \.isNewline) {
                let words = line.split(separator: " ")
                guard let index = words.firstIndex(of: "import"), index + 1 < words.count else { continue }
                let module = String(words[index + 1])
                if projectModules.contains(module) {
                    found.append((file.lastPathComponent, module))
                }
            }
        }
        return found
    }

    @Test(arguments: ["Domain", "Application", "Platform", "Presentation"])
    func layerOnlyImportsWhatItMay(layer: String) throws {
        let allowed = Self.allowedImports[layer, default: []]
        for (file, module) in try Self.projectImports(in: layer) {
            #expect(allowed.contains(module), "\(layer)/\(file) must not import \(module)")
        }
    }

    @Test func domainHasNoFrameworkDependencies() throws {
        let folder = Self.sourcesFolder.appendingPathComponent("Domain")
        let files = try #require(FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil))
        for case let file as URL in files where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for framework in ["SwiftUI", "AppKit", "IOKit"] {
                #expect(!text.contains("import \(framework)"), "Domain/\(file.lastPathComponent) must not import \(framework)")
            }
        }
    }
}
