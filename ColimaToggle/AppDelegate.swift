import Foundation
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    @Published var isRunning: Bool = false
    var startupPanel: NSPanel? = nil // 保持强引用防止窗口闪退

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !colimaExists() {
            showMissingColimaAlertAndExit()
            return
        }

        if isColimaRunning() {
            print("✅ Colima 已在运行")
            isRunning = true
        } else {
            print("🚀 Colima 未运行，准备弹出窗口")
            showStartupWindowAndStartColima()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if colimaExists() {
            stopColima()
        }
    }

    func startColima() {
        isRunning = true
        Task {
            _ = try? shell("colima start")
        }
    }

    func stopColima() {
        isRunning = false
        Task {
            _ = try? shell("colima stop")
        }
    }

    func toggleColima() {
        isRunning.toggle()
        Task {
            _ = try? shell(isRunning ? "colima start" : "colima stop")
        }
    }

    func colimaExists() -> Bool {
        let which = try? shell("which colima")
        return !(which?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    func isColimaRunning() -> Bool {
        let output = try? shell("colima status")
        return output?.contains("colima is running") ?? false
    }

    func showMissingColimaAlertAndExit() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Colima Not Found"
            alert.informativeText = "Please install Colima before running this tool."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "ok")
            alert.runModal()
            NSApplication.shared.terminate(nil)
        }
    }

    func showStartupWindowAndStartColima() {
        DispatchQueue.main.async { [self] in
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            panel.title = "Starting Colima..."

            let scrollView = NSScrollView(frame: panel.contentView!.bounds)
            scrollView.hasVerticalScroller = true

            let textView = NSTextView(frame: scrollView.contentView.bounds)
            textView.isEditable = false
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            textView.autoresizingMask = [.width, .height]
            scrollView.documentView = textView

            panel.contentView?.addSubview(scrollView)
            panel.center()
            panel.makeKeyAndOrderFront(nil)

            self.startupPanel = panel // 保留引用防止闪退

            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", "colima start"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                let handle = pipe.fileHandleForReading
                handle.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    if data.isEmpty { return }
                    if let line = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            textView.string += line
                            textView.scrollToEndOfDocument(nil)
                        }
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    DispatchQueue.main.async {
                        textView.string += "\n❌ launch fail：\(error.localizedDescription)"
                        print("🚫 Colima 启动失败：", error)
                    }
                }

                for _ in 0..<10 {
                    if self.isColimaRunning() {
                        break
                    }
                    sleep(1)
                }

                DispatchQueue.main.async {
                    self.isRunning = true
                    handle.readabilityHandler = nil
                    self.startupPanel?.close()
                    self.startupPanel = nil
                }
            }
        }
    }
    
    func shutdownAndExitWithWindow() {
        DispatchQueue.main.async { [self] in
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            panel.title = "closing Colima..."

            let scrollView = NSScrollView(frame: panel.contentView!.bounds)
            scrollView.hasVerticalScroller = true

            let textView = NSTextView(frame: scrollView.contentView.bounds)
            textView.isEditable = false
            textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            textView.autoresizingMask = [.width, .height]
            scrollView.documentView = textView

            panel.contentView?.addSubview(scrollView)
            panel.center()
            panel.makeKeyAndOrderFront(nil)

            // 强引用防止窗口自动关闭
            self.startupPanel = panel

            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-l", "-c", "colima stop"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                let handle = pipe.fileHandleForReading
                handle.readabilityHandler = { fileHandle in
                    let data = fileHandle.availableData
                    if data.isEmpty { return }
                    if let line = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            textView.string += line
                            textView.scrollToEndOfDocument(nil)
                        }
                    }
                }

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    DispatchQueue.main.async {
                        textView.string += "\n❌ An error occurred while stopping Colima: \(error.localizedDescription)"
                        print("🚫 Colima 关闭失败：", error)
                    }
                }

                DispatchQueue.main.async {
                    handle.readabilityHandler = nil
                    self.startupPanel?.close()
                    self.startupPanel = nil
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }


    @discardableResult
    func shell(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
