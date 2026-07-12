import AppKit
import Combine
import SwiftUI
import TokenBarCore

enum PopoverLayout {
    static let width: CGFloat = 360
    static let maximumHeight: CGFloat = 620
    static let maximumVisibleSnapshots = 6
    static let maximumListHeight: CGFloat = 450

    static func height(for update: QuotaProviderUpdate?) -> CGFloat {
        guard let update else { return 310 }
        let snapshots = update.snapshots.isEmpty ? update.snapshot.map { [$0] } ?? [] : update.snapshots
        guard !snapshots.isEmpty else { return 330 }

        let detailHeight: CGFloat = snapshots.contains { $0.detail?.isEmpty == false } ? 18 : 0
        let calculated = 266 + CGFloat(snapshots.count) * 48 + detailHeight
        return min(maximumHeight, max(330, calculated))
    }
}

@MainActor
final class StatusItemController: NSObject {
    private let model: TokenBarAppModel
    private let openSettings: () -> Void
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellable: AnyCancellable?
    private var eventMonitors: [Any] = []

    init(model: TokenBarAppModel, openSettings: @escaping () -> Void) {
        self.model = model
        self.openSettings = openSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = NSPopover()
        super.init()

        popover.behavior = .applicationDefined
        popover.contentSize = NSSize(
            width: PopoverLayout.width,
            height: PopoverLayout.height(for: model.updates[.codex])
        )
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(model: model, openSettings: openSettings)
                .frame(width: PopoverLayout.width)
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleProportionallyDown
        }
        updateButton()

        cancellable = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateButton()
            }
        }
        installOutsideClickMonitor()
    }

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        if !popover.isShown {
            updatePopoverSize()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }

    private func updateButton() {
        guard let button = statusItem.button else { return }
        let remaining = model.menuSnapshot?.remainingPercent
        button.image = BatteryStatusIcon.image(
            remainingPercent: remaining,
            colors: model.settings.quotaColors
        )
        button.title = " \(model.menuTitle)"
        button.toolTip = menuToolTip
        updatePopoverSize()
    }

    private var menuToolTip: String {
        let strings = model.strings
        guard let snapshot = model.menuSnapshot else {
            return "TokenBar · \(strings.connectingCodex)"
        }
        let quota = snapshot.quotaLabel ?? "Codex"
        return "\(quota) · \(strings.window(snapshot.windowLabel)) · \(strings.remaining(snapshot.remainingPercent ?? 0))"
    }

    private func updatePopoverSize() {
        popover.contentSize = NSSize(
            width: PopoverLayout.width,
            height: PopoverLayout.height(for: model.updates[.codex])
        )
    }

    private func installOutsideClickMonitor() {
        let mouseMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseMask, handler: { [weak self] _ in
            Task { @MainActor in
                guard let self, self.popover.isShown else { return }
                if self.clickIsOnPopoverScreen(NSEvent.mouseLocation) {
                    self.closePopover()
                }
            }
        }) {
            eventMonitors.append(globalMonitor)
        }

        if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseMask, handler: { [weak self] event in
            guard let self else { return event }
            guard self.popover.isShown else { return event }
            if event.window === self.popover.contentViewController?.view.window {
                return event
            }
            if self.localClickIsInStatusButton(event) {
                return event
            }
            if self.localClickIsOnPopoverScreen(event) {
                self.closePopover()
            }
            return event
        }) {
            eventMonitors.append(localMonitor)
        }
    }

    private func localClickIsInStatusButton(_ event: NSEvent) -> Bool {
        guard let button = statusItem.button, event.window === button.window else {
            return false
        }
        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        return buttonFrameInWindow.contains(event.locationInWindow)
    }

    private func localClickIsOnPopoverScreen(_ event: NSEvent) -> Bool {
        if let eventScreen = event.window?.screen, let popoverScreen {
            return eventScreen == popoverScreen
        }
        return clickIsOnPopoverScreen(NSEvent.mouseLocation)
    }

    private func clickIsOnPopoverScreen(_ point: NSPoint) -> Bool {
        guard let popoverScreen else { return true }
        return popoverScreen.frame.contains(point)
    }

    private var popoverScreen: NSScreen? {
        popover.contentViewController?.view.window?.screen
            ?? statusItem.button?.window?.screen
    }
}

private enum BatteryStatusIcon {
    static func image(
        remainingPercent: Int?,
        colors: QuotaColorConfiguration
    ) -> NSImage {
        let size = NSSize(width: 21, height: 12)
        let remaining = QuotaSnapshot.clampPercent(remainingPercent ?? 0)
        let fillValue = colors.color(forRemainingPercent: remaining)
        let fillColor = NSColor(
            red: fillValue.red,
            green: fillValue.green,
            blue: fillValue.blue,
            alpha: remainingPercent == nil ? 0.28 : 1
        )

        let image = NSImage(size: size, flipped: false) { _ in
            let outlineColor = NSColor.labelColor.withAlphaComponent(0.86)
            let bodyRect = NSRect(x: 0.75, y: 1.25, width: 17.25, height: 9.5)
            let body = NSBezierPath(roundedRect: bodyRect, xRadius: 2.1, yRadius: 2.1)
            body.lineWidth = 1.25
            outlineColor.setStroke()
            body.stroke()

            let terminal = NSBezierPath(
                roundedRect: NSRect(x: 18.65, y: 4.05, width: 1.8, height: 3.9),
                xRadius: 0.7,
                yRadius: 0.7
            )
            outlineColor.setFill()
            terminal.fill()

            if remaining > 0, remainingPercent != nil {
                let maximumWidth: CGFloat = 13.75
                let fillWidth = max(1.5, maximumWidth * CGFloat(remaining) / 100)
                let fill = NSBezierPath(
                    roundedRect: NSRect(x: 2.5, y: 3, width: fillWidth, height: 6),
                    xRadius: 1.15,
                    yRadius: 1.15
                )
                fillColor.setFill()
                fill.fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
