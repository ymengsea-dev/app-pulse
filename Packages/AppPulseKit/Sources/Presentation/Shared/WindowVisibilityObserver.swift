import AppKit
import SwiftUI

/// Reports whether the window can be seen. Covers minimized, hidden, and fully covered windows.
struct WindowVisibilityObserver: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ObserverView {
        ObserverView(onChange: onChange)
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onChange = onChange
    }

    final class ObserverView: NSView {
        var onChange: (Bool) -> Void
        private var lastReported: Bool?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard let window else { return }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(occlusionChanged),
                name: NSWindow.didChangeOcclusionStateNotification,
                object: window
            )
            report()
        }

        @objc private func occlusionChanged() {
            report()
        }

        private func report() {
            guard let window else { return }
            let isVisible = window.occlusionState.contains(.visible)
            guard isVisible != lastReported else { return }
            lastReported = isVisible
            onChange(isVisible)
        }
    }
}
