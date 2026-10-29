import SwiftUI

@main
struct TypecaseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    init() {
        AppModel.shared.start()
    }

    var body: some Scene {
        // Main window: sidebar, character grid and inspector.
        Window("Typecase", id: SceneID.main) {
            MainView()
                .environment(model)
        }
        .defaultSize(width: 1080, height: 700)
        .commands { AppCommands(model: model) }

        // Quick Lookup is an AppKit panel (see QuickLookupPanel.swift): a SwiftUI window would activate the app and
        // take the text cursor away from the app the character is meant for.

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
