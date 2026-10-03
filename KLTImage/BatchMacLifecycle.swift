import AppKit
import SwiftUI

@MainActor
final class BatchApplicationDelegate: NSObject, NSApplicationDelegate {
    static weak var activeBatch: BatchModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let batch = Self.activeBatch, batch.running else { return .terminateNow }
        batch.dismiss { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
}

struct BatchMacWindowGuard: NSViewRepresentable {
    let model: BatchModel
    let close: () -> Void
    func makeNSView(context: Context) -> GuardView { GuardView(model: model, close: close) }
    func updateNSView(_ nsView: GuardView, context: Context) {}
    @MainActor final class GuardView: NSView {
        let model: BatchModel
        let close: () -> Void
        init(model: BatchModel, close: @escaping () -> Void) {
            self.model = model; self.close = close
            super.init(frame: .zero); BatchApplicationDelegate.activeBatch = model
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidMoveToWindow() {
            NotificationCenter.default.removeObserver(self)
            if let window {
                NotificationCenter.default.addObserver(self, selector: #selector(windowClosed),
                                                       name: NSWindow.willCloseNotification, object: window)
            }
        }
        @objc private func windowClosed() { model.dismiss(close) }
        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
