import AppKit
import Combine
import Darwin
import Foundation
import SwiftUI

@MainActor
final class LocalServerMonitor: ObservableObject {
    @Published private(set) var servers: [RunningServer] = []
    @Published private(set) var terminatingServerIDs: Set<String> = []
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var lastError: String?

    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?

    func start() {
        refresh()

        guard refreshTimer == nil else {
            return
        }

        let timer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func stop() {
        refreshTask?.cancel()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            let result = await LocalServerDiscovery.discover()
            guard !Task.isCancelled else {
                return
            }

            switch result {
            case .success(let discoveredServers):
                let liveIDs = Set(discoveredServers.map(\.id))
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84, blendDuration: 0.08)) {
                    servers = discoveredServers
                    terminatingServerIDs.formIntersection(liveIDs)
                }
                lastError = nil
                lastUpdatedAt = Date()
            case .failure(let error):
                lastError = error.localizedDescription
                lastUpdatedAt = Date()
            }
        }
    }

    func open(_ server: RunningServer) {
        guard let url = server.browserURL else {
            report(error: "Couldn't create a browser URL for port \(server.port).")
            return
        }

        NSWorkspace.shared.open(url)
    }

    func terminate(_ server: RunningServer) {
        _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.84, blendDuration: 0.06)) {
            terminatingServerIDs.insert(server.id)
        }

        let result = kill(server.pid, SIGTERM)
        guard result == 0 else {
            _ = withAnimation(.spring(response: 0.28, dampingFraction: 0.84, blendDuration: 0.06)) {
                terminatingServerIDs.remove(server.id)
            }
            report(error: "Couldn't stop PID \(server.pid). It may already be gone.")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                _ = withAnimation(.spring(response: 0.36, dampingFraction: 0.88, blendDuration: 0.06)) {
                    self.terminatingServerIDs.remove(server.id)
                }
            }
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func report(error message: String) {
        lastError = message
    }
}

private enum LocalServerDiscovery {
    static func discover() async -> Result<[RunningServer], Error> {
        await Task.detached(priority: .utility) {
            do {
                return .success(try scan())
            } catch {
                return .failure(error)
            }
        }.value
    }

    private static func scan() throws -> [RunningServer] {
        let username = NSUserName()
        let listeningOutput = try Shell.run(
            executable: "/usr/sbin/lsof",
            arguments: ["-nP", "-a", "-u", username, "-iTCP", "-sTCP:LISTEN", "-Fpcn"],
            acceptedExitCodes: [0, 1]
        )

        let listeningRecords = parseListeningRecords(from: listeningOutput)
        guard !listeningRecords.isEmpty else {
            return []
        }

        let pids = Array(Set(listeningRecords.map(\.pid))).sorted()
        let commands = try fetchCommands(for: pids)
        let workingDirectories = try fetchWorkingDirectories(for: pids)

        let servers = listeningRecords.compactMap { record -> RunningServer? in
            let command = commands[record.pid] ?? record.processName
            let cwd = workingDirectories[record.pid]
            let projectMetadata = cwd.map(ProjectMetadataCache.shared.metadata(for:)) ?? .empty
            let stack = detectStack(processName: record.processName, command: command)

            guard shouldInclude(record: record, command: command, cwd: cwd, projectMetadata: projectMetadata, stack: stack) else {
                return nil
            }

            let projectName = resolveProjectName(
                processName: record.processName,
                command: command,
                cwd: cwd,
                projectMetadata: projectMetadata
            )

            return RunningServer(
                pid: record.pid,
                port: record.port,
                host: record.host,
                processName: record.processName,
                projectName: projectName,
                command: command,
                workingDirectory: cwd,
                stackDisplayName: stack?.name
            )
        }

        return Array(Set(servers)).sorted {
            if $0.projectName.localizedCaseInsensitiveCompare($1.projectName) != .orderedSame {
                return $0.projectName.localizedCaseInsensitiveCompare($1.projectName) == .orderedAscending
            }
            if $0.port != $1.port {
                return $0.port < $1.port
            }
            return $0.pid < $1.pid
        }
    }

    private static func parseListeningRecords(from output: String) -> [ListeningRecord] {
        var currentPID: Int32?
        var currentProcessName = ""
        var records = Set<ListeningRecord>()

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let prefix = line.first else {
                continue
            }

            let value = String(line.dropFirst())
            switch prefix {
            case "p":
                currentPID = Int32(value)
            case "c":
                currentProcessName = value
            case "n":
                guard let pid = currentPID, let endpoint = parseEndpoint(value) else {
                    continue
                }

                records.insert(
                    ListeningRecord(
                        pid: pid,
                        processName: currentProcessName,
                        host: endpoint.host,
                        port: endpoint.port
                    )
                )
            default:
                continue
            }
        }

