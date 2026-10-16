import SwiftUI
import WebKit
import CoreLocation

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
            webView.ignoresSafeArea(.all, edges: .bottom)
        }
    }
}

struct FullFeatureWebView: UIViewRepresentable {
    let targetURL = URL(string: "https://sipgn-siphr.bgn.go.id/")!

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()

        // 1. Bypass capture file agar selalu bisa buka Galeri
        let unlockGalleryScript = WKUserScript(
            source: """
            function allowGalleryPicker() {
                const inputs = document.querySelectorAll('input[type="file"]');
                inputs.forEach(input => input.removeAttribute('capture'));
            }
            document.addEventListener('DOMContentLoaded', allowGalleryPicker);
            const observer = new MutationObserver(() => allowGalleryPicker());
            observer.observe(document.documentElement, { childList: true, subtree: true });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(unlockGalleryScript)

        // 2. Bypass & Mock Geolocation Langsung dari GPS Native iPhone ke Web SIPGN
        let geoBridgeScript = WKUserScript(
            source: """
            window.__currentLat = 0;
            window.__currentLng = 0;
            window.__currentAcc = 10;
            window.__hasLocation = false;

            window.updateDeviceLocation = function(lat, lng, acc) {
                window.__currentLat = lat;
                window.__currentLng = lng;
                window.__currentAcc = acc;
                window.__hasLocation = true;
            };

            if (navigator.geolocation) {
                const nativeGetCurrentPosition = navigator.geolocation.getCurrentPosition.bind(navigator.geolocation);
                const nativeWatchPosition = navigator.geolocation.watchPosition.bind(navigator.geolocation);

                navigator.geolocation.getCurrentPosition = function(success, error, options) {
                    if (window.__hasLocation) {
                        success({
                            coords: {
                                latitude: window.__currentLat,
                                longitude: window.__currentLng,
                                accuracy: window.__currentAcc,
                                altitude: null,
                                altitudeAccuracy: null,
                                heading: null,
                                speed: null
                            },
                            timestamp: Date.now()
                        });
                    } else {
                        window.webkit.messageHandlers.requestLocationUpdate.postMessage({});
                        setTimeout(() => {
                            if (window.__hasLocation) {
                                success({
                                    coords: {
                                        latitude: window.__currentLat,
                                        longitude: window.__currentLng,
                                        accuracy: window.__currentAcc,
                                        altitude: null,
                                        altitudeAccuracy: null,
                                        heading: null,
                                        speed: null
                                    },
                                    timestamp: Date.now()
                                });
                            } else {
                                nativeGetCurrentPosition(success, error, options);
                            }
                        }, 1000);
                    }
                };

                navigator.geolocation.watchPosition = function(success, error, options) {
                    return setInterval(() => {
                        if (window.__hasLocation) {
                            success({
                                coords: {
                                    latitude: window.__currentLat,
                                    longitude: window.__currentLng,
                                    accuracy: window.__currentAcc,
                                    altitude: null,
                                    altitudeAccuracy: null,
                                    heading: null,
                                    speed: null
                                },
                                timestamp: Date.now()
                            });
                        }
                    }, 3000);
                };
            }
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(geoBridgeScript)

        // 3. Simpan dan Isi Otomatis Login Akun
        let savedUser = UserDefaults.standard.string(forKey: "saved_siphr_user") ?? ""
        let savedPass = UserDefaults.standard.string(forKey: "saved_siphr_pass") ?? ""
        
        let credentialsScript = WKUserScript(
            source: """
            const autoUser = "\(savedUser)";
            const autoPass = "\(savedPass)";

            function fillCredentials() {
                const userInput = document.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="email"]');
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
                        const uInput = form.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="email"]');
                        const pInput = form.querySelector('input[type="password"]');
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
        contentController.add(context.coordinator, name: "requestLocationUpdate")
        config.userContentController = contentController

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.bounces = true
        
        context.coordinator.webView = wv
        context.coordinator.startUpdatingLocation()
        
        wv.load(URLRequest(url: targetURL))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, CLLocationManagerDelegate {
        var parent: FullFeatureWebView
        weak var webView: WKWebView?
        let locationManager = CLLocationManager()
        var lastLocation: CLLocation?

        init(_ parent: FullFeatureWebView) {
            self.parent = parent
            super.init()
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        }

        func startUpdatingLocation() {
            locationManager.requestWhenInUseAuthorization()
            locationManager.startUpdatingLocation()
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let loc = locations.last else { return }
            self.lastLocation = loc
            injectLocationToWeb(loc)
        }

        func injectLocationToWeb(_ loc: CLLocation) {
            let js = "if (window.updateDeviceLocation) { window.updateDeviceLocation(\(loc.coordinate.latitude), \(loc.coordinate.longitude), \(loc.horizontalAccuracy)); }"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "saveCredentialsHandler",
               let dict = message.body as? [String: String],
               let user = dict["user"], let pass = dict["pass"] {
                UserDefaults.standard.set(user, forKey: "saved_siphr_user")
                UserDefaults.standard.set(pass, forKey: "saved_siphr_pass")
            } else if message.name == "requestLocationUpdate" {
                if let loc = self.lastLocation {
                    injectLocationToWeb(loc)
                } else {
                    locationManager.startUpdatingLocation()
                }
            }
        }

        // Tangani izin WebKit modern untuk Media & Lokasi
        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }

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
