import UIKit
import WebKit
import CoreLocation
import SiroNav

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let win = UIWindow(windowScene: windowScene)
        win.rootViewController = ViewController()
        win.makeKeyAndVisible()
        self.window = win
    }
}

class ViewController: UIViewController, SiroNavListener, WKScriptMessageHandler, WKNavigationDelegate {
    private var webView: WKWebView!
    private var navView: SiroNavView!
    private var navController: SiroNavController!
    private var startButton: UIButton!
    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var simTimer: Timer?
    private var fixes: [NavPoint] = []
    private var currentFixIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 15/255, green: 23/255, blue: 42/255, alpha: 1.0) // Slate 900

        setupMapWebView()
        setupHUD()
        setupLaunchScreenUI()

        let config = NavConfig(apiKey: "siro_live_eval_ios_key")
        navController = SiroNavController(config: config)
        navController.listener = self

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.didTapStartNav()
        }
    }

    private func setupMapWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "siroNavBridge")

        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        config.userContentController = contentController

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = .clear
        view.addSubview(webView)

        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
            <script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
            <link href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css" rel="stylesheet" />
            <style>
                html, body, #map { margin: 0; padding: 0; width: 100%; height: 100%; background: #0F172A; }
                .vehicle-marker-wrapper {
                    width: 52px;
                    height: 52px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    filter: drop-shadow(0px 6px 14px rgba(0, 0, 0, 0.65));
                }
            </style>
        </head>
        <body>
            <div id="map"></div>
            <script>
                if (maplibregl.getRTLTextPluginStatus() === 'unavailable') {
                    maplibregl.setRTLTextPlugin(
                        'https://unpkg.com/@mapbox/mapbox-gl-rtl-text@0.2.3/mapbox-gl-rtl-text.min.js',
                        null,
                        true
                    );
                }

                var map = new maplibregl.Map({
                    container: 'map',
                    style: 'https://map.intaleqapp.com/style.json',
                    center: [35.9106, 31.9539],
                    zoom: 18.2,
                    pitch: 50.0,
                    bearing: 0,
                    attributionControl: false
                });

                var vehicleMarker = null;
                var vehicleEl = null;

                map.on('load', function() {
                    vehicleEl = document.createElement('div');
                    vehicleEl.className = 'vehicle-marker-wrapper';
                    vehicleEl.innerHTML = '<svg width="48" height="48" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg"><circle cx="24" cy="24" r="21" fill="white" stroke="#0071E3" stroke-width="3"/><path d="M24 7L13 37L24 30L35 37L24 7Z" fill="#0071E3" stroke="#005bb5" stroke-width="2" stroke-linejoin="round"/></svg>';

                    vehicleMarker = new maplibregl.Marker({
                        element: vehicleEl,
                        rotationAlignment: 'map',
                        pitchAlignment: 'map'
                    })
                    .setLngLat([35.9106, 31.9539])
                    .addTo(map);

                    map.addSource('nav-route-source', {
                        type: 'geojson',
                        data: { type: 'Feature', geometry: { type: 'LineString', coordinates: [] } }
                    });

                    map.addLayer({
                        id: 'nav-route-casing',
                        type: 'line',
                        source: 'nav-route-source',
                        layout: { 'line-join': 'round', 'line-cap': 'round' },
                        paint: { 'line-color': '#FFFFFF', 'line-width': 10.0 }
                    });

                    map.addLayer({
                        id: 'nav-route-line',
                        type: 'line',
                        source: 'nav-route-source',
                        layout: { 'line-join': 'round', 'line-cap': 'round' },
                        paint: { 'line-color': '#0071E3', 'line-width': 6.5 }
                    });
                });

                function setRoute(coordsJson) {
                    try {
                        var coords = JSON.parse(coordsJson);
                        var source = map.getSource('nav-route-source');
                        if (source) {
                            source.setData({
                                type: 'Feature',
                                geometry: { type: 'LineString', coordinates: coords }
                            });
                        }
                    } catch(e) {}
                }

                function calculateSmartZoom(speed) {
                    if (speed <= 0) return 18.8;
                    if (speed < 25) return 19.0 - (speed / 25.0) * 0.8;
                    if (speed < 60) return 18.2 - ((speed - 25.0) / 35.0) * 0.7;
                    if (speed < 100) return 17.5 - ((speed - 60.0) / 40.0) * 0.8;
                    return 16.5;
                }

                function updateVehiclePosition(lat, lng, heading, speed) {
                    if (vehicleMarker) {
                        vehicleMarker.setLngLat([lng, lat]);
                        if (heading >= 0) {
                            vehicleMarker.setRotation(heading);
                        }
                    }
                    var targetBearing = heading >= 0 ? heading : map.getBearing();
                    var targetZoom = calculateSmartZoom(typeof speed === 'number' ? speed : 0);

                    map.easeTo({
                        center: [lng, lat],
                        bearing: targetBearing,
                        pitch: 50.0,
                        zoom: targetZoom,
                        duration: 350
                    });
                }
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: "https://map.intaleqapp.com"))
    }

    private func setupHUD() {
        navView = SiroNavView(frame: view.bounds)
        navView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        navView.locale = "ar"
        navView.showFareMetrics = true
        navView.isHidden = true
        navView.onExit = { [weak self] in
            self?.stopNavigation()
        }
        view.addSubview(navView)
    }

    private func setupLaunchScreenUI() {
        titleLabel = UILabel()
        titleLabel.text = "Siro Nav Demo (iOS Swift)"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        subtitleLabel = UILabel()
        subtitleLabel.text = "تجربة الملاحة الحية، التوجيه الصوتي العربي، وعدّاد الأجرة"
        subtitleLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        startButton = UIButton(type: .system)
        startButton.setTitle("بدء الرحلة التجريبية (SIMULATED NAV)", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        startButton.backgroundColor = UIColor(red: 2/255, green: 132/255, blue: 199/255, alpha: 1.0)
        startButton.layer.cornerRadius = 14
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(didTapStartNav), for: .touchUpInside)
        view.addSubview(startButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            startButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            startButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc private func didTapStartNav() {
        startButton.isEnabled = false
        startButton.setTitle("جاري حساب المسار الملتزم بالشبكة الطرقية...", for: .normal)

        let origin = NavPoint(latitude: 31.9539, longitude: 35.9106)
        let destination = NavPoint(latitude: 31.9650, longitude: 35.8900)

        Task {
            do {
                let routingClient = RoutingClient(config: self.navController.config)
                let route = try await routingClient.getRoute(origin: origin, destination: destination, locale: "ar")

                await MainActor.run {
                    self.titleLabel.isHidden = true
                    self.subtitleLabel.isHidden = true
                    self.startButton.isHidden = true
                    self.navView.isHidden = false

                    // Custom Fare Config: Base fare 0.50, Per KM 0.35, Per min waiting 0.05, JOD currency
                    let fare = NavFareConfig(
                        baseFare: 0.50,
                        perKilometer: 0.35,
                        perWaitingMinute: 0.05,
                        currency: "JOD",
                        waitingSpeedKmh: 5.0
                    )

                    _ = self.navController.startNavigation(route: route, fare: fare)

                    // Draw route polyline in webview
                    var coords: [[Double]] = []
                    for pt in route.polyline {
                        coords.append([pt.longitude, pt.latitude])
                    }
                    if let data = try? JSONSerialization.data(withJSONObject: coords),
                       let jsonStr = String(data: data, encoding: .utf8) {
                        self.webView.evaluateJavaScript("setRoute('\(jsonStr)');")
                    }

                    // Start Route Simulation
                    let simulator = NavRouteSimulator(route: route, speedKmh: 45.0)
                    self.fixes = simulator.generateSimulatedFixes(stepIntervalSeconds: 0.35)
                    self.currentFixIndex = 0

                    self.simTimer?.invalidate()
                    self.simTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] t in
                        guard let self = self, self.navController.isNavigating else {
                            t.invalidate()
                            return
                        }
                        if self.currentFixIndex >= self.fixes.count {
                            t.invalidate()
                            return
                        }
                        let fix = self.fixes[self.currentFixIndex]
                        self.currentFixIndex += 1

                        let loc = CLLocation(
                            coordinate: CLLocationCoordinate2D(latitude: fix.latitude, longitude: fix.longitude),
                            altitude: fix.altitude,
                            horizontalAccuracy: fix.accuracy,
                            verticalAccuracy: 5.0,
                            course: fix.heading,
                            speed: (fix.speedKmh / 3.6),
                            timestamp: fix.timestamp
                        )
                        self.navController.updateLocation(loc)

                        // Update Vehicle in map view
                        self.webView.evaluateJavaScript("updateVehiclePosition(\(fix.latitude), \(fix.longitude), \(fix.heading), \(fix.speedKmh));")
                    }
                }
            } catch {
                await MainActor.run {
                    self.startButton.isEnabled = true
                    self.startButton.setTitle("إعادة المحاولة", for: .normal)
                    print("[ViewController] Routing error: \(error)")
                }
            }
        }
    }

    private func stopNavigation() {
        simTimer?.invalidate()
        simTimer = nil
        navController.stopNavigation()
        navView.isHidden = true
        titleLabel.isHidden = false
        subtitleLabel.isHidden = false
        startButton.isHidden = false
        startButton.isEnabled = true
        startButton.setTitle("بدء الرحلة التجريبية (SIMULATED NAV)", for: .normal)
    }

    // MARK: - SiroNavListener
    func onInstructionChanged(_ instruction: NavInstructionEvent) {
        DispatchQueue.main.async {
            self.navView.updateInstruction(instruction)
        }
    }

    func onProgressUpdated(_ progress: NavProgressEvent) {
        DispatchQueue.main.async {
            self.navView.updateProgress(
                progress,
                totals: self.navController.lastTripTotals,
                startTime: self.navController.tripStartTime
            )
        }
    }

    func onSpeedExceeded(currentSpeed: Double, speedLimit: Double) {}
    func onCameraApproaching(camera: SpeedCamera, distance: Double) {}
    func onTripArrived(totals: NavTripTotals) {}
    func onError(_ error: String) {}

        // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[WKWebView] didFail: \(error)")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[WKWebView] didFailProvisionalNavigation: \(error)")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[WKWebView] didFinish")
    }

    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {}
}
