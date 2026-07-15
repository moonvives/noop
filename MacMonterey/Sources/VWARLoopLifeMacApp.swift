import AppKit
import SwiftUI

extension Notification.Name {
    static let vwarOpenHealthArchive = Notification.Name("VWAROpenHealthArchive")
}

final class VWARMacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApp.windows.first?.setContentSize(NSSize(width: 1_180, height: 780))
            NSApp.windows.first?.minSize = NSSize(width: 1_020, height: 700)
            NSApp.windows.first?.title = "VWAR Loop Life"
            NSApp.windows.first?.titlebarAppearsTransparent = true
        }
    }
}

@main
struct VWARLoopLifeMacApp: App {
    @NSApplicationDelegateAdaptor(VWARMacAppDelegate.self) private var appDelegate
    @StateObject private var healthArchive = HealthArchiveModel()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(healthArchive)
                .preferredColorScheme(.dark)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Importar exportação de saúde…") {
                    NotificationCenter.default.post(name: .vwarOpenHealthArchive, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }
    }
}
