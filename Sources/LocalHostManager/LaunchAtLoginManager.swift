import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var lastError: String?

    private let fileManager = FileManager.default

    init() {
        refresh()
    }

    func refresh() {
        if #available(macOS 13.0, *), useModernLoginItemAPI {
            let status = SMAppService.mainApp.status
            switch status {
            case .enabled:
                isEnabled = true
                lastError = nil
                return
            case .requiresApproval:
                isEnabled = true
                lastError = "Approve LocalHostManager in System Settings > Login Items to finish enabling start at login."
                return
            case .notRegistered, .notFound:
                break
            @unknown default:
                break
            }
        }

        isEnabled = fileManager.fileExists(atPath: legacyLaunchAgentURL.path)
        lastError = nil
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try enableLaunchAtLogin()
            } else {
                try disableLaunchAtLogin()
            }
        } catch {
            refresh()
            lastError = error.localizedDescription
            return
        }

        refresh()

        if enabled, #available(macOS 13.0, *), useModernLoginItemAPI, SMAppService.mainApp.status == .requiresApproval {
            lastError = "Approve LocalHostManager in System Settings > Login Items to finish enabling start at login."
        } else {
            lastError = nil
        }
    }

    private func enableLaunchAtLogin() throws {
        if #available(macOS 13.0, *), useModernLoginItemAPI {
            do {
                try registerMainAppLoginItem()
                try removeLegacyLaunchAgent()
                return
            } catch {
                if shouldFallBackToLegacyLaunchAgent(error) {
                    try installLegacyLaunchAgent()
                    return
                }
                throw error
            }
        }

        try installLegacyLaunchAgent()
    }

    private func disableLaunchAtLogin() throws {
        var modernError: Error?

        if #available(macOS 13.0, *), useModernLoginItemAPI {
            do {
                try unregisterMainAppLoginItemIfNeeded()
            } catch {
                modernError = error
            }
        }

        do {
            try removeLegacyLaunchAgent()
        } catch {
            if modernError == nil {
                throw error
            }
        }

        if let modernError {
            throw modernError
        }
    }

    @available(macOS 13.0, *)
    private func registerMainAppLoginItem() throws {
        do {
            try SMAppService.mainApp.register()
        } catch let error as NSError {
            if error.code == kSMErrorAlreadyRegistered {
                return
            }
            throw error
        }
    }

    @available(macOS 13.0, *)
    private func unregisterMainAppLoginItemIfNeeded() throws {
        let status = SMAppService.mainApp.status
        guard status == .enabled || status == .requiresApproval else {
            return
        }

        do {
            try SMAppService.mainApp.unregister()
        } catch let error as NSError {
            if error.code == kSMErrorJobNotFound {
                return
            }
            throw error
        }
    }

    private func installLegacyLaunchAgent() throws {
        guard let executablePath = Bundle.main.executableURL?.resolvingSymlinksInPath().path else {
            throw LaunchAtLoginError.missingExecutable
        }

        let directoryURL = legacyLaunchAgentURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)

        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        try data.write(to: legacyLaunchAgentURL, options: .atomic)
    }

    private func removeLegacyLaunchAgent() throws {
        guard fileManager.fileExists(atPath: legacyLaunchAgentURL.path) else {
            return
        }

        try fileManager.removeItem(at: legacyLaunchAgentURL)
    }

    private func shouldFallBackToLegacyLaunchAgent(_ error: Error) -> Bool {
        let nsError = error as NSError
        let message = (nsError.localizedDescription as NSString).lowercased
        return nsError.code == kSMErrorInvalidSignature
            || message.contains("signature")
            || message.contains("code signed")
    }

    private var agentLabel: String {
        (Bundle.main.bundleIdentifier ?? "com.localhostmanager.app") + ".launch-at-login"
    }

    private var legacyLaunchAgentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist")
    }

    private var useModernLoginItemAPI: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case missingExecutable

    var errorDescription: String? {
        switch self {
        case .missingExecutable:
            return "Couldn't find the app executable for launch-at-login."
        }
    }
}
