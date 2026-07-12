import AppKit
import SwiftUI
import TokenBarCore
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var model: TokenBarAppModel
    @State private var isRecordingHotKey = false
    @State private var keyRecorder: Any?
    @State private var selectedSection: SettingsSection

    init(model: TokenBarAppModel, initialSection: SettingsSection = .general) {
        self.model = model
        _selectedSection = State(initialValue: initialSection)
    }

    private var strings: TokenBarStrings { model.strings }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle()
                .fill(TokenBarTheme.divider)
                .frame(width: 1)
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear { stopHotKeyRecording() }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundStyle(TokenBarTheme.codexEmerald)
                Text("TokenBar")
                    .font(.headline.weight(.semibold))
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)

            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title(strings), systemImage: section.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            selectedSection == section ? TokenBarTheme.codexEmerald.opacity(0.11) : .clear,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedSection == section ? TokenBarTheme.codexEmerald : .primary)
            }
            Spacer()
        }
        .padding(16)
        .frame(width: 166, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.42))
    }

    private var content: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedSection.title(strings))
                            .font(.title3.weight(.semibold))
                        Text(selectedSection.subtitle(strings))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    switch selectedSection {
                    case .general: generalContent
                    case .appearance: appearanceContent
                    case .codex: codexContent
                    case .privacy: privacyContent
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Rectangle()
                .fill(TokenBarTheme.divider)
                .frame(height: 1)

            actionBar
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var generalContent: some View {
        VStack(spacing: 14) {
            settingsGroup(strings.system) {
                settingsRow(strings.languageLabel, detail: strings.languageDetail) {
                    Picker("", selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 132)
                }
                settingsDivider
                settingsRow(strings.launchAtLogin, detail: strings.launchAtLoginDetail) {
                    Toggle("", isOn: $model.settings.launchAtLogin)
                        .labelsHidden()
                }
            }

            settingsGroup(strings.refreshAndAlerts) {
                settingsRow(strings.refreshInterval, detail: strings.refreshIntervalDetail) {
                    intervalControl
                }
                settingsDivider
                settingsRow(strings.quotaAlerts, detail: strings.quotaAlertsDetail) {
                    Toggle("", isOn: $model.settings.notificationsEnabled)
                        .labelsHidden()
                }
                settingsDivider
                settingsRow(strings.alertThreshold, detail: strings.alertThresholdDetail) {
                    thresholdControl
                        .disabled(!model.settings.notificationsEnabled)
                        .opacity(model.settings.notificationsEnabled ? 1 : 0.45)
                }
            }

            settingsGroup(strings.shortcuts) {
                settingsRow(strings.holdToView, detail: strings.holdToViewDetail) {
                    Toggle("", isOn: $model.settings.hotKey.isEnabled)
                        .labelsHidden()
                }
                settingsDivider
                settingsRow(strings.currentShortcut, detail: strings.defaultShortcut) {
                    Button(isRecordingHotKey ? strings.pressShortcut : model.settings.hotKey.displayName) {
                        startHotKeyRecording()
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var codexContent: some View {
        VStack(spacing: 14) {
            settingsGroup(strings.connection) {
                settingsRow(strings.codexStatus, detail: codexStatusDetail) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(codexStatusColor)
                            .frame(width: 7, height: 7)
                        Text(codexStatusTitle)
                            .font(.callout.weight(.medium))
                    }
                }
                settingsDivider
                settingsRow(strings.codexSource, detail: codexSourceDetail) {
                    HStack(spacing: 8) {
                        if model.isResolvingCodexSource {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(codexSourceTitle)
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                        Button(strings.change) {
                            chooseCodexApplication()
                        }
                        .controlSize(.small)
                    }
                }
                settingsDivider
                settingsRow(strings.requestTimeout, detail: strings.requestTimeoutDetail) {
                    timeoutControl
                }

                if let error = model.codexInstallationErrorMessage {
                    settingsDivider
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(TokenBarTheme.codexRed)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
            }

            HStack(spacing: 10) {
                Button {
                    chooseCodexApplication()
                } label: {
                    Label(strings.chooseApp, systemImage: "app.badge.checkmark")
                }
                Button {
                    Task { await model.detectCodexAgain() }
                } label: {
                    Label(strings.detectAgain, systemImage: "arrow.clockwise")
                }
                .disabled(model.isResolvingCodexSource)

                Menu {
                    Button(strings.chooseCLI) { chooseCodexExecutable() }
                } label: {
                    Label(strings.text("Advanced", "高级"), systemImage: "ellipsis.circle")
                }
                Spacer()
            }

            settingsGroup(strings.officialLinks) {
                settingsRow(strings.codexUsage, detail: strings.codexUsageDetail) {
                    Button {
                        model.openCodexUsagePage()
                    } label: {
                        Label(strings.open, systemImage: "arrow.up.right.square")
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var appearanceContent: some View {
        VStack(spacing: 14) {
            settingsGroup(strings.quotaColors) {
                settingsRow(strings.highQuotaColor, detail: strings.highQuotaColorDetail) {
                    ColorPicker("", selection: abundantColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 38)
                }
                settingsDivider
                settingsRow(strings.lowQuotaColor, detail: strings.lowQuotaColorDetail) {
                    ColorPicker("", selection: depletedColor, supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 38)
                }
            }

            settingsGroup(strings.gradientPreview) {
                VStack(spacing: 8) {
                    LinearGradient(
                        colors: colorPreviewStops,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 10)
                    .clipShape(Capsule())

                    HStack {
                        Text("0%")
                        Spacer()
                        Text(strings.quotaRemaining)
                        Spacer()
                        Text("100%")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 14)
            }
        }
    }

    private var privacyContent: some View {
        VStack(spacing: 14) {
            settingsGroup(strings.localFirst) {
                privacyRow(strings.privacyLocal)
                settingsDivider
                privacyRow(strings.privacyProtocol)
                settingsDivider
                privacyRow(strings.privacyNoContent)
                settingsDivider
                privacyRow(strings.privacyNoUpload)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(strings.save) { model.saveSettings() }
                .keyboardShortcut(.defaultAction)
            Button {
                Task { await model.refreshAll() }
            } label: {
                Label(strings.refreshNow, systemImage: "arrow.clockwise")
            }
            .disabled(model.isRefreshing)

            if let error = model.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(TokenBarTheme.codexRed)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var intervalControl: some View {
        HStack(spacing: 8) {
            Text(strings.minutes(Int(model.settings.refreshIntervalSeconds / 60)))
                .font(.callout.monospacedDigit())
                .frame(width: 62, alignment: .trailing)
            Stepper("", value: $model.settings.refreshIntervalSeconds, in: 60...3600, step: 60)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(width: 114, alignment: .trailing)
    }

    private var thresholdControl: some View {
        HStack(spacing: 8) {
            Text("\(model.settings.notificationThresholdPercent)%")
                .font(.callout.monospacedDigit())
                .frame(width: 62, alignment: .trailing)
            Stepper("", value: $model.settings.notificationThresholdPercent, in: 1...100, step: 1)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(width: 114, alignment: .trailing)
    }

    private var timeoutControl: some View {
        HStack(spacing: 8) {
            Text(strings.seconds(Int(model.settings.codex.timeoutSeconds)))
                .font(.callout.monospacedDigit())
                .frame(width: 62, alignment: .trailing)
            Stepper("", value: $model.settings.codex.timeoutSeconds, in: 2...30, step: 1)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(width: 114, alignment: .trailing)
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { model.settings.language },
            set: { model.setLanguage($0) }
        )
    }

    private var abundantColor: Binding<Color> {
        Binding(
            get: { TokenBarTheme.color(model.settings.quotaColors.abundant) },
            set: { model.settings.quotaColors.abundant = TokenBarTheme.quotaColor(from: $0) }
        )
    }

    private var depletedColor: Binding<Color> {
        Binding(
            get: { TokenBarTheme.color(model.settings.quotaColors.depleted) },
            set: { model.settings.quotaColors.depleted = TokenBarTheme.quotaColor(from: $0) }
        )
    }

    private var colorPreviewStops: [Color] {
        stride(from: 0, through: 100, by: 10).map {
            TokenBarTheme.color(model.settings.quotaColors.color(forRemainingPercent: $0))
        }
    }

    private var codexStatusTitle: String {
        switch model.updates[.codex]?.status {
        case .ok: strings.connected
        case .limited: strings.quotaLow
        case .unauthorized: strings.signedOut
        case .error: strings.connectionError
        case .stale: strings.dataStale
        case .unsupported: strings.unsupportedVersion
        case .disabled: strings.disabled
        case nil: strings.connecting
        }
    }

    private var codexStatusDetail: String {
        model.updates[.codex]?.message ?? strings.readQuotaWindows
    }

    private var codexSourceTitle: String {
        guard let installation = model.resolvedInstallation else {
            return model.isResolvingCodexSource ? strings.validatingSource : strings.noCodexSource
        }
        return installation.displayName
    }

    private var codexSourceDetail: String {
        guard let installation = model.resolvedInstallation else {
            return model.codexInstallationErrorMessage ?? strings.automaticDetectionDetail
        }
        let location = installation.applicationURL?.path ?? installation.executableURL.path
        var versions: [String] = []
        if let version = installation.applicationVersion {
            versions.append("v\(version)")
        }
        versions.append(installation.cliVersion)
        return "\(location)\n\(versions.joined(separator: " · "))"
    }

    private var codexStatusColor: Color {
        TokenBarTheme.statusColor(
            status: model.updates[.codex]?.status ?? .stale,
            remainingPercent: model.updates[.codex]?.snapshot?.remainingPercent
        )
    }

    @ViewBuilder
    private func settingsGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
                .padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .padding(.horizontal, 14)
                .background(TokenBarTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(TokenBarTheme.divider, lineWidth: 1)
                }
        }
    }

    private func settingsRow<Trailing: View>(
        _ title: String,
        detail: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 18)
            trailing()
        }
        .frame(minHeight: 52)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(TokenBarTheme.divider)
            .frame(height: 1)
    }

    private func privacyRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(TokenBarTheme.codexEmerald)
            Text(text).font(.callout)
            Spacer()
        }
        .frame(minHeight: 42)
    }

    private func startHotKeyRecording() {
        stopHotKeyRecording()
        isRecordingHotKey = true
        keyRecorder = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopHotKeyRecording()
                return nil
            }

            let flags = event.modifierFlags
            let hasModifier = flags.contains(.command)
                || flags.contains(.option)
                || flags.contains(.control)
                || flags.contains(.shift)
            guard hasModifier else {
                model.lastError = strings.shortcutNeedsModifier
                stopHotKeyRecording()
                return nil
            }

            model.settings.hotKey = HotKeyConfiguration(
                keyCode: UInt16(event.keyCode),
                command: flags.contains(.command),
                option: flags.contains(.option),
                control: flags.contains(.control),
                shift: flags.contains(.shift)
            )
            model.saveSettings()
            stopHotKeyRecording()
            return nil
        }
    }

    private func stopHotKeyRecording() {
        if let keyRecorder { NSEvent.removeMonitor(keyRecorder) }
        keyRecorder = nil
        isRecordingHotKey = false
    }

    private func chooseCodexApplication() {
        let panel = NSOpenPanel()
        panel.title = strings.chooseApp
        panel.prompt = strings.text("Choose", "选择")
        panel.message = strings.text(
            "Choose the current ChatGPT or Codex application.",
            "请选择新版 ChatGPT 或 Codex 应用。"
        )
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.selectCodexApplication(url) }
    }

    private func chooseCodexExecutable() {
        let panel = NSOpenPanel()
        panel.title = strings.chooseCLI
        panel.prompt = strings.text("Choose", "选择")
        panel.message = strings.text(
            "Advanced: choose a standalone Codex CLI executable.",
            "高级选项：选择独立安装的 Codex CLI 可执行文件。"
        )
        panel.allowedContentTypes = [.unixExecutable]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await model.selectCodexExecutable(url) }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case appearance
    case codex
    case privacy

    var id: String { rawValue }

    func title(_ strings: TokenBarStrings) -> String {
        switch self {
        case .general: strings.general
        case .appearance: strings.appearance
        case .codex: "Codex"
        case .privacy: strings.privacy
        }
    }

    func subtitle(_ strings: TokenBarStrings) -> String {
        switch self {
        case .general: strings.generalSubtitle
        case .appearance: strings.appearanceSubtitle
        case .codex: strings.codexSubtitle
        case .privacy: strings.privacySubtitle
        }
    }

    var systemImage: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .appearance: "paintpalette"
        case .codex: "terminal"
        case .privacy: "lock"
        }
    }
}

private extension HotKeyConfiguration {
    var displayName: String {
        var parts: [String] = []
        if control { parts.append("⌃") }
        if option { parts.append("⌥") }
        if shift { parts.append("⇧") }
        if command { parts.append("⌘") }
        parts.append(KeyCodeName.name(for: keyCode))
        return parts.joined()
    }
}

private enum KeyCodeName {
    static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }

    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
        50: "`", 51: "Delete", 53: "Esc", 96: "F5", 97: "F6", 98: "F7",
        99: "F3", 100: "F8", 101: "F9", 103: "F11", 109: "F10",
        111: "F12", 118: "F4", 122: "F1", 120: "F2"
    ]
}
