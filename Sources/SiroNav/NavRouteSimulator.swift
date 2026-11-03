import Foundation

/// Simulates driving along a route at a set speed for testing and UI previews without physical driving.
public final class NavRouteSimulator: @unchecked Sendable {
    public let route: NavRoute
    public let speedKmh: Double
    private var currentIndex: Int = 0
    private var isSimulating: Bool = false
    private var timer: Timer?

    public init(route: NavRoute, speedKmh: Double = 60.0) {
        self.route = route
        self.speedKmh = speedKmh
    }

    /// Interpolates fixes along the polyline.
    public func generateSimulatedFixes(stepIntervalSeconds: TimeInterval = 1.0) -> [NavPoint] {
        guard route.polyline.count > 1 else { return route.polyline }
        var fixes: [NavPoint] = []
        let speedMps = (speedKmh * 1000.0) / 3600.0
        let stepDist = speedMps * stepIntervalSeconds
        var baseTime = Date()

        for i in 0..<(route.polyline.count - 1) {
            let p1 = route.polyline[i]
            let p2 = route.polyline[i + 1]
            let segmentDist = p1.distance(to: p2)
            let bearing = p1.bearing(to: p2)

            fixes.append(NavPoint(
                latitude: p1.latitude,
                longitude: p1.longitude,
                heading: bearing,
                speedKmh: speedKmh,
                altitude: p1.altitude,
                accuracy: 3.0,
                timestamp: baseTime
            ))

            if segmentDist > stepDist {
                let steps = Int(segmentDist / stepDist)
                for s in 1...steps {
                    baseTime = baseTime.addingTimeInterval(stepIntervalSeconds)
                    let frac = Double(s) * stepDist / segmentDist
                    let lat = p1.latitude + frac * (p2.latitude - p1.latitude)
                    let lng = p1.longitude + frac * (p2.longitude - p1.longitude)
                    fixes.append(NavPoint(
                        latitude: lat,
                        longitude: lng,
                        heading: bearing,
                        speedKmh: speedKmh,
                        altitude: p1.altitude,
                        accuracy: 3.0,
                        timestamp: baseTime
                    ))
                }
            }
            baseTime = baseTime.addingTimeInterval(stepIntervalSeconds)
        }

        if let last = route.polyline.last {
            fixes.append(NavPoint(
                latitude: last.latitude,
                longitude: last.longitude,
                heading: fixes.last?.heading ?? 0.0,
                speedKmh: 0.0,
                altitude: last.altitude,
                accuracy: 3.0,
                timestamp: baseTime
            ))
        }

        return fixes
    }
}
