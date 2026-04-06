import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let monitor = LocalServerMonitor()
    private let launchAtLoginManager = LaunchAtLoginManager()
    private let popover = NSPopover()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover()
        bindState()
        monitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    func popoverDidClose(_ notification: Notification) {
        statusItem.button?.highlight(false)
    }

    func popoverDidShow(_ notification: Notification) {
        NSApplication.shared.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = BrandStatusIcon.statusItem
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.toolTip = AppBrand.displayName
    }

    private func configurePopover() {
        let rootView = PopoverView(monitor: monitor, launchAtLoginManager: launchAtLoginManager)
        popover.animates = true
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 460, height: 540)
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    private func bindState() {
        monitor.$servers
            .sink { [weak self] servers in
                self?.statusItem.button?.toolTip = self?.tooltip(for: servers.count)
            }
            .store(in: &cancellables)
    }

    private func tooltip(for count: Int) -> String {
        if count == 0 {
            return "\(AppBrand.displayName): no dev servers detected"
        }

        if count == 1 {
            return "\(AppBrand.displayName): 1 dev server detected"
        }

        return "\(AppBrand.displayName): \(count) dev servers detected"
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else {
            return
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        monitor.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        button.highlight(true)
    }
}

private enum AppChromeColor {
    static let hoverBackground = NSColor.controlBackgroundColor.blended(
        withFraction: 0.025,
        of: NSColor.labelColor.withAlphaComponent(0.05)
    ) ?? NSColor.controlBackgroundColor

    static let hoverBorder = NSColor.separatorColor.withAlphaComponent(0.32).blended(
        withFraction: 0.08,
        of: NSColor.labelColor.withAlphaComponent(0.06)
    ) ?? NSColor.separatorColor.withAlphaComponent(0.32)

    static let openBlue = NSColor.systemBlue
    static let stopRed = NSColor.systemRed
    static let quietShadow = NSColor.black.withAlphaComponent(0.06)
    static let hoverShadow = NSColor.black.withAlphaComponent(0.05)
    static let buttonRestFill = NSColor.controlBackgroundColor.blended(
        withFraction: 0.08,
        of: NSColor.labelColor.withAlphaComponent(0.08)
    ) ?? NSColor.controlBackgroundColor
    static let buttonRestBorder = NSColor.separatorColor.withAlphaComponent(0.26)
    static let buttonHoverGrey = NSColor.controlBackgroundColor.blended(
        withFraction: 0.22,
        of: NSColor.labelColor.withAlphaComponent(0.16)
    ) ?? NSColor.controlBackgroundColor
    static let buttonHoverBorder = NSColor.separatorColor.withAlphaComponent(0.42)
    static let buttonPressedGrey = NSColor.controlBackgroundColor.blended(
        withFraction: 0.28,
        of: NSColor.labelColor.withAlphaComponent(0.22)
    ) ?? NSColor.controlBackgroundColor
}

private extension NSColor {
    func fillColor(alpha: CGFloat) -> NSColor {
        withAlphaComponent(alpha)
    }
}

private struct PopoverView: View {
    @ObservedObject var monitor: LocalServerMonitor
    @ObservedObject var launchAtLoginManager: LaunchAtLoginManager

