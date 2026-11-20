import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct MacBootSoundApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("MacBootSound") {
            ContentView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About MacBootSound") {
                    showAboutPanel()
                }
            }
        }
    }

    private func showAboutPanel() {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let credits = NSMutableAttributedString(
            string: "By RedCat\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph
            ]
        )

        let urlString = "https://ioerror.tistory.com"
        if let url = URL(string: urlString) {
            credits.append(
                NSAttributedString(
                    string: urlString,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11),
                        .link: url,
                        .paragraphStyle: paragraph
                    ]
                )
            )
        }

        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits
        ])
    }
}
