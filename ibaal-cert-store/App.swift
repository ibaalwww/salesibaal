import SwiftUI
import WebKit
import CoreLocation

@main
struct KurirMBGApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @State private var webView = KurirWebView()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            webView.ignoresSafeArea(.all, edges: .bottom)
        }
    }
}

struct KurirWebView: UIViewRepresentable {
    // URL Target khusus portal Kurir MBG SIPGN
    let targetURL = URL(string: "https://kurirmbg-sipgn.bgn.go.id/auth/login")!

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let contentController = WKUserContentController()

        // 1. Skrip untuk memastikan tombol upload/kamera web membuka galeri foto
        let unlockGalleryScript = WKUserScript(
            source: """
            function unlockGallery() {
                try {
                    const inputs = document.querySelectorAll('input[type="file"]');
                    inputs.forEach(input => input.removeAttribute('capture'));
                } catch (e) {}
            }
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', unlockGallery);
            } else {
                unlockGallery();
            }
            const observer = new MutationObserver(() => unlockGallery());
            observer.observe(document.documentElement, { childList: true, subtree: true });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(unlockGalleryScript)

        // 2. Jembatan GPS Geolocation native iPhone ke Web Kurir
        let geoBridgeScript = WKUserScript(
            source: """
            window.__currentLat = null;
            window.__currentLng = null;
            window.__currentAcc = 10;

            window.updateDeviceLocation = function(lat, lng, acc) {
                window.__currentLat = lat;
                window.__currentLng = lng;
                window.__currentAcc = acc;
            };

            if (navigator.geolocation) {
                const originalGet = navigator.geolocation.getCurrentPosition.bind(navigator.geolocation);
                const originalWatch = navigator.geolocation.watchPosition.bind(navigator.geolocation);

                navigator.geolocation.getCurrentPosition = function(success, error, options) {
                    if (window.__currentLat !== null && window.__currentLng !== null) {
                        success({
                            coords: {
                                latitude: window.__currentLat,
                                longitude: window.__currentLng,
                                accuracy: window.__currentAcc,
                                altitude: null, altitudeAccuracy: null, heading: null, speed: null
                            },
                            timestamp: Date.now()
                        });
                    } else {
                        window.webkit.messageHandlers.requestLocationUpdate.postMessage({});
                        setTimeout(() => {
                            if (window.__currentLat !== null && window.__currentLng !== null) {
                                success({
                                    coords: {
                                        latitude: window.__currentLat,
                                        longitude: window.__currentLng,
                                        accuracy: window.__currentAcc,
                                        altitude: null, altitudeAccuracy: null, heading: null, speed: null
                                    },
                                    timestamp: Date.now()
                                });
                            } else {
                                originalGet(success, error, options);
                            }
                        }, 800);
                    }
                };

                navigator.geolocation.watchPosition = function(success, error, options) {
                    return setInterval(() => {
                        if (window.__currentLat !== null && window.__currentLng !== null) {
                            success({
                                coords: {
                                    latitude: window.__currentLat,
                                    longitude: window.__currentLng,
                                    accuracy: window.__currentAcc,
                                    altitude: null, altitudeAccuracy: null, heading: null, speed: null
                                },
                                timestamp: Date.now()
                            });
                        }
                    }, 2500);
                };
            }
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(geoBridgeScript)

        // 3. Auto-Fill & Simpan Kredensial Login Kurir
        let savedUser = UserDefaults.standard.string(forKey: "saved_kurirmbg_user") ?? ""
        let savedPass = UserDefaults.standard.string(forKey: "saved_kurirmbg_pass") ?? ""
        
        let credentialsScript = WKUserScript(
            source: """
            const autoUser = "\(savedUser)";
            const autoPass = "\(savedPass)";

            function fillCredentials() {
                const userInput = document.querySelector('input[type="text"], input[type="email"], input[name*="user"], input[name*="email"], input[id*="email"], input[id*="username"]');
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
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

        context.coordinator.webView = wv
        context.coordinator.setupLocationManager()
        
        var req = URLRequest(url: targetURL)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        wv.load(req)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler, CLLocationManagerDelegate {
        var parent: KurirWebView
        weak var webView: WKWebView?
        let locationManager = CLLocationManager()
        var latestLocation: CLLocation?

        init(_ parent: KurirWebView) {
            self.parent = parent
            super.init()
        }

        func setupLocationManager() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestWhenInUseAuthorization()
            }
            locationManager.startUpdatingLocation()
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let loc = locations.last else { return }
            self.latestLocation = loc
            sendLocationToJS(loc)
        }

        func sendLocationToJS(_ loc: CLLocation) {
            let js = "if (window.updateDeviceLocation) { window.updateDeviceLocation(\(loc.coordinate.latitude), \(loc.coordinate.longitude), \(loc.horizontalAccuracy)); }"
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "saveCredentialsHandler",
               let dict = message.body as? [String: String],
               let user = dict["user"], let pass = dict["pass"] {
                UserDefaults.standard.set(user, forKey: "saved_kurirmbg_user")
                UserDefaults.standard.set(pass, forKey: "saved_kurirmbg_pass")
            } else if message.name == "requestLocationUpdate" {
                if let loc = self.latestLocation {
                    sendLocationToJS(loc)
                } else {
                    locationManager.startUpdatingLocation()
                }
            }
        }

        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }

        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
    }
}
