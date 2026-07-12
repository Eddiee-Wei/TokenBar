import Foundation
import TokenBarCore

@main
struct TokenBarCLI {
    static func main() async {
        let settings = (try? JSONSettingsStore().load()) ?? TokenBarSettings()
        let strings = TokenBarStrings(settings.language)
        switch CommandLine.arguments.dropFirst().first {
        case "refresh":
            await refresh(settings: settings, strings: strings)
        case "paths":
            print("Application Support: \(TokenBarPaths.applicationSupportDirectory.path)")
            print("\(strings.text("Settings file", "设置文件")): \(TokenBarPaths.settingsFile.path)")
        default:
            printUsage(strings: strings)
        }
    }

    private static func refresh(settings: TokenBarSettings, strings: TokenBarStrings) async {
        let configuration: CodexProviderConfiguration
        do {
            let installation = try CodexInstallationResolver().resolve(configuration: settings.codex)
            configuration = installation.configuration(timeoutSeconds: settings.codex.timeoutSeconds)
        } catch {
            fputs("\(strings.text("Unable to find a valid Codex app or CLI", "无法找到有效的 Codex 应用或 CLI")): \(error)\n", stderr)
            return
        }
        let provider = CodexProvider(configuration: configuration, language: settings.language)
        let update = await provider.refresh()
        await provider.stop()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(update)
            print(String(decoding: data, as: UTF8.self))
        } catch {
            fputs("\(strings.text("Unable to encode Codex quota", "无法编码 Codex 额度")): \(error.localizedDescription)\n", stderr)
        }
    }

    private static func printUsage(strings: TokenBarStrings) {
        print(strings.text(
            """
            tokenbar commands:
              refresh  Refresh official Codex quota and print JSON.
              paths    Print TokenBar local paths.
            """,
            """
            tokenbar 命令：
              refresh  刷新 Codex 官方额度并输出 JSON。
              paths    打印 TokenBar 本地路径。
            """
        ))
    }
}
