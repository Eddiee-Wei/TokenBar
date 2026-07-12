import AppKit
import Combine
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let model: TokenBarAppModel
    private let hostingController: NSHostingController<AnyView>
    private var cancellable: AnyCancellable?

    init(model: TokenBarAppModel) {
        self.model = model
        self.hostingController = NSHostingController(rootView: AnyView(
            SettingsView(model: model).frame(width: 680, height: 500)
        ))
        let window = NSWindow(contentViewController: hostingController)
        window.title = model.strings.text("TokenBar Settings", "TokenBar 设置")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 680, height: 500))
        window.center()
        super.init(window: window)
        window.delegate = self
        cancellable = model.$settings.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.window?.title = self.model.strings.text("TokenBar Settings", "TokenBar 设置")
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(section: SettingsSection = .general) {
        hostingController.rootView = AnyView(
            SettingsView(model: model, initialSection: section).frame(width: 680, height: 500)
        )
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
