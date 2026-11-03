import Foundation

public struct SnappedResult: Equatable, Sendable {
    public let snappedPoint: NavPoint
    public let segmentIndex: Int
    public let crossTrackDistanceMeters: Double
    public let distanceAlongRouteMeters: Double

    public init(
        snappedPoint: NavPoint,
        segmentIndex: Int,
        crossTrackDistanceMeters: Double,
        distanceAlongRouteMeters: Double
    ) {
        self.snappedPoint = snappedPoint
        self.segmentIndex = segmentIndex
        self.crossTrackDistanceMeters = crossTrackDistanceMeters
        self.distanceAlongRouteMeters = distanceAlongRouteMeters
    }
}

public struct MapMatcher {
    private static let windowLookahead = 30
    private static let windowLookbehind = 5
    private static let nearTieMeters = 15.0

    public static func snapToPolyline(
        rawPoint: NavPoint,
        polyline: [NavPoint],
        lastKnownSegmentIndex: Int = 0
    ) -> SnappedResult {
        if polyline.isEmpty {
            return SnappedResult(
                snappedPoint: rawPoint,
                segmentIndex: 0,
                crossTrackDistanceMeters: 0.0,
                distanceAlongRouteMeters: 0.0
            )
        }

        if polyline.count == 1 {
            let dist = rawPoint.distance(to: polyline[0])
            return SnappedResult(
                snappedPoint: polyline[0],
                segmentIndex: 0,
                crossTrackDistanceMeters: dist,
                distanceAlongRouteMeters: 0.0
            )
        }

        let totalSegments = polyline.count - 1
        let startIdx = max(0, lastKnownSegmentIndex - windowLookbehind)
        let endIdx = min(totalSegments, lastKnownSegmentIndex + windowLookahead)

        var minDistance = Double.infinity
        for i in startIdx..<endIdx {
            let projected = projectPointOnSegment(rawPoint, polyline[i], polyline[i + 1])
            let dist = rawPoint.distance(to: projected)
            if dist < minDistance {
                minDistance = dist
            }
        }

        var bestSegmentIndex = min(max(0, lastKnownSegmentIndex), totalSegments - 1)
        var bestDistance = minDistance
        var bestSnappedPoint = rawPoint

        for i in startIdx..<endIdx {
            let projected = projectPointOnSegment(rawPoint, polyline[i], polyline[i + 1])
            let dist = rawPoint.distance(to: projected)
            if dist <= minDistance + nearTieMeters {
                bestSegmentIndex = i
                bestDistance = dist
                bestSnappedPoint = projected
                break
            }
        }

        var distanceAlongRoute = 0.0
        for i in 0..<bestSegmentIndex {
            distanceAlongRoute += polyline[i].distance(to: polyline[i + 1])
        }
        distanceAlongRoute += polyline[bestSegmentIndex].distance(to: bestSnappedPoint)

        return SnappedResult(
            snappedPoint: bestSnappedPoint,
            segmentIndex: bestSegmentIndex,
            crossTrackDistanceMeters: bestDistance,
            distanceAlongRouteMeters: distanceAlongRoute
        )
    }

    private static func projectPointOnSegment(_ p: NavPoint, _ a: NavPoint, _ b: NavPoint) -> NavPoint {
        let dx = b.longitude - a.longitude
        let dy = b.latitude - a.latitude

        if dx == 0 && dy == 0 {
            return a
        }

        let t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / (dx * dx + dy * dy)
        let clampedT = min(max(0.0, t), 1.0)

        let projLng = a.longitude + clampedT * dx
        let projLat = a.latitude + clampedT * dy
        let segmentBearing = a.bearing(to: b)

        return NavPoint(
            latitude: projLat,
            longitude: projLng,
            heading: segmentBearing,
            speedKmh: p.speedKmh,
            altitude: a.altitude + clampedT * (b.altitude - a.altitude),
            accuracy: p.accuracy,
            timestamp: p.timestamp
        )
    }
}
