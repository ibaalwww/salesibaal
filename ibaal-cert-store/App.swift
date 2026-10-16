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

// MARK: - WKWebView Wrapper dengan Auto-Fill Kredensial & Akses Galeri
struct FullFeatureWebView: UIViewRepresentable {
    let targetURL = URL(string: "https://sipgn-siphr.bgn.go.id/")!

    func makeUIView(context: Context) -> WKWebView {
        // Konfigurasi data store persisten agar cookies, cache, dan sesi login tidak hilang
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()

        // 1. Skrip untuk menghapus atribut capture agar selalu bisa pilih dari galeri
        let unlockGalleryScript = WKUserScript(
            source: """
            function allowGalleryPicker() {
                const inputs = document.querySelectorAll('input[type="file"]');
                inputs.forEach(input => {
                    input.removeAttribute('capture');
                });
            }
            document.addEventListener('DOMContentLoaded', allowGalleryPicker);
            const observer = new MutationObserver((mutations) => {
                allowGalleryPicker();
            });
            observer.observe(document.documentElement, { childList: true, subtree: true });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(unlockGalleryScript)

        // 2. Skrip Penyimpan & Pengisi Otomatis Email/Username dan Password
        let savedUser = UserDefaults.standard.string(forKey: "saved_siphr_user") ?? ""
        let savedPass = UserDefaults.standard.string(forKey: "saved_siphr_pass") ?? ""
        
        let credentialsScript = WKUserScript(
            source: """
            const autoUser = "\(savedUser)";
            const autoPass = "\(savedPass)";

            function fillCredentials() {
                const userInput = document.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="email"], input[id*="user"], input[id*="email"]');
                const passInput = document.querySelector('input[type="password"]');

                if (userInput && autoUser && !userInput.value) {
                    userInput.value = autoUser;
                    userInput.dispatchEvent(new Event('input', { bubbles: true }));
                    userInput.dispatchEvent(new Event('change', { bubbles: true }));
                }

                if (passInput && autoPass && !passInput.value) {
                    passInput.value = autoPass;
                    passInput.dispatchEvent(new Event('input', { bubbles: true }));
                    passInput.dispatchEvent(new Event('change', { bubbles: true }));
                }
            }

            function setupLoginInterceptor() {
                const forms = document.querySelectorAll('form');
                forms.forEach(form => {
                    form.addEventListener('submit', function() {
                        const uInput = form.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="email"], input[id*="user"], input[id*="email"]');
                        const pInput = form.querySelector('input[type="password"]');
                        if (uInput && pInput && uInput.value && pInput.value) {
                            window.webkit.messageHandlers.saveCredentialsHandler.postMessage({
                                user: uInput.value,
                                pass: pInput.value
                            });
                        }
                    });
                });

                const submitButtons = document.querySelectorAll('button[type="submit"], input[type="submit"], button.btn, button:not([type])');
                submitButtons.forEach(btn => {
                    btn.addEventListener('click', function() {
                        const uInput = document.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="email"], input[id*="user"], input[id*="email"]');
                        const pInput = document.querySelector('input[type="password"]');
                        if (uInput && pInput && uInput.value && pInput.value) {
                            window.webkit.messageHandlers.saveCredentialsHandler.postMessage({
                                user: uInput.value,
                                pass: pInput.value
                            });
                        }
                    });
                });
            }

            document.addEventListener('DOMContentLoaded', () => {
                fillCredentials();
                setupLoginInterceptor();
            });

            setInterval(fillCredentials, 1200);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(credentialsScript)
        contentController.add(context.coordinator, name: "saveCredentialsHandler")

        config.userContentController = contentController

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

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: FullFeatureWebView

        init(_ parent: FullFeatureWebView) {
            self.parent = parent
        }

        // Tangkap data email & password yang diinput user lalu simpan permanen
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "saveCredentialsHandler",
               let dict = message.body as? [String: String],
               let user = dict["user"], let pass = dict["pass"] {
                UserDefaults.standard.set(user, forKey: "saved_siphr_user")
                UserDefaults.standard.set(pass, forKey: "saved_siphr_pass")
            }
        }

        // Penanganan dialog web JS (Alert & Confirm)
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
