import SwiftUI
import UIKit
import WebKit

@main
struct NFSMWOApp: App {
    init() {
        // Biar layar HP tidak mati/redup sendiri waktu loading atau pakai stik Bluetooth
        UIApplication.shared.isIdleTimerDisabled = true
    }

    var body: some Scene {
        WindowGroup {
            GameContainerView()
                .ignoresSafeArea(.all)
                .statusBar(hidden: true)
        }
    }
}

struct GameContainerView: View {
    @State private var reloadTrigger = false
    @State private var showQuickMenu = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            NFSMWOWebView(
                url: URL(string: "https://web.nfsmwo.com")!,
                reloadTrigger: $reloadTrigger
            )
            .ignoresSafeArea(.all)

            // Tombol mengambang tipis di pojok kiri atas untuk Reload jika dibutuhkan
            Button {
                showQuickMenu = true
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(10)
            }
            .confirmationDialog("Menu Game", isPresented: $showQuickMenu, titleVisibility: .visible) {
                Button("Reload Game") {
                    reloadTrigger = true
                }
                Button("Batal", role: .cancel) {}
            }
        }
        .background(Color.black.ignoresSafeArea(.all))
    }
}

struct NFSMWOWebView: UIViewControllerRepresentable {
    let url: URL
    @Binding var reloadTrigger: Bool

    func makeUIViewController(context: Context) -> GameWebViewController {
        let vc = GameWebViewController(url: url)
        return vc
    }

    func updateUIViewController(_ uiViewController: GameWebViewController, context: Context) {
        if reloadTrigger {
            uiViewController.reloadGame()
            DispatchQueue.main.async {
                reloadTrigger = false
            }
        }
    }
}

class GameWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private var webView: WKWebView!
    private let gameURL: URL

    init(url: URL) {
        self.gameURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Sembunyikan Status Bar & Home Indicator agar tidak kepencet waktu nge-NOS / setir
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // Matikan efek membal (bounce) & zoom agar kontrol sentuh setir/pedal akurat
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false

        // User-Agent Safari iOS modern agar fitur WebGL/WebGPU & Lite Mode terdeteksi optimal
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

        view.addSubview(webView)
        webView.load(URLRequest(url: gameURL))
    }

    func reloadGame() {
        webView.reload()
    }

    // Menangani popup login (Discord / Google / MWO Account)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let targetURL = navigationAction.request.url {
            webView.load(URLRequest(url: targetURL))
        }
        return nil
    }

    // Menangani alert dari dalam game (contoh: tawaran pindah ke Lite Mode)
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "NFS MW Online", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "NFS MW Online", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ya", style: .default) { _ in completionHandler(true) })
        alert.addAction(UIAlertAction(title: "Batal", style: .cancel) { _ in completionHandler(false) })
        present(alert, animated: true)
    }
}
