import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        }
    }
}

public struct TokenBarStrings: Sendable {
    public let language: AppLanguage

    public init(_ language: AppLanguage) {
        self.language = language
    }

    public func text(_ english: String, _ chinese: String) -> String {
        language == .english ? english : chinese
    }

    public var general: String { text("General", "通用") }
    public var generalSubtitle: String {
        text("Launch, refresh, alerts, language, and shortcuts.", "启动、刷新、提醒、语言与快捷键。")
    }
    public var appearance: String { text("Appearance", "外观") }
    public var appearanceSubtitle: String {
        text("Customize quota progress colors.", "自定义额度进度条的颜色。")
    }
    public var codexSubtitle: String {
        text("Connect to the official local Codex quota source.", "连接 Codex 官方本机额度来源。")
    }
    public var privacy: String { text("Privacy", "隐私") }
    public var privacySubtitle: String {
        text("TokenBar's local data boundaries.", "TokenBar 的本地数据边界。")
    }

    public var system: String { text("System", "系统") }
    public var launchAtLogin: String { text("Launch at Login", "开机启动") }
    public var launchAtLoginDetail: String {
        text("Start TokenBar after signing in to macOS", "登录 macOS 后自动运行")
    }
    public var languageLabel: String { text("Language", "语言") }
    public var languageDetail: String {
        text("Choose TokenBar's display language", "选择 TokenBar 的显示语言")
    }
    public var refreshAndAlerts: String { text("Refresh & Alerts", "刷新与提醒") }
    public var refreshInterval: String { text("Refresh Interval", "刷新间隔") }
    public var refreshIntervalDetail: String {
        text("Sync official Codex quota in the background", "后台同步 Codex 官方额度")
    }
    public var quotaAlerts: String { text("Quota Alerts", "额度提醒") }
    public var quotaAlertsDetail: String {
        text("Send a notification below the threshold", "低于阈值时发送系统通知")
    }
    public var alertThreshold: String { text("Alert Threshold", "提醒阈值") }
    public var alertThresholdDetail: String {
        text("Notify once per quota window", "每个额度窗口仅提醒一次")
    }
    public var shortcuts: String { text("Shortcut", "快捷键") }
    public var holdToView: String { text("Hold to View", "按住查看") }
    public var holdToViewDetail: String {
        text("Release to close the popover", "松开后自动关闭浮窗")
    }
    public var currentShortcut: String { text("Current Shortcut", "当前快捷键") }
    public var defaultShortcut: String { text("Default: Command + E", "默认 Command + E") }
    public var pressShortcut: String { text("Press a shortcut", "请按下快捷键") }
    public var shortcutNeedsModifier: String {
        text("The shortcut must include at least one modifier key.", "快捷键至少需要一个修饰键。")
    }
    public func shortcutRegistrationFailed(_ status: Int32) -> String {
        text(
            "Shortcut registration failed (status \(status)). It may be used by another app.",
            "快捷键注册失败（状态码 \(status)），可能已被其他应用占用。"
        )
    }

    public var quotaColors: String { text("Quota Colors", "额度颜色") }
    public var highQuotaColor: String { text("High Quota Color", "高额度颜色") }
    public var highQuotaColorDetail: String {
        text("Progress color at 100% remaining", "剩余 100% 时的进度条颜色")
    }
    public var lowQuotaColor: String { text("Low Quota Color", "低额度颜色") }
    public var lowQuotaColorDetail: String {
        text("Progress color at 0% remaining", "剩余 0% 时的进度条颜色")
    }
    public var gradientPreview: String { text("Gradient Preview", "渐变预览") }
    public var quotaRemaining: String { text("Quota Remaining", "剩余额度") }

