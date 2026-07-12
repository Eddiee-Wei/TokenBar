import AppKit
import Combine
import SwiftUI
import TokenBarCore

@main
struct TokenBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppServices {
    static let shared = AppServices()

    private(set) var model: TokenBarAppModel?
    private var statusItemController: StatusItemController?
    private var hotKeyMonitor: HotKeyMonitor?
    private var settingsWindowController: SettingsWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var didPresentCodexSetup = false
    private var lastHotKeyError: String?

    func start() {
        guard statusItemController == nil else { return }
        let model = TokenBarAppModel()
        self.model = model
        NSApp.setActivationPolicy(.accessory)

        let statusItemController = StatusItemController(
            model: model,
            openSettings: { [weak self] in self?.showSettings() }
        )
        self.statusItemController = statusItemController
        self.hotKeyMonitor = HotKeyMonitor(
            configuration: { [weak model] in model?.settings.hotKey ?? HotKeyConfiguration() },
            show: { [weak statusItemController] in statusItemController?.showPopover() },
            hide: { [weak statusItemController] in statusItemController?.closePopover() },
            registrationErrorMessage: { [weak model] status in
                model?.strings.shortcutRegistrationFailed(status)
                    ?? TokenBarStrings(.english).shortcutRegistrationFailed(status)
            },
            registrationChanged: { [weak self, weak model] error in
                guard let self else { return }
                if let error {
                    self.lastHotKeyError = error
                    model?.lastError = error
                } else if model?.lastError == self.lastHotKeyError {
                    model?.lastError = nil
                    self.lastHotKeyError = nil
                }
            }
        )
        self.hotKeyMonitor?.start()
        model.$settings.sink { [weak self] _ in
            DispatchQueue.main.async { self?.hotKeyMonitor?.reload() }
        }
        .store(in: &cancellables)
        model.$codexInstallationError
            .dropFirst()
            .sink { [weak self, weak model] error in
                guard error != nil else { return }
                DispatchQueue.main.async {
                    guard let self, let model, model.needsCodexSetup,
                          !self.didPresentCodexSetup else { return }
                    self.didPresentCodexSetup = true
                    self.showSettings(section: .codex)
                }
            }
            .store(in: &cancellables)

        if CommandLine.arguments.contains("--show-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak statusItemController] in
                NSApp.activate(ignoringOtherApps: true)
                statusItemController?.showPopover()
            }
        }
        if CommandLine.arguments.contains("--show-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.showSettings()
            }
        }
    }

    func showSettings(section: SettingsSection = .general) {
        guard let model else { return }
        statusItemController?.closePopover()
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(model: model)
        }
        settingsWindowController?.show(section: section)
    }

    func stop() {
        model?.shutdown()
        hotKeyMonitor?.stop()
        cancellables.removeAll()
        statusItemController = nil
        settingsWindowController = nil
        model = nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            guard !AppInstaller.installAndRelaunchIfNeeded() else { return }
            AppServices.shared.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in AppServices.shared.stop() }
    }
}