    private var visibleServers: [RunningServer] {
        monitor.servers.filter { !monitor.terminatingServerIDs.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 18) {
            header
            content
            footer
        }
        .padding(18)
        .frame(width: 460)
        .animation(.spring(response: 0.34, dampingFraction: 0.84, blendDuration: 0.08), value: visibleServers.map(\.id))
        .animation(.easeInOut(duration: 0.18), value: summaryText)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: BrandStatusIcon.popover)
                .interpolation(.high)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(6)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(AppBrand.displayName)
                    .font(.system(size: 17, weight: .semibold))

                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }

            Spacer()

            Button(action: monitor.refresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Refresh the server list")
        }
    }

    @ViewBuilder
    private var content: some View {
        if visibleServers.isEmpty {
            emptyState
                .transition(.serverCard)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(visibleServers) { server in
                        ServerRow(server: server, onOpen: {
                            monitor.open(server)
                        }, onKill: {
                            monitor.terminate(server)
                        })
                        .transition(.serverCard)
                    }
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 3)
            }
            .frame(maxHeight: 390)
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.slash")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)
            Text("No local dev servers")
                .font(.headline)
            Text("Start a Vite, Next.js, Rails, Python, or similar localhost server and it will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .padding(.horizontal, 30)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = monitor.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let error = launchAtLoginManager.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let lastUpdatedAt = monitor.lastUpdatedAt {
                Text("Updated \(lastUpdatedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }

            HStack {
                Text("Opens localhost targets in your default browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Toggle(
                    "Start at Login",
                    isOn: Binding(
                        get: { launchAtLoginManager.isEnabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    )
                )
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.caption)
                .help("Launch \(AppBrand.displayName) automatically the next time you sign in")

                Button("Quit", action: monitor.quit)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var summaryText: String {
        let count = visibleServers.count
        if count == 0 {
            return "Watching for local builds and dev servers"
        }
        if count == 1 {
            return "1 active server"
        }
        return "\(count) active servers"
    }
}

private struct ServerRow: View {
    let server: RunningServer
    let onOpen: () -> Void
    let onKill: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(server.projectName)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)

                TagFlowLayout(horizontalSpacing: 8, verticalSpacing: 6) {
                    TagLabel(text: server.portLabel, emphasis: .strong, isMonospaced: true)
                    TagLabel(text: server.stackLabel, systemImage: "terminal")
                    TagLabel(text: server.pidLabel, emphasis: .tertiary, isMonospaced: true)
                }

                if let path = server.abbreviatedWorkingDirectory {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                HoverActionButton(variant: .primary, action: onOpen) {
                    Image(systemName: "safari")
                }
                .help("Open port \(server.port) in your browser")

                HoverActionButton(variant: .destructive, action: onKill) {
                    Image(systemName: "xmark.circle.fill")
                }
                .help("Stop PID \(server.pid)")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(rowBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(rowBorderColor, lineWidth: 1)
        )
        .shadow(color: rowShadowColor, radius: isHovered ? 16 : 8, y: isHovered ? 7 : 3)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isHovered = hovering
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.86, blendDuration: 0.06), value: isHovered)
    }

    private var rowBackgroundColor: Color {
        if isHovered {
            return Color(nsColor: AppChromeColor.hoverBackground)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var rowBorderColor: Color {
        if isHovered {
            return Color(nsColor: AppChromeColor.hoverBorder)
        }
        return Color(nsColor: .separatorColor).opacity(0.35)
    }

    private var rowShadowColor: Color {
        Color(nsColor: isHovered ? AppChromeColor.hoverShadow : AppChromeColor.quietShadow)
    }
}

private struct TagLabel: View {
    let text: String
    var systemImage: String? = nil
    var emphasis: TagEmphasis = .secondary
    var isMonospaced = false

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(isMonospaced ? .caption.monospacedDigit() : .caption)
                .fontWeight(emphasis == .strong ? .semibold : .regular)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(capsuleBackground)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(capsuleBorder, lineWidth: 1)
        )
    }

    private var capsuleBackground: Color {
        switch emphasis {
        case .strong:
            return Color(nsColor: NSColor.controlBackgroundColor.blended(
                withFraction: 0.1,
                of: NSColor.labelColor.withAlphaComponent(0.08)
            ) ?? .controlBackgroundColor)
        case .secondary:
            return Color(nsColor: .windowBackgroundColor)
        case .tertiary:
            return Color(nsColor: NSColor.windowBackgroundColor.withAlphaComponent(0.72))
        }
    }

    private var capsuleBorder: Color {
        switch emphasis {
        case .strong:
            return Color(nsColor: .separatorColor).opacity(0.35)
        case .secondary:
            return .clear
        case .tertiary:
            return Color(nsColor: .separatorColor).opacity(0.16)
        }
    }

    private var foregroundColor: Color {
        switch emphasis {
        case .strong:
            return Color(nsColor: .labelColor)
        case .secondary:
            return Color(nsColor: .secondaryLabelColor)
        case .tertiary:
            return Color(nsColor: .tertiaryLabelColor)
        }
    }
}

private enum TagEmphasis {
    case strong
    case secondary
    case tertiary
}