    public var connection: String { text("Connection", "连接") }
    public var codexStatus: String { text("Codex Status", "Codex 状态") }
    public var connected: String { text("Connected", "已连接") }
    public var quotaLow: String { text("Quota Low", "额度紧张") }
    public var signedOut: String { text("Signed Out", "未登录") }
    public var connectionError: String { text("Connection Error", "连接异常") }
    public var dataStale: String { text("Data Stale", "数据过期") }
    public var unsupportedVersion: String { text("Unsupported Version", "版本不支持") }
    public var disabled: String { text("Disabled", "已停用") }
    public var connecting: String { text("Connecting", "连接中") }
    public var readQuotaWindows: String {
        text("Read the 5-hour and 7-day quota windows", "读取 5 小时和 7 天额度窗口")
    }
    public var codexSource: String { text("Codex Source", "Codex 来源") }
    public var automaticDetection: String { text("Automatic Detection", "自动检测") }
    public var automaticDetectionDetail: String {
        text("Find the Codex app or CLI automatically", "自动寻找 Codex 应用或 CLI")
    }
    public var chooseApp: String { text("Choose App…", "选择应用…") }
    public var chooseCLI: String { text("Choose CLI…", "选择 CLI…") }
    public var change: String { text("Change…", "更换…") }
    public var detectAgain: String { text("Detect Again", "重新检测") }
    public var selectedApplication: String { text("Selected Application", "已选应用") }
    public var selectedCLI: String { text("Selected CLI", "已选 CLI") }
    public var noCodexSource: String { text("No Codex source found", "未找到 Codex 来源") }
    public var noCodexSourceDetail: String {
        text(
            "Install the Codex app or choose it from Applications.",
            "请安装 Codex 应用，或从“应用程序”中选择它。"
        )
    }
    public var validatingSource: String { text("Validating…", "正在验证…") }
    public var unsupportedClassicApp: String {
        text(
            "ChatGPT Classic does not include Codex CLI. Choose the current ChatGPT/Codex app instead.",
            "ChatGPT Classic 不包含 Codex CLI，请选择新版 ChatGPT/Codex 应用。"
        )
    }
    public var invalidCodexApp: String {
        text(
            "The selected app does not contain a supported Codex CLI.",
            "所选应用不包含受支持的 Codex CLI。"
        )
    }
    public var invalidCodexCLI: String {
        text("The selected file is not a valid Codex CLI.", "所选文件不是有效的 Codex CLI。")
    }
    public var sourceMissing: String {
        text("The selected Codex source is no longer available.", "已选择的 Codex 来源已不可用。")
    }
    public var requestTimeout: String { text("Request Timeout", "请求超时") }
    public var requestTimeoutDetail: String {
        text("Maximum wait when the connection is unhealthy", "连接异常时的最大等待时间")
    }
    public var officialLinks: String { text("Official Links", "官方入口") }
    public var codexUsage: String { text("Codex Usage", "Codex 用量") }
    public var codexUsageDetail: String {
        text("View complete usage in ChatGPT", "在 ChatGPT 中查看完整用量")
    }
    public var open: String { text("Open", "打开") }

    public var localFirst: String { text("Local Only", "本地优先") }
    public var privacyLocal: String {
        text("Quota data is processed only on this Mac.", "额度数据只在当前 Mac 上处理。")
    }
    public var privacyProtocol: String {
        text(
            "Uses only the official local Codex app-server protocol.",
            "只调用 Codex 官方本机 app-server 协议。"
        )
    }
    public var privacyNoContent: String {
        text(
            "Does not read prompts, code, browser cookies, or auth.json.",
            "不读取 prompt、代码、浏览器 Cookie 或 auth.json。"
        )
    }
    public var privacyNoUpload: String {
        text(
            "Does not upload quota data or include third-party analytics.",
            "不上传额度数据，也不包含第三方统计 SDK。"
        )
    }

    public var save: String { text("Save", "保存") }
    public var refreshNow: String { text("Refresh Now", "立即刷新") }
    public func minutes(_ value: Int) -> String { text("\(value) min", "\(value) 分钟") }
    public func seconds(_ value: Int) -> String { text("\(value) sec", "\(value) 秒") }