        return Array(records)
    }

    private static func parseEndpoint(_ rawValue: String) -> (host: String, port: Int)? {
        guard let separatorIndex = rawValue.lastIndex(of: ":"), separatorIndex < rawValue.index(before: rawValue.endIndex) else {
            return nil
        }

        let host = rawValue[..<separatorIndex].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        let portString = rawValue[rawValue.index(after: separatorIndex)...]

        guard let port = Int(portString) else {
            return nil
        }

        return (host: host.isEmpty ? "*" : host, port: port)
    }

    private static func fetchCommands(for pids: [Int32]) throws -> [Int32: String] {
        guard !pids.isEmpty else {
            return [:]
        }

        let arguments = ["-o", "pid=,command=", "-p", pids.map(String.init).joined(separator: ",")]
        let output = try Shell.run(executable: "/bin/ps", arguments: arguments, acceptedExitCodes: [0, 1])
        var commands: [Int32: String] = [:]

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else {
                continue
            }

            let components = line.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard components.count == 2, let pid = Int32(components[0]) else {
                continue
            }

            commands[pid] = String(components[1])
        }

        return commands
    }

    private static func fetchWorkingDirectories(for pids: [Int32]) throws -> [Int32: String] {
        guard !pids.isEmpty else {
            return [:]
        }

        let output = try Shell.run(
            executable: "/usr/sbin/lsof",
            arguments: ["-a", "-p", pids.map(String.init).joined(separator: ","), "-d", "cwd", "-Fn"],
            acceptedExitCodes: [0, 1]
        )

        var directories: [Int32: String] = [:]
        var currentPID: Int32?
        var shouldCapturePath = false

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            guard let prefix = line.first else {
                continue
            }

            let value = String(line.dropFirst())
            switch prefix {
            case "p":
                currentPID = Int32(value)
                shouldCapturePath = false
            case "f":
                shouldCapturePath = value == "cwd"
            case "n":
                guard shouldCapturePath, let pid = currentPID else {
                    continue
                }
                directories[pid] = value
                shouldCapturePath = false
            default:
                continue
            }
        }

        return directories
    }

    private static func shouldInclude(
        record: ListeningRecord,
        command: String,
        cwd: String?,
        projectMetadata: ProjectMetadata,
        stack: StackMatch?
    ) -> Bool {
        let normalizedCommand = command.lowercased()
        let normalizedProcess = record.processName.lowercased()
        let normalizedCWD = cwd?.lowercased() ?? ""
        let haystack = [normalizedProcess, normalizedCommand, normalizedCWD].joined(separator: " ")

        if ignoredKeywords.contains(where: haystack.contains) {
            return false
        }

        var score = 0

        if let stack {
            score += stack.weight
        }

        if projectMetadata.hasProjectMarkers {
            score += 2
        }

        if normalizedCommand.contains("/users/") || normalizedCWD.contains("/users/") {
            score += 1
        }

        if developmentRuntimeNames.contains(normalizedProcess) {
            score += 1
        }

        if record.port >= 3000 && record.port <= 9999 {
            score += 1
        }

        return score >= 3
    }

    private static func resolveProjectName(
        processName: String,
        command: String,
        cwd: String?,
        projectMetadata: ProjectMetadata
    ) -> String {
        if let explicitName = projectMetadata.projectName, !explicitName.isEmpty {
            return explicitName
        }

        if let cwd {
            return URL(fileURLWithPath: cwd).lastPathComponent
        }

        let executablePath = command.split(separator: " ").first.map(String.init) ?? processName
        return URL(fileURLWithPath: executablePath).deletingPathExtension().lastPathComponent
    }

    private static func detectStack(processName: String, command: String) -> StackMatch? {
        let normalized = "\(processName) \(command)".lowercased()

        for match in stackMatchers where normalized.contains(match.keyword) {
            return match
        }

        return nil
    }

    private static let stackMatchers: [StackMatch] = [
        StackMatch(keyword: "electron-vite", name: "Electron + Vite", weight: 3),
        StackMatch(keyword: "next", name: "Next.js", weight: 3),
        StackMatch(keyword: "nuxt", name: "Nuxt", weight: 3),
        StackMatch(keyword: "astro", name: "Astro", weight: 3),
        StackMatch(keyword: "vite", name: "Vite", weight: 3),
        StackMatch(keyword: "webpack", name: "Webpack", weight: 3),
        StackMatch(keyword: "react-scripts", name: "React Scripts", weight: 3),
        StackMatch(keyword: "parcel", name: "Parcel", weight: 3),
        StackMatch(keyword: "svelte-kit", name: "SvelteKit", weight: 3),
        StackMatch(keyword: "http.server", name: "Python HTTP Server", weight: 3),
        StackMatch(keyword: "uvicorn", name: "Uvicorn", weight: 3),
        StackMatch(keyword: "gunicorn", name: "Gunicorn", weight: 3),
        StackMatch(keyword: "flask", name: "Flask", weight: 3),
        StackMatch(keyword: "django", name: "Django", weight: 3),
        StackMatch(keyword: "puma", name: "Puma", weight: 3),
        StackMatch(keyword: "rails", name: "Rails", weight: 3),
        StackMatch(keyword: "rackup", name: "Rack", weight: 3),
        StackMatch(keyword: "mix phx.server", name: "Phoenix", weight: 3),
        StackMatch(keyword: "phoenix", name: "Phoenix", weight: 3),
        StackMatch(keyword: "php -s", name: "PHP Server", weight: 3),
        StackMatch(keyword: "hugo", name: "Hugo", weight: 3),
        StackMatch(keyword: "http-server", name: "HTTP Server", weight: 3),
        StackMatch(keyword: "serve", name: "Static Server", weight: 2),
    ]

    private static let ignoredKeywords: [String] = [
        "adobe",
        "creative cloud",
        "controlcenter",
        "discord",
        "figma",
        "figma_agent",
        "google chrome",
        "lm studio",
        "logioptionsplus",
        "postgres",
        "postgresql",
        "mysql",
        "redis-server",
        "rapportd",
        "sharingd",
        "xpcproxy",
        "zoom",
    ]

    private static let developmentRuntimeNames: Set<String> = [
        "air",
        "bun",
        "cargo",
        "deno",
        "go",
        "node",
        "php",
        "pnpm",
        "python",
        "python3",
        "ruby",
        "swift",
        "yarn",
    ]
}