private struct TagFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let rows = rows(for: subviews, maxWidth: proposal.width ?? .greatestFiniteMagnitude)
        let width = rows.map(\.width).max() ?? 0
        let height = totalHeight(for: rows)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = rows(for: subviews, maxWidth: max(bounds.width, 1))
        var currentY = bounds.minY

        for row in rows {
            var currentX = bounds.minX

            for element in row.elements {
                let point = CGPoint(
                    x: currentX,
                    y: currentY + (row.height - element.size.height) / 2
                )
                subviews[element.index].place(
                    at: point,
                    proposal: ProposedViewSize(width: element.size.width, height: element.size.height)
                )
                currentX += element.size.width + horizontalSpacing
            }

            currentY += row.height + verticalSpacing
        }
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [FlowRow] {
        let availableWidth = maxWidth.isFinite ? maxWidth : .greatestFiniteMagnitude
        var result: [FlowRow] = []
        var currentRow = FlowRow()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentRow.elements.isEmpty
                ? size.width
                : currentRow.width + horizontalSpacing + size.width

            if nextWidth > availableWidth, !currentRow.elements.isEmpty {
                result.append(currentRow)
                currentRow = FlowRow()
            }

            currentRow.append(index: index, size: size, spacing: horizontalSpacing)
        }

        if !currentRow.elements.isEmpty {
            result.append(currentRow)
        }

        return result
    }

    private func totalHeight(for rows: [FlowRow]) -> CGFloat {
        guard !rows.isEmpty else {
            return 0
        }

        return rows.reduce(0) { $0 + $1.height } + verticalSpacing * CGFloat(rows.count - 1)
    }
}

private struct FlowRow {
    struct Element {
        let index: Int
        let size: CGSize
    }

    var elements: [Element] = []
    var width: CGFloat = 0
    var height: CGFloat = 0

    mutating func append(index: Int, size: CGSize, spacing: CGFloat) {
        width += elements.isEmpty ? size.width : spacing + size.width
        height = max(height, size.height)
        elements.append(Element(index: index, size: size))
    }
}

private struct HoverActionButton<Label: View>: View {
    let variant: Variant
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label()
        }
        .buttonStyle(HoverActionButtonStyle(variant: variant, isHovered: isHovered))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

private enum Variant {
    case primary
    case destructive
}

private struct HoverActionButtonStyle: ButtonStyle {
    let variant: Variant
    let isHovered: Bool

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(borderColor(isPressed: configuration.isPressed), lineWidth: 1)
            )
            .shadow(
                color: shadowColor(isPressed: configuration.isPressed),
                radius: configuration.isPressed ? 2 : (isHovered ? 7 : 0),
                y: configuration.isPressed ? 1 : (isHovered ? 3 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : (isHovered ? 1.01 : 1))
            .opacity(isEnabled ? 1 : 0.55)
            .animation(.spring(response: 0.22, dampingFraction: 0.8, blendDuration: 0.05), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return Color(nsColor: AppChromeColor.openBlue)
        case .destructive:
            return Color(nsColor: AppChromeColor.stopRed)
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            let alpha: CGFloat = isPressed ? 0.2 : (isHovered ? 0.13 : 0.08)
            return Color(nsColor: AppChromeColor.openBlue.fillColor(alpha: alpha))
        case .destructive:
            let alpha: CGFloat = isPressed ? 0.18 : (isHovered ? 0.12 : 0.07)
            return Color(nsColor: AppChromeColor.stopRed.fillColor(alpha: alpha))
        }
    }

    private func borderColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            let alpha: CGFloat = isPressed ? 0.36 : (isHovered ? 0.24 : 0.16)
            return Color(nsColor: AppChromeColor.openBlue.fillColor(alpha: alpha))
        case .destructive:
            let alpha: CGFloat = isPressed ? 0.34 : (isHovered ? 0.22 : 0.16)
            return Color(nsColor: AppChromeColor.stopRed.fillColor(alpha: alpha))
        }
    }

    private func shadowColor(isPressed: Bool) -> Color {
        guard isHovered || isPressed else {
            return .clear
        }

        switch variant {
        case .primary:
            return Color(nsColor: AppChromeColor.openBlue.fillColor(alpha: isPressed ? 0.1 : 0.14))
        case .destructive:
            return Color(nsColor: AppChromeColor.stopRed.fillColor(alpha: isPressed ? 0.08 : 0.12))
        }
    }
}

private extension AnyTransition {
    static var serverCard: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.985)).combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .scale(scale: 0.96)).combined(with: .move(edge: .trailing))
        )
    }
}
