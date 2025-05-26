import SwiftUI

@main
struct ColimaToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Stop Colima and Quit") {
                appDelegate.shutdownAndExitWithWindow()
            }
        } label: {
            Label("Colima", image: "ColimaIcon")
        }
        .menuBarExtraStyle(.window)
    }

}
