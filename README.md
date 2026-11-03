# Siro Nav for iOS (Swift)
### حزمة الملاحة التوجيهية الحية لنظام iOS (Native Swift • iOS 14+)

[![Platform](https://img.shields.io/badge/Platform-iOS%2014.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Maps](https://img.shields.io/badge/Maps-Siro%20Limestone%20Vector-purple.svg)](https://map.intaleqapp.com)

حزمة ملاحة أصلية عالية الأداء مبنية بلغة **Swift** لنظام iOS، مخصصة لتطبيقات النقل الذكي والتوصيل (Ride-Hailing & Delivery). توفر تجربة ملاحة متكاملة داخل التطبيق على نمط خرائط سيرو (Siro Limestone 3D) مع الصوت العربي المسجل استوديو، التوجيه الذكي للدواوير والمخارج، وعداد احتساب الأجرة والانتظار اللحظي.

---

## 📸 معاينة حية للمحرك على محاكي الآيفون (Live iOS Simulator Visuals)

<div align="center">
  <img src="docs/media/screen_ios_simulator_roundabout.png" width="370" alt="Siro Nav iOS Roundabout Polyline" />
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/media/screen_ios_simulator_fare_progression.png" width="370" alt="Siro Nav iOS Fare Progression HUD" />
</div>

- **خط المسار الأزرق الملاحي (Blue Route Polyline)**: مع إطار أبيض عالي التباين بسماكة 12px يلتف بسلاسة مع مسار الدوار والتقاطعات.
- **توجيه الدواوير الصوتي الذكي**: استخراج رقم المخرج ونطقه بالصوت الاستوديو العربي (`عند الدوار، اسلك المخرج السادس إلى شارع الكلية العلمية الإسلامية`).
- **ماركر السائق وسهم التوجيه**: قرص دائري أبيض بظل ثلاثي الأبعاد مع سهم ملاحة أزرق يتجه فورياً مع زاوية الـ Heading.
- **لوحة الأجرة التراكمية المباشرة**: احتساب فتحة العداد، الكيلومترات، ودقائق الانتظار عند التوقف أو السرعة البطيئة.
- **عداد السرعة المرتفع**: شارة دائرية بارزة واضحة للسائق أثناء القيادة مع حلقة حمراء تحذيرية.

---

## 📦 التثبيت (Installation)

### Swift Package Manager (SPM)
في Xcode، اذهب إلى **File > Add Package Dependencies...** وأدخل رابط المستودع:
```text
https://github.com/Hamza-Ayed/siro-nav-ios.git
```

أو أضف إلى ملف `Package.swift`:
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

## ⚡ البدء السريع في ٥ أسطر (Quick Start)

### ١. إعداد المتحكم وتحديد تسعيرة الرحلة للمطور (Fare Config)

```swift
import SiroNav
import CoreLocation

// تهيئة المتحكم مع مفتاح منصة سيرو
let config = NavConfig(
    apiKey: "YOUR_SIRO_API_KEY",
    baseUrl: "https://map-saas.intaleqapp.com/api"
)
let navController = SiroNavController(config: config)

// خيارات التسعير والفوترة للمطور
let fareConfig = NavFareConfig(
    baseFare: 0.50,            // فتحة العداد المبدئية
    perKilometer: 0.35,        // سعر الكيلومتر
    perWaitingMinute: 0.05,    // سعر دقيقة الانتظار (عند سرعة < 5 كم/س)
    currency: "JOD",           // العملة: JOD, SAR, AED, USD
    waitingSpeedKmh: 5.0
)

// بدء الملاحة
navController.startNavigation(route: activeRoute, fare: fareConfig)
```

### ٢. إضافة واجهة الملاحة الجاهزة (`SiroNavView`)

```swift
let navView = SiroNavView(frame: view.bounds)
navView.locale = "ar"              // لغة الواجهة والصوت (ar / en)
navView.showFareMetrics = true     // إظهار شريط الأجرة والمسافة للمطور

navView.onExit = { [weak self] in
    navController.stopNavigation()
    navView.removeFromSuperview()
}
view.addSubview(navView)
```

### ٣. ربط الأحداث وتحديث الموقع من الـ GPS

```swift
navController.listener = self

// تحديث الموقع عند وصول إشارة GPS
func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    navController.updateLocation(location)
}

// الاستماع لأحداث الملاحة
func onInstructionChanged(_ instruction: NavInstructionEvent) {
    navView.updateInstruction(instruction)
}

func onProgressUpdated(_ progress: NavProgressEvent) {
    navView.updateProgress(
        progress,
        totals: navController.lastTripTotals,
        startTime: navController.tripStartTime
    )
}

func onTripArrived(totals: NavTripTotals) {
    print("تم الوصول! إجمالي الأجرة: \(totals.fareLabel)")
}
```

---

## 🧪 تشغيل الاختبارات الآلية (Unit Tests)

```bash
swift test
```

---

## 📄 الترخيص (License)
MIT License. © 2026 Siro Maps & Hamza Ayed.
