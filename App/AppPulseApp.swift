import AppKit
import Presentation
import SwiftUI

@main
struct AppPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = CompositionRoot.makeStore()
    private let quitUseCase = CompositionRoot.makeQuitUseCase()

    var body: some Scene {
        Window("AppPulse", id: "main") {
            RootView(store: store, quitUseCase: quitUseCase)
        }
        .defaultSize(width: 960, height: 680)
        // Closing the window quits the app, and macOS would otherwise restore that closed state:
        // the next launch showed no window at all.
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
    }
}

/// Window-only app, so closing the window ends it.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
