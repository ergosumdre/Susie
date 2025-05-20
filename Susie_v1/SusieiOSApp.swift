import SwiftUI

@main
struct SusieiOSApp: App {
    @StateObject private var appDataStore = AppDataStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDataStore)
        }
    }
}
