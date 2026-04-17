import Foundation

struct RunningServer: Identifiable, Equatable, Hashable {
    let pid: Int32
    let port: Int
    let host: String
    let processName: String
    let projectName: String
    let command: String
    let workingDirectory: String?
    let stackDisplayName: String?

    var id: String {
        "\(pid)-\(port)"
    }

    var browserURL: URL? {
        var components = URLComponents()
        components.scheme = prefersSecureScheme ? "https" : "http"
        components.host = "localhost"
        components.port = port
        return components.url
    }

    var prefersSecureScheme: Bool {
        let normalized = command.lowercased()
        return port == 443 || port == 8443 || normalized.contains("https") || normalized.contains("ssl")
    }

    var portLabel: String {
        "Port \(port)"
    }

    var stackLabel: String {
        stackDisplayName ?? processName
    }

    var pidLabel: String {
        "PID \(pid)"
    }

    var abbreviatedWorkingDirectory: String? {
        guard let workingDirectory else {
            return nil
        }

        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if workingDirectory.hasPrefix(homePath) {
            return "~" + workingDirectory.dropFirst(homePath.count)
        }

        return workingDirectory
    }
}
