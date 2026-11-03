import Foundation
import CoreLocation

/// Geographic point for navigation and telemetry.
public struct NavPoint: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let heading: Double
    public let speedKmh: Double
    public let altitude: Double
    public let accuracy: Double
    public let timestamp: Date

    public init(
        latitude: Double,
        longitude: Double,
        heading: Double = 0.0,
        speedKmh: Double = 0.0,
        altitude: Double = 0.0,
        accuracy: Double = 5.0,
        timestamp: Date = Date()
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.heading = heading
        self.speedKmh = speedKmh
        self.altitude = altitude
        self.accuracy = accuracy
        self.timestamp = timestamp
    }

    public static func fromCoordinate(_ coordinate: CLLocationCoordinate2D, time: Date = Date()) -> NavPoint {
        return NavPoint(latitude: coordinate.latitude, longitude: coordinate.longitude, timestamp: time)
    }

    /// Haversine formula calculation in meters.
    public func distance(to other: NavPoint) -> Double {
        let earthRadiusMeters = 6371000.0
        let dLat = (other.latitude - latitude) * (.pi / 180.0)
        let dLng = (other.longitude - longitude) * (.pi / 180.0)

        let lat1 = latitude * (.pi / 180.0)
        let lat2 = other.latitude * (.pi / 180.0)

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * c
    }

    /// Forward bearing in degrees (0..360).
    public func bearing(to other: NavPoint) -> Double {
        let lat1 = latitude * (.pi / 180.0)
        let lat2 = other.latitude * (.pi / 180.0)
        let dLng = (other.longitude - longitude) * (.pi / 180.0)

        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        let initialBearing = atan2(y, x) * (180.0 / .pi)
        return (initialBearing + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
}

/// Navigation configuration for API access and thresholds.
public struct NavConfig: Equatable, Sendable {
    public let apiKey: String
    public let baseUrl: String
    public let offRouteThresholdMeters: Double
    public let offRouteDebounceSeconds: Int
    public let overspeedToleranceKmh: Double
    public let telemetryBatchSize: Int

    public init(
        apiKey: String,
        baseUrl: String = "https://map-saas.intaleqapp.com/api",
        offRouteThresholdMeters: Double = 30.0,
        offRouteDebounceSeconds: Int = 3,
        overspeedToleranceKmh: Double = 5.0,
        telemetryBatchSize: Int = 10
    ) {
        self.apiKey = apiKey
        self.baseUrl = baseUrl
        self.offRouteThresholdMeters = offRouteThresholdMeters
        self.offRouteDebounceSeconds = offRouteDebounceSeconds
        self.overspeedToleranceKmh = overspeedToleranceKmh
        self.telemetryBatchSize = telemetryBatchSize
    }
}

/// Turn-by-turn maneuver step.
public struct NavStep: Codable, Equatable, Sendable {
    public let index: Int
    public let instruction: String
    public let streetName: String
    public let maneuverType: Int
    public let exitNumber: Int?
    public let distanceMeters: Double
    public let durationSeconds: Double
    public let lat: Double
    public let lng: Double
    public let coordinateInterval: [Int]

    public init(
        index: Int,
        instruction: String,
        streetName: String = "",
        maneuverType: Int = 0,
        exitNumber: Int? = nil,
        distanceMeters: Double = 0.0,
        durationSeconds: Double = 0.0,
        lat: Double = 0.0,
        lng: Double = 0.0,
        coordinateInterval: [Int] = [0, 0]
    ) {
        self.index = index
        self.instruction = instruction
        self.streetName = streetName
        self.maneuverType = maneuverType
        self.exitNumber = exitNumber
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.lat = lat
        self.lng = lng
        self.coordinateInterval = coordinateInterval
    }
}

/// Fixed or mobile speed enforcement camera on the route.
public struct SpeedCamera: Codable, Equatable, Sendable {
    public let id: String
    public let speedLimitKmh: Double
    public let lat: Double
    public let lng: Double

    public init(id: String, speedLimitKmh: Double, lat: Double, lng: Double) {
        self.id = id
        self.speedLimitKmh = speedLimitKmh
        self.lat = lat
        self.lng = lng
    }
}

/// Route model representing parsed geometry and maneuvers.
public struct NavRoute: Equatable, Sendable {
    public let id: String
    public let routeName: String
    public let polyline: [NavPoint]
    public let steps: [NavStep]
    public let speedCameras: [SpeedCamera]
    public let totalDistanceMeters: Double
    public let totalDurationSeconds: Double

    public init(
        id: String,
        routeName: String = "",
        polyline: [NavPoint],
        steps: [NavStep] = [],
        speedCameras: [SpeedCamera] = [],
        totalDistanceMeters: Double,
        totalDurationSeconds: Double
    ) {
        self.id = id
        self.routeName = routeName
        self.polyline = polyline
        self.steps = steps
        self.speedCameras = speedCameras
        self.totalDistanceMeters = totalDistanceMeters
        self.totalDurationSeconds = totalDurationSeconds
    }

    public var isEmpty: Bool { polyline.isEmpty }
    public var isNotEmpty: Bool { !polyline.isEmpty }
}
