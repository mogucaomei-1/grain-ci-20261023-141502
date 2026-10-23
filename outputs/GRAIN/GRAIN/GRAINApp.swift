import SwiftUI

@main
struct GRAINApp: App {
    @StateObject private var editor = EditorViewModel()
    @AppStorage("didPrimeInitialNetworkAccess") private var didPrimeInitialNetworkAccess = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(editor)
                .preferredColorScheme(.dark)
                .onAppear(perform: GrainHaptics.prepare)
                .task {
                    await primeInitialNetworkAccessIfNeeded()
                }
        }
    }

    private func primeInitialNetworkAccessIfNeeded() async {
        guard !didPrimeInitialNetworkAccess else { return }
        didPrimeInitialNetworkAccess = true

        var request = URLRequest(
            url: URL(string: "https://captive.apple.com/hotspot-detect.html")!
        )
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 6
        _ = try? await URLSession.shared.data(for: request)
    }
}
