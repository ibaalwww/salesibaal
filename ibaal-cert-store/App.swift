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

        // 1. Skrip Bypass WebRTC Camera Stream -> Membuka Galeri & Memasukkan Gambar ke Canvas
        let webrtcGalleryBypassScript = WKUserScript(
            source: """
            (function() {
                // Hapus atribut capture pada semua input file biasa jika ada
                function removeCapture() {
                    document.querySelectorAll('input[type="file"]').forEach(el => {
                        el.removeAttribute('capture');
                    });
                }
                document.addEventListener('DOMContentLoaded', removeCapture);
                new MutationObserver(removeCapture).observe(document.documentElement, { childList: true, subtree: true });

                // Hook navigator.mediaDevices.getUserMedia (Sistem Kamera WebRTC)
                if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                    navigator.mediaDevices.getUserMedia = function(constraints) {
                        return new Promise((resolve, reject) => {
                            // Buat input file sementara untuk memilih foto dari galeri
                            let fileInput = document.createElement('input');
                            fileInput.type = 'file';
                            fileInput.accept = 'image/*';
                            fileInput.style.display = 'none';
                            document.body.appendChild(fileInput);

                            fileInput.onchange = function(e) {
                                let file = e.target.files[0];
                                if (!file) {
                                    reject(new DOMException("User cancelled photo selection", "NotAllowedError"));
                                    fileInput.remove();
                                    return;
                                }

                                let reader = new FileReader();
                                reader.onload = function(event) {
                                    let img = new Image();
                                    img.onload = function() {
                                        // Gambar foto galeri ke canvas untuk dijadikan video stream palsu
                                        let canvas = document.createElement('canvas');
                                        canvas.width = img.width || 1280;
                                        canvas.height = img.height || 720;
                                        let ctx = canvas.getContext('2d');
                                        ctx.drawImage(img, 0, 0, canvas.width, canvas.height);

                                        // Buat loop render agar stream dianggap aktif oleh webview
                                        setInterval(() => {
                                            ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
                                        }, 100);

                                        let stream = canvas.captureStream(25);
                                        resolve(stream);
                                        fileInput.remove();
                                    };
                                    img.src = event.target.result;
                                };
                                reader.readAsDataURL(file);
                            };

                            // Buka jendela pemilihan foto/galeri iOS
                            fileInput.click();
                        });
                    };
                }
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(webrtcGalleryBypassScript)

        // 2. Jembatan GPS Geolocation
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

        // 3. Simpan Kredensial Login
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
                document.querySelectorAll('form').forEach(form => {
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

        // Izin media WebKit untuk Camera & Microphone
        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
    }
}
