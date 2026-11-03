import XCTest
import CoreLocation
@testable import SiroNav

final class SiroNavTests: XCTestCase {

    func testPolylineDecoding() throws {
        let points = try PolylineCodec.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(round(points[0].latitude * 100000) / 100000, 38.5)
        XCTAssertEqual(round(points[0].longitude * 100000) / 100000, -120.2)
    }

    func testGeodesicDistanceAndBearing() {
        let p1 = NavPoint(latitude: 31.9539, longitude: 35.9106)
        let p2 = NavPoint(latitude: 31.9735, longitude: 35.9235)

        let dist = p1.distance(to: p2)
        XCTAssertGreaterThan(dist, 2000.0)
        XCTAssertLessThan(dist, 3000.0)

        let bearing = p1.bearing(to: p2)
        XCTAssertGreaterThan(bearing, 0.0)
        XCTAssertLessThan(bearing, 90.0)
    }

    func testMapMatcherSnapping() {
        let polyline = [
            NavPoint(latitude: 31.9500, longitude: 35.9100),
            NavPoint(latitude: 31.9600, longitude: 35.9100),
            NavPoint(latitude: 31.9700, longitude: 35.9100)
        ]

        let raw = NavPoint(latitude: 31.9550, longitude: 35.9105)
        let snapped = MapMatcher.snapToPolyline(rawPoint: raw, polyline: polyline)

        XCTAssertEqual(snapped.segmentIndex, 0)
        XCTAssertGreaterThan(snapped.crossTrackDistanceMeters, 20.0)
        XCTAssertLessThan(snapped.crossTrackDistanceMeters, 60.0)
        XCTAssertEqual(round(snapped.snappedPoint.longitude * 10000) / 10000, 35.9100)
    }

    func testApiKeyLicensingValidation() {
        let engineInvalid = NavigationEngine(config: NavConfig(apiKey: ""))
        let dummyRoute = NavRoute(
            id: "r1",
            polyline: [NavPoint(latitude: 31.95, longitude: 35.91)],
            totalDistanceMeters: 100,
            totalDurationSeconds: 10
        )
        XCTAssertFalse(engineInvalid.startNavigation(route: dummyRoute))

        let engineValid = NavigationEngine(config: NavConfig(apiKey: "valid_commercial_key_123"))
        XCTAssertTrue(engineValid.startNavigation(route: dummyRoute))
    }

    func testTripMeterBillingCalculations() {
        let config = NavFareConfig(
            baseFare: 0.5,
            perKilometer: 0.35,
            perWaitingMinute: 0.05,
            currency: "JOD"
        )
        let meter = NavTripMeter(config: config)
        let t0 = Date()

        var lat = 31.9
        _ = meter.addFix(NavPoint(latitude: lat, longitude: 35.9, speedKmh: 40, accuracy: 5, timestamp: t0))

        for i in 1...20 {
            lat += 0.0005
            _ = meter.addFix(NavPoint(latitude: lat, longitude: 35.9, speedKmh: 40, accuracy: 5, timestamp: t0.addingTimeInterval(Double(i))))
        }

        let totals = meter.totals
        XCTAssertEqual(totals.distanceKm, 1.1, accuracy: 0.08)
        XCTAssertEqual(totals.waitingMinutes, 0.0, accuracy: 0.001)
        XCTAssertGreaterThan(totals.fare, 0.5)
        XCTAssertEqual(totals.currency, "JOD")
    }

    func testSpeedCameraAlerting() {
        let tracker = CameraTracker()
        let cam = SpeedCamera(id: "cam_1", speedLimitKmh: 80.0, lat: 31.9550, lng: 35.9100)
        let pos = NavPoint(latitude: 31.9540, longitude: 35.9100, speedKmh: 95.0)

        let events = tracker.checkCameras(currentPosition: pos, cameras: [cam], overspeedToleranceKmh: 5.0)
        XCTAssertGreaterThanOrEqual(events.count, 1)
    }

    func testSimulatedTripFlow() {
        let poly = [
            NavPoint(latitude: 31.9539, longitude: 35.9106),
            NavPoint(latitude: 31.9560, longitude: 35.9120),
            NavPoint(latitude: 31.9580, longitude: 35.9140)
        ]
        let step1 = NavStep(
            index: 0,
            instruction: "اتجه نحو الشمال على شارع زهران",
            streetName: "شارع زهران",
            maneuverType: 0,
            distanceMeters: 400.0,
            durationSeconds: 30.0,
            lat: 31.9560,
            lng: 35.9120
        )
        let route = NavRoute(
            id: "route_amman_sample",
            routeName: "طريق تجريبي عمان",
            polyline: poly,
            steps: [step1],
            totalDistanceMeters: 800.0,
            totalDurationSeconds: 60.0
        )

        let config = NavConfig(apiKey: "live_test_key_123")
        let controller = SiroNavController(config: config)
        let fare = NavFareConfig(baseFare: 0.50, perKilometer: 0.35, perWaitingMinute: 0.05, currency: "JOD")

        final class MockListener: SiroNavListener {
            var instructionsCount = 0
            var progressCount = 0
            var arrived = false
            var finalTotals: NavTripTotals?

            func onInstructionChanged(_ instruction: NavInstructionEvent) { instructionsCount += 1 }
            func onProgressUpdated(_ progress: NavProgressEvent) { progressCount += 1 }
            func onSpeedExceeded(currentSpeed: Double, speedLimit: Double) {}
            func onCameraApproaching(camera: SpeedCamera, distance: Double) {}
            func onTripArrived(totals: NavTripTotals) {
                arrived = true
                finalTotals = totals
            }
            func onError(_ error: String) {}
        }

        let listener = MockListener()
        controller.listener = listener

        let started = controller.startNavigation(route: route, fare: fare)
        XCTAssertTrue(started)
        XCTAssertTrue(controller.isNavigating)

        let simulator = NavRouteSimulator(route: route, speedKmh: 60.0)
        let fixes = simulator.generateSimulatedFixes(stepIntervalSeconds: 0.5)
        XCTAssertGreaterThan(fixes.count, 2)

        for fix in fixes {
            controller.updateLocation(CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: fix.latitude, longitude: fix.longitude),
                altitude: fix.altitude,
                horizontalAccuracy: fix.accuracy,
                verticalAccuracy: 5.0,
                course: fix.heading,
                speed: (fix.speedKmh / 3.6),
                timestamp: fix.timestamp
            ))
        }

        XCTAssertTrue(listener.progressCount > 0)
        XCTAssertTrue(listener.arrived)
        XCTAssertNotNil(listener.finalTotals)
        XCTAssertGreaterThan(listener.finalTotals!.distanceKm, 0.4)
        XCTAssertGreaterThan(listener.finalTotals!.fare, 0.50)
    }
}
