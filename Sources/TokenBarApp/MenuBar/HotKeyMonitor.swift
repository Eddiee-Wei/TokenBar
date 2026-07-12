import AppKit
import Carbon
import TokenBarCore

@MainActor
final class HotKeyMonitor {
    private let configuration: () -> HotKeyConfiguration
    private let show: () -> Void
    private let hide: () -> Void
    private let registrationErrorMessage: (Int32) -> String
    private let registrationChanged: (String?) -> Void
    private var monitors: [Any] = []
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var registeredHotKey: HotKeyConfiguration?
    private var isHeld = false

    init(
        configuration: @escaping () -> HotKeyConfiguration,
        show: @escaping () -> Void,
        hide: @escaping () -> Void,
        registrationErrorMessage: @escaping (Int32) -> String = {
            "Shortcut registration failed (status \($0)). It may be used by another app."
        },
        registrationChanged: @escaping (String?) -> Void = { _ in }
    ) {
        self.configuration = configuration
        self.show = show
        self.hide = hide
        self.registrationErrorMessage = registrationErrorMessage
        self.registrationChanged = registrationChanged
    }

    func start() {
        stop()
        installCarbonHandler()
        reload()

        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }) {
            monitors.append(monitor)
        }

        if let localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            guard let self else { return event }
            return self.handleLocal(event)
        }) {
            monitors.append(localMonitor)
        }
    }

    func reload() {
        registerCarbonHotKey(configuration())
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        unregisterCarbonHotKey()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        isHeld = false
    }

    private func installCarbonHandler() {
        guard eventHandlerRef == nil else { return }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let monitor = Unmanaged<HotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                let kind = GetEventKind(event)
                Task { @MainActor in
                    if kind == UInt32(kEventHotKeyPressed) {
                        monitor.carbonPressed()
                    } else if kind == UInt32(kEventHotKeyReleased) {
                        monitor.carbonReleased()
                    }
                }
                return noErr
            },
            eventTypes.count,
            &eventTypes,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func registerCarbonHotKey(_ hotKey: HotKeyConfiguration) {
        guard hotKey.isEnabled else {
            unregisterCarbonHotKey()
            registeredHotKey = nil
            registrationChanged(nil)
            return
        }
        guard registeredHotKey != hotKey else { return }

        unregisterCarbonHotKey()

        let hotKeyID = EventHotKeyID(signature: fourCharCode("TBar"), id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(hotKey.keyCode),
            carbonModifiers(for: hotKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr {
            hotKeyRef = ref
            registeredHotKey = hotKey
            registrationChanged(nil)
        } else {
            hotKeyRef = nil
            registeredHotKey = nil
            registrationChanged(registrationErrorMessage(status))
        }
    }

    private func unregisterCarbonHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func carbonPressed() {
        guard configuration().isEnabled else { return }
        if !isHeld {
            isHeld = true
            show()
        }
    }

    private func carbonReleased() {
        guard isHeld else { return }
        release()
    }

    private func handleLocal(_ event: NSEvent) -> NSEvent? {
        let consumed = handle(event)
        return consumed ? nil : event
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        let hotKey = configuration()
        guard hotKey.isEnabled else {
            if isHeld { release() }
            return false
        }

        switch event.type {
        case .keyDown:
            guard matches(event, hotKey: hotKey) else { return false }
            if !isHeld {
                isHeld = true
                show()
            }
            return true
        case .keyUp:
            guard isHeld, UInt16(event.keyCode) == hotKey.keyCode else { return false }
            release()
            return true
        case .flagsChanged:
            if isHeld && !modifiersMatch(event.modifierFlags, hotKey: hotKey) {
                release()
            }
            return false
        default:
            return false
        }
    }

    private func release() {
        isHeld = false
        hide()
    }

    private func matches(_ event: NSEvent, hotKey: HotKeyConfiguration) -> Bool {
        UInt16(event.keyCode) == hotKey.keyCode && modifiersMatch(event.modifierFlags, hotKey: hotKey)
    }

    private func modifiersMatch(_ flags: NSEvent.ModifierFlags, hotKey: HotKeyConfiguration) -> Bool {
        flags.contains(.command) == hotKey.command
            && flags.contains(.option) == hotKey.option
            && flags.contains(.control) == hotKey.control
            && flags.contains(.shift) == hotKey.shift
    }

    private func carbonModifiers(for hotKey: HotKeyConfiguration) -> UInt32 {
        var modifiers: UInt32 = 0
        if hotKey.command { modifiers |= UInt32(cmdKey) }
        if hotKey.option { modifiers |= UInt32(optionKey) }
        if hotKey.control { modifiers |= UInt32(controlKey) }
        if hotKey.shift { modifiers |= UInt32(shiftKey) }
        return modifiers
    }

    private func fourCharCode(_ value: String) -> OSType {
        var result: UInt32 = 0
        for scalar in value.unicodeScalars.prefix(4) {
            result = (result << 8) + scalar.value
        }
        return result
    }
}
