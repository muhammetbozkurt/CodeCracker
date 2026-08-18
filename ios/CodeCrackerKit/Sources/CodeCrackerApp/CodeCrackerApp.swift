import SwiftUI

@main
struct CodeCrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // The app is designed dark in both system appearances, matching
                // the web client. See Theme.swift.
                .preferredColorScheme(.dark)
        }
    }
}
