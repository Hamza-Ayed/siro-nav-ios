# Siro Nav for iOS (Swift)
### نظام الملاحة التوجيهية الحية لمنصة خرائط سيرو على iOS

[![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

In-app turn-by-turn navigation on **Siro Maps**, tailored for ride-hailing and delivery apps. The driver never leaves your app: the route, map matching, Arabic voice guidance, and trip meter all run seamlessly natively in Swift.

---

## 🚀 Key Features / المميزات الرئيسية

1. **Sub-second Map Matching**: High-performance forward-window map snapping onto route polyline with continuous off-route deviation tracking and auto-rerouting.
2. **Offline Bundled Arabic Voice Engine**: 93 pre-baked studio audio prompts in Arabic (`ar`) covering turns, distance alerts, speed limits, fixed speed cameras, and ride phases.
3. **Trip Meter & Tariff Engine**: Built-in meter for distance (in km) and waiting minutes (below speed threshold), auto-calculating fare with custom tariffs (JOD/SAR/USD).
4. **Speed Camera & Radar Warnings**: Lookahead detection (500m / 300m) for fixed and mobile radars with overspeed tolerance enforcement.
5. **Drop-in UI Component (`SiroNavView`)**: Native Swift HUD overlay with maneuver banners, distance counters, dynamic speed badge, and ride controls.
6. **Commercial API Licensing**: Enterprise API key gated licensing with automatic telemetry probe collector for fleet intelligence.

---

## 📦 Installation / التثبيت

### Swift Package Manager (SPM)
In Xcode, go to **File > Add Package Dependencies...** and enter the repository URL:
```text
https://github.com/Hamza-Ayed/siro-nav-ios.git
```

Or add to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/Hamza-Ayed/siro-nav-ios.git", from: "0.1.0")
]
```

### CocoaPods
```ruby
pod 'SiroNav', :git => 'https://github.com/Hamza-Ayed/siro-nav-ios.git'
```

---

## 🛠️ Quick Start / دليل البدء السريع

```swift
import SiroNav
import CoreLocation

// 1. Initialize Controller with API Key
let config = NavConfig(
    apiKey: "YOUR_SIRO_API_KEY",
    baseUrl: "https://map-saas.intaleqapp.com/api"
)
let navController = SiroNavController(config: config)

// 2. Start Turn-by-Turn Navigation with Ride Fare Config
let fareConfig = NavFareConfig(
    baseFare: 0.50,
    perKilometer: 0.35,
    perWaitingMinute: 0.05,
    currency: "JOD"
)

let started = navController.startNavigation(route: activeRoute, fare: fareConfig)
if !started {
    print("Navigation start failed: \(navController.activeError ?? "Unknown error")")
}

// 3. Feed GPS updates (e.g. from CLLocationManager)
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    navController.updateLocation(location)
}

// 4. Present Drop-in HUD View
let navView = SiroNavView(frame: view.bounds)
navView.onExit = {
    navController.stopNavigation()
    navView.removeFromSuperview()
}
view.addSubview(navView)
```

---

## 🧪 Testing

Run test suite:
```bash
swift test
```

---

## 📄 License
MIT License. © 2026 Siro Platform & Hamza Ayed.
