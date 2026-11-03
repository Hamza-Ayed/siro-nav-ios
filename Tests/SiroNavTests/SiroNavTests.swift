import XCTest
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
}
