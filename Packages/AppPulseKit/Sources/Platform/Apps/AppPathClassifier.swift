/// Pure rules for reading an app bundle out of an executable path.
enum AppPathClassifier {
    /// The outermost `.app` in a path, so helpers nested inside an app count as that app.
    static func outermostAppBundle(in path: String) -> String? {
        var bundle = ""
        for component in path.split(separator: "/") {
            bundle += "/" + component
            if component.hasSuffix(".app") { return bundle }
        }
        return nil
    }

    /// Background parts of macOS ship as `.app` bundles too. Finder is the one users think of as an app.
    static func isSystemBundle(_ bundlePath: String) -> Bool {
        bundlePath.hasPrefix("/System/Library/") && !bundlePath.hasSuffix("/Finder.app")
    }
}
