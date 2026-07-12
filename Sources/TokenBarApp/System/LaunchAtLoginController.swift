import Foundation
import ServiceManagement
import TokenBarCore

@MainActor
final class LaunchAtLoginController {
    func apply(enabled: Bool, language: AppLanguage = .english) throws {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            if enabled {
                throw LaunchAtLoginError.requiresInstalledApp(language)
            }
            return
        }

        let service = SMAppService.mainApp
        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
        } else if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case requiresInstalledApp(AppLanguage)

    var errorDescription: String? {
        switch self {
        case .requiresInstalledApp(let language):
            TokenBarStrings(language).launchAtLoginRequiresInstall
        }
    }
}