    public var liveHeader: String { text("CODEX // LIVE", "CODEX // 实时") }
    public var remainingHeader: String { text("REMAINING", "剩余") }
    public var refreshQuotaHelp: String { text("Refresh Codex quota", "刷新 Codex 额度") }
    public var connectingCodex: String { text("Connecting to Codex", "正在连接 Codex") }
    public var readingLocalQuota: String {
        text("Reading the local quota source.", "正在读取本机额度。")
    }
    public var localOfficial: String {
        text("Local only · Official sources first", "仅本地运行 · 官方来源优先")
    }
    public var settings: String { text("Settings", "设置") }
    public var waitingForQuota: String { text("Waiting for quota data", "等待额度数据") }
    public var officialLive: String { text("Official live data", "官方实时") }
    public var noQuotaSnapshot: String { text("No quota snapshot available.", "暂无额度快照。") }
    public var openUsagePage: String { text("Open Usage Page", "打开用量页") }
    public func planSummary(_ value: String?) -> String? {
        let plan: String?
        switch value {
        case "free": plan = "Free"
        case "go": plan = "Go"
        case "plus": plan = "Plus"
        case "pro": plan = "Pro"
        case "prolite": plan = "Pro Lite"
        case "team": plan = "Team"
        case "self_serve_business_usage_based", "business": plan = "Business"
        case "enterprise_cbp_usage_based", "enterprise": plan = "Enterprise"
        case "edu": plan = "Edu"
        case "unknown", nil: plan = nil
        case let value?: plan = value
        }
        return plan.map { text("\($0) plan", "\($0) 方案") }
    }
    public func popoverWindowTitle(quota: String?, window: String?) -> String {
        let quotaWindow: String
        let period: String
        switch window {
        case "5h":
            quotaWindow = text("5-hour quota", "5 小时额度")
            period = text("5 hours", "5 小时")
        case "7d":
            quotaWindow = text("Weekly quota", "每周额度")
            period = text("Weekly", "每周")
        case "24h":
            quotaWindow = text("Daily quota", "每日额度")
            period = text("Daily", "每日")
        case "month":
            quotaWindow = text("Monthly quota", "每月额度")
            period = text("Monthly", "每月")
        case let value?:
            quotaWindow = text("\(value) quota", "\(value) 额度")
            period = value
        case nil:
            quotaWindow = text("Quota", "额度")
            period = text("Quota", "额度")
        }

        guard let quota, quota.caseInsensitiveCompare("Codex") != .orderedSame else {
            return quotaWindow
        }
        return "\(quota) · \(period)"
    }
    public func remaining(_ percent: Int) -> String { text("\(percent)% remaining", "剩余 \(percent)%") }
    public func showInMenuBar(_ title: String) -> String {
        text("Show \(title) in the menu bar", "在菜单栏显示 \(title)")
    }
    public var selectedForMenuBar: String {
        text("Selected for the menu bar", "已选为菜单栏额度")
    }
    public var notSelectedForMenuBar: String {
        text("Not selected for the menu bar", "未选为菜单栏额度")
    }
    public var noResetTime: String { text("No reset time", "无重置时间") }
    public var reset: String { text("Reset", "已重置") }
    public func timeRemaining(days: Int, hours: Int, minutes: Int, includesDays: Bool) -> String {
        if includesDays {
            return text("\(days)d \(hours)h \(minutes)m left", "还剩 \(days)d \(hours)h \(minutes)m")
        }
        return text("\(days * 24 + hours)h \(minutes)m left", "还剩 \(days * 24 + hours)h \(minutes)m")
    }

    public func window(_ value: String?) -> String {
        switch value {
        case "5h": text("5 hours", "5 小时")
        case "7d": text("7 days", "7 天")
        case "24h": text("24 hours", "24 小时")
        case "month": text("This month", "本月")
        case let value?: value
        case nil: text("Quota", "额度")
        }
    }

