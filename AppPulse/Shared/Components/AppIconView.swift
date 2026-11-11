import AppKit
import SwiftUI

/// An app's real icon, or a quiet tile for the system row.
struct AppIconView: View {
    let bundlePath: String?
    let size: CGFloat

    var body: some View {
        if let bundlePath {
            Image(nsImage: AppIconCache.icon(forPath: bundlePath, size: size))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "gearshape.2")
                .font(.system(size: size * 0.5))
                .foregroundStyle(Theme.stone.readable)
                .frame(width: size, height: size)
                .background(Theme.stone.opacity(0.16), in: RoundedRectangle(cornerRadius: size / 4, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}

/// Icons are drawn once at display size. Rescaling the full-size icon on each redraw was this app's largest CPU cost.
@MainActor
private enum AppIconCache {
    private static let retinaScale: CGFloat = 2
    private static var icons: [String: NSImage] = [:]

    static func icon(forPath path: String, size: CGFloat) -> NSImage {
        let key = "\(size)|\(path)"
        if let icon = icons[key] { return icon }
        let source = NSWorkspace.shared.icon(forFile: path)
        let icon = rendered(source, size: size) ?? source
        icons[key] = icon
        return icon
    }

    private static func rendered(_ source: NSImage, size: CGFloat) -> NSImage? {
        let pixels = Int(size * retinaScale)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        // Must be set before the context is made, or the context draws in pixels instead of points.
        let imageSize = NSSize(width: size, height: size)
        bitmap.size = imageSize
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(in: NSRect(origin: .zero, size: imageSize))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: imageSize)
        image.addRepresentation(bitmap)
        return image
    }
}
