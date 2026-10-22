import SwiftUI

@main
struct GRAINApp: App {
    @StateObject private var editor = EditorViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(editor)
                .preferredColorScheme(.dark)
                .onAppear(perform: GrainHaptics.prepare)
        }
    }
}
