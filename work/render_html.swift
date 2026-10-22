import AppKit
import WebKit

final class Renderer: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let window: NSWindow
    private let output: URL

    init(html: URL, output: URL, size: NSSize) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: configuration)
        window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.output = output
        super.init()
        webView.navigationDelegate = self
        window.contentView = webView
        window.orderFrontRegardless()
        webView.loadFileURL(html, allowingReadAccessTo: html.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let configuration = WKSnapshotConfiguration()
            configuration.rect = self.webView.bounds
            configuration.snapshotWidth = NSNumber(value: self.webView.bounds.width)
            self.webView.takeSnapshot(with: configuration) { image, error in
                guard let image,
                      let tiff = image.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let png = bitmap.representation(using: .png, properties: [:])
                else {
                    fputs("Snapshot error: \(error?.localizedDescription ?? "unknown")\n", stderr)
                    NSApp.terminate(nil)
                    return
                }
                do {
                    try png.write(to: self.output)
                    print(self.output.path)
                } catch {
                    fputs("Write error: \(error)\n", stderr)
                }
                NSApp.terminate(nil)
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let runner = Renderer(
    html: URL(fileURLWithPath: CommandLine.arguments[1]),
    output: URL(fileURLWithPath: CommandLine.arguments[2]),
    size: NSSize(width: 430, height: 932)
)
withExtendedLifetime(runner) {
    app.run()
}