private struct ListeningRecord: Hashable {
    let pid: Int32
    let processName: String
    let host: String
    let port: Int
}

private struct StackMatch {
    let keyword: String
    let name: String
    let weight: Int
}

private struct ProjectMetadata {
    let projectName: String?
    let hasProjectMarkers: Bool

    static let empty = ProjectMetadata(projectName: nil, hasProjectMarkers: false)
}

private final class ProjectMetadataCache: @unchecked Sendable {
    static let shared = ProjectMetadataCache()

    private let lock = NSLock()
    private var storage: [String: ProjectMetadata] = [:]

    func metadata(for directory: String) -> ProjectMetadata {
        lock.lock()
        if let cached = storage[directory] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let metadata = Self.inspect(directory: directory)

        lock.lock()
        storage[directory] = metadata
        lock.unlock()

        return metadata
    }

    private static func inspect(directory: String) -> ProjectMetadata {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        let markerFiles = [
            "package.json",
            "pnpm-workspace.yaml",
            "yarn.lock",
            "bun.lockb",
            "pyproject.toml",
            "requirements.txt",
            "Pipfile",
            "manage.py",
            "Gemfile",
            "Cargo.toml",
            "go.mod",
            "composer.json",
            "mix.exs",
            ".git",
        ]

        let hasMarkers = markerFiles.contains {
            fileManager.fileExists(atPath: url.appendingPathComponent($0).path)
        }

        if let packageName = parseJSONName(at: url.appendingPathComponent("package.json")) {
            return ProjectMetadata(projectName: packageName, hasProjectMarkers: hasMarkers)
        }

        if let pyProjectName = parseRegexName(
            at: url.appendingPathComponent("pyproject.toml"),
            pattern: #"(?m)^\s*name\s*=\s*"([^"]+)""#
        ) {
            return ProjectMetadata(projectName: pyProjectName, hasProjectMarkers: hasMarkers)
        }

        if let cargoName = parseRegexName(
            at: url.appendingPathComponent("Cargo.toml"),
            pattern: #"(?m)^\s*name\s*=\s*"([^"]+)""#
        ) {
            return ProjectMetadata(projectName: cargoName, hasProjectMarkers: hasMarkers)
        }

        if let goModule = parseRegexName(
            at: url.appendingPathComponent("go.mod"),
            pattern: #"(?m)^\s*module\s+(.+)$"#
        ) {
            return ProjectMetadata(projectName: goModule.split(separator: "/").last.map(String.init), hasProjectMarkers: hasMarkers)
        }

        if let composerName = parseJSONName(at: url.appendingPathComponent("composer.json")) {
            return ProjectMetadata(projectName: composerName, hasProjectMarkers: hasMarkers)
        }

        return ProjectMetadata(projectName: url.lastPathComponent, hasProjectMarkers: hasMarkers)
    }

    private static func parseJSONName(at url: URL) -> String? {
        guard
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let name = object["name"] as? String
        else {
            return nil
        }

        return name
    }

    private static func parseRegexName(at url: URL, pattern: String) -> String? {
        guard let content = try? String(contentsOf: url) else {
            return nil
        }

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
            let range = Range(match.range(at: 1), in: content)
        else {
            return nil
        }

        return content[range].trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private enum Shell {
    static func run(executable: String, arguments: [String], acceptedExitCodes: Set<Int32> = [0]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        guard acceptedExitCodes.contains(process.terminationStatus) else {
            throw DiscoveryError.commandFailed(executable: executable, message: stderr.isEmpty ? stdout : stderr)
        }

        return stdout
    }
}

private enum DiscoveryError: LocalizedError {
    case commandFailed(executable: String, message: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(let executable, let message):
            let details = message.trimmingCharacters(in: .whitespacesAndNewlines)
            if details.isEmpty {
                return "Failed to inspect running servers with \(executable)."
            }
            return "Failed to inspect running servers with \(executable): \(details)"
        }
    }
}
