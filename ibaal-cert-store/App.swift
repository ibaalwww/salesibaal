import SwiftUI
import WebKit

@main
struct WebWrapperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @State private var webView = FullFeatureWebView()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            webView
                .ignoresSafeArea(.all, edges: .bottom)
        }
    }
}

// MARK: - WKWebView Wrapper dengan Izin Kamera & Galeri
struct FullFeatureWebView: UIViewRepresentable {
    let targetURL = URL(string: "https://pop-sipgn.bgn.go.id/")!

    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = preferences
        config.allowsInlineMediaPlayback = true
        
        // Membuka izin input kamera dan galeri
        config.mediaTypesRequiringUserActionForPlayback = []

        // Injeksi JS agar tag input file yang 'capture=camera' tetap membuka menu pilihan galeri iOS
        let overrideCaptureScript = WKUserScript(
            source: """
            document.addEventListener('DOMContentLoaded', function() {
                const inputs = document.querySelectorAll('input[type="file"]');
                inputs.forEach(input => {
                    input.removeAttribute('capture');
                });
            });
            const observer = new MutationObserver((mutations) => {
                mutations.forEach((mutation) => {
                    mutation.addedNodes.forEach((node) => {
                        if (node.tagName === 'INPUT' && node.type === 'file') {
                            node.removeAttribute('capture');
                        } else if (node.querySelectorAll) {
                            node.querySelectorAll('input[type="file"]').forEach(i => i.removeAttribute('capture'));
                        }
                    });
                });
            });
            observer.observe(document.body, { childList: true, subtree: true });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(overrideCaptureScript)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.bounces = true
        
        let req = URLRequest(url: targetURL)
        wv.load(req)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: FullFeatureWebView

        init(_ parent: FullFeatureWebView) {
            self.parent = parent
        }

        // Penanganan izin dialog JS (Alert, Confirm, Input)
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completionHandler() }))
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Batal", style: .cancel, handler: { _ in completionHandler(false) }))
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in completionHandler(true) }))
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
        }
    }
}
