import AppKit
import Foundation
import SwiftUI

@MainActor
private final class DesktopAppModel: ObservableObject {
    @Published var deviceSelector = ""
    @Published var duration = "600"
    @Published var outputDirectory = NSString(string: "~/Documents/VITAE-VWAR-Capture").expandingTildeInPath
    @Published var console = "Scan nearby devices, then select the VWAR Loop Life by name or UUID."
    @Published var isRunning = false
    @Published var activity = "READY"
    @Published var lastRunSucceeded: Bool?

    private var process: Process?
    private var pipe: Pipe?

    func scan() {
        run(arguments: ["--list", "--scan-timeout", "30"], activity: "SCANNING")
    }

    func capture() {
        let selector = deviceSelector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selector.isEmpty else {
            console = "Enter part of the advertised name or paste the UUID shown by Scan."
            lastRunSucceeded = false
            return
        }
        guard let seconds = Int(duration), seconds > 0 else {
            console = "Capture duration must be a positive number of seconds."
            lastRunSucceeded = false
            return
        }
        var arguments: [String]
        if UUID(uuidString: selector) != nil { arguments = ["--identifier", selector] }
        else { arguments = ["--name", selector] }
        arguments += ["--duration", String(seconds), "--output", outputDirectory]
        run(arguments: arguments, activity: "CAPTURING")
    }

    func stop() {
        process?.interrupt()
        activity = "STOPPING"
    }

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url { outputDirectory = url.path }
    }

    private func run(arguments: [String], activity: String) {
        guard !isRunning else { return }
        guard let helper = helperURL else {
            console = "The bundled capture helper is missing. Reinstall the complete VITAE One VWAR Loop Life app."
            lastRunSucceeded = false
            return
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = helper
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        self.process = process
        self.pipe = pipe
        isRunning = true
        self.activity = activity
        lastRunSucceeded = nil
        console = ""

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.appendConsole(text) }
        }
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.pipe?.fileHandleForReading.readabilityHandler = nil
                self?.isRunning = false
                self?.activity = process.terminationStatus == 0 ? "COMPLETE" : "FAILED"
                self?.lastRunSucceeded = process.terminationStatus == 0
                self?.process = nil
                self?.pipe = nil
            }
        }

        do { try process.run() }
        catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            isRunning = false
            self.activity = "FAILED"
            lastRunSucceeded = false
            console = "Unable to start collector: \(error.localizedDescription)"
            self.process = nil
            self.pipe = nil
        }
    }

    private func appendConsole(_ text: String) {
        console += text
        if console.count > 40_000 { console.removeFirst(console.count - 40_000) }
    }

    private var helperURL: URL? {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("vitae-vwar-capture")
        if FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }

        // Supports `swift run VITAEVWARDesktop` during development when both products share .build.
        let sibling = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
            .appendingPathComponent("vitae-vwar-capture")
        return FileManager.default.isExecutableFile(atPath: sibling.path) ? sibling : nil
    }
}

private struct ContentView: View {
    @StateObject private var model = DesktopAppModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.12))
            HStack(alignment: .top, spacing: 28) {
                controls.frame(width: 330)
                console
            }
            .padding(28)
        }
        .frame(minWidth: 920, idealWidth: 1040, minHeight: 600, idealHeight: 680)
        .background(Color(red: 0.035, green: 0.035, blue: 0.04))
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text("VITAE ONE VWAR LOOP LIFE")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(Color.white.opacity(0.55))
                Text("Coletor VWAR Loop Life")
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
            }
            Spacer()
            Text(model.activity)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 22) {
            section("DEVICE") {
                TextField("Name fragment or UUID", text: $model.deviceSelector)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(fieldBackground)
                actionButton("SCAN NEARBY DEVICES", primary: false, action: model.scan)
            }
            section("CAPTURE") {
                HStack(spacing: 10) {
                    TextField("Seconds", text: $model.duration)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(fieldBackground)
                    Text("SECONDS")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.42))
                }
                HStack(spacing: 8) {
                    Text(model.outputDirectory)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(2)
                        .foregroundStyle(Color.white.opacity(0.64))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("CHOOSE") { model.chooseOutputDirectory() }
                        .buttonStyle(TextButtonStyle())
                }
                actionButton(model.isRunning ? "STOP CAPTURE" : "START READ-ONLY CAPTURE", primary: true) {
                    if model.isRunning { model.stop() } else { model.capture() }
                }
            }
            section("SAFETY") {
                Text("Reads and subscriptions only. No proprietary commands, firmware changes, cloud login, or medical interpretation.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var console: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CAPTURE LOG")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.42))
            ScrollView {
                Text(model.console.isEmpty ? "Waiting for collector output…" : model.console)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }
            .background(Color.black.opacity(0.32), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Color.white.opacity(0.42))
            content()
        }
    }

    private func actionButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(primary ? Color(red: 0.78, green: 1.0, blue: 0.16) : Color.white.opacity(0.07))
                .foregroundStyle(primary ? Color.black : Color.white.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(model.isRunning && title.contains("SCAN"))
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.055))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.09)))
    }

    private var statusColor: Color {
        if model.lastRunSucceeded == false { return Color(red: 1, green: 0.38, blue: 0.36) }
        if model.isRunning { return Color(red: 0.78, green: 1.0, blue: 0.16) }
        return Color.white.opacity(0.62)
    }
}

private struct TextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Color.white.opacity(configuration.isPressed ? 0.5 : 0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }
}

@main
private struct VITAEVWARDesktopApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
            .windowStyle(.hiddenTitleBar)
            .commands { CommandGroup(replacing: .newItem) { } }
    }
}
