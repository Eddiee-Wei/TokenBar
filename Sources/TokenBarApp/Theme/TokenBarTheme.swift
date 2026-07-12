import AppKit
import SwiftUI
import TokenBarCore

enum TokenBarTheme {
    static let codexEmerald = Color(red: 0.06, green: 0.54, blue: 0.40)
    static let codexEmeraldSoft = Color(red: 0.23, green: 0.50, blue: 0.38)
    static let codexAmber = Color(red: 0.63, green: 0.47, blue: 0.15)
    static let codexOrange = Color(red: 0.72, green: 0.31, blue: 0.12)
    static let codexRed = Color(red: 0.70, green: 0.16, blue: 0.13)

    static func quotaColor(
        remainingPercent: Int?,
        configuration: QuotaColorConfiguration
    ) -> Color {
        guard let remainingPercent else { return .secondary }
        return color(configuration.color(forRemainingPercent: remainingPercent))
    }

    static func quotaGradient(
        remainingPercent: Int,
        configuration: QuotaColorConfiguration
    ) -> [Color] {
        configuration.gradient(forRemainingPercent: remainingPercent).map(color)
    }

    static func color(_ value: QuotaColor) -> Color {
        Color(red: value.red, green: value.green, blue: value.blue)
    }

    static func quotaColor(from color: Color) -> QuotaColor {
        guard let converted = NSColor(color).usingColorSpace(.sRGB) else {
            return QuotaColorConfiguration.defaultAbundant
        }
        return QuotaColor(
            red: Double(converted.redComponent),
            green: Double(converted.greenComponent),
            blue: Double(converted.blueComponent)
        )
    }

    static func statusColor(status: ProviderStatus, remainingPercent: Int?) -> Color {
        switch status {
        case .ok:
            return codexEmerald
        case .limited:
            return codexRed
        case .stale:
            return codexAmber
        case .unauthorized, .unsupported, .disabled:
            return .secondary
        case .error:
            return codexRed
        }
    }

    static var rail: Color {
        Color.primary.opacity(0.11)
    }

    static var divider: Color {
        Color.primary.opacity(0.11)
    }

    static var surface: Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.72)
    }

    static func rowBackground(remainingPercent: Int?, status: ProviderStatus) -> Color {
        Color(nsColor: .controlBackgroundColor).opacity(0.58)
    }

    static func rowStroke(remainingPercent: Int?, status: ProviderStatus) -> Color {
        Color.primary.opacity(0.11)
    }
}