    public func status(_ value: ProviderStatus) -> String {
        switch value {
        case .ok: text("Healthy", "正常")
        case .stale: text("Stale", "过期")
        case .limited: text("Low", "紧张")
        case .unauthorized: text("Unauthorized", "未授权")
        case .unsupported: text("Unsupported", "不支持")
        case .error: text("Error", "错误")
        case .disabled: text("Disabled", "已禁用")
        }
    }

    public func freshness(_ value: SourceFreshness) -> String {
        switch value {
        case .live: text("Live", "实时")
        case .cached: text("Cached", "缓存")
        case .unavailable: text("Unavailable", "不可用")
        }
    }

    public func confidence(_ value: SnapshotConfidence) -> String {
        switch value {
        case .high: text("High confidence", "高可信")
        case .medium: text("Medium confidence", "中可信")
        case .low: text("Low confidence", "低可信")
        }
    }

    public var quotaAlertTitle: String { text("Codex Quota Alert", "Codex 额度提醒") }
    public func quotaAlertBody(name: String, remaining: Int) -> String {
        text("\(name): \(remaining)% remaining", "\(name)剩余 \(remaining)%")
    }
    public func quotaDisplayName(quota: String?, window: String?) -> String {
        let quotaPrefix = quota.map { "\($0) " } ?? ""
        let windowName: String
        switch window {
        case "5h": windowName = text("5-hour quota", "5 小时额度")
        case "7d": windowName = text("7-day quota", "7 天额度")
        case let value?: windowName = text("\(value) quota", "\(value) 额度")
        case nil: windowName = text("quota", "额度")
        }
        return quotaPrefix + windowName
    }

    public var notificationPermissionDenied: String {
        text(
            "Notifications are disabled. Allow TokenBar in System Settings → Notifications.",
            "通知权限未开启，请在系统设置 → 通知中允许 TokenBar。"
        )
    }
    public var launchAtLoginRequiresInstall: String {
        text(
            "Install TokenBar in Applications before enabling Launch at Login.",
            "请先把 TokenBar 安装到应用程序目录，再启用开机启动。"
        )
    }

    public var installFailedTitle: String { text("Unable to Install TokenBar", "无法安装 TokenBar") }
    public func installFailedDetail(_ error: String) -> String {
        text(
            "Move TokenBar to Applications and open it again.\n\n\(error)",
            "请把 TokenBar 拖到“应用程序”后再打开。\n\n\(error)"
        )
    }
    public var ok: String { text("OK", "好") }
    public var invalidApplication: String {
        text(
            "TokenBar.app in the installer is incomplete or has an invalid identifier.",
            "安装包中的 TokenBar.app 不完整或标识不匹配。"
        )
    }

    public func additionalCredits(balance: String?, unlimited: Bool, resetCount: Int?) -> String? {
        var parts: [String] = []
        if unlimited {
            parts.append(text("Unlimited additional credits", "附加 credits 不限量"))
        } else if let balance {
            parts.append(text("Additional credits \(balance)", "附加 credits \(balance)"))
        }
        if let resetCount {
            parts.append(text("\(resetCount) quota resets", "\(resetCount) 次额度重置"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public func reachedLimitReason(_ value: String?) -> String? {
        switch value {
        case "rate_limit_reached": text("Current quota limit reached", "已达到当前额度上限")
        case "workspace_owner_credits_depleted": text("Workspace credits depleted", "工作区 credits 已用完")
        case "workspace_member_credits_depleted": text("Member credits depleted", "成员 credits 已用完")
        case "workspace_owner_usage_limit_reached": text("Workspace usage limit reached", "工作区用量上限已达到")
        case "workspace_member_usage_limit_reached": text("Member usage limit reached", "成员用量上限已达到")
        case let value?: value
        case nil: nil
        }
    }
}
