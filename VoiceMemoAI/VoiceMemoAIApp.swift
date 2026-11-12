import SwiftUI

@main
struct VoiceMemoAIApp: App {
    @StateObject private var recorder = RecorderStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(recorder)
                .preferredColorScheme(.light)
        }
    }
}
