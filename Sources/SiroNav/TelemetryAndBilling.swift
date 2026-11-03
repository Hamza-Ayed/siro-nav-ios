import Foundation

public struct NavFareConfig: Equatable, Sendable {
    public let baseFare: Double
    public let perKilometer: Double
    public let perWaitingMinute: Double
    public let currency: String
    public let waitingSpeedKmh: Double

    public init(
        baseFare: Double = 0.0,
        perKilometer: Double,
        perWaitingMinute: Double,
        currency: String = "JOD",
        waitingSpeedKmh: Double = 5.0
    ) {
        self.baseFare = baseFare
        self.perKilometer = perKilometer
        self.perWaitingMinute = perWaitingMinute
        self.currency = currency
        self.waitingSpeedKmh = waitingSpeedKmh
    }
}

public struct NavTripTotals: Equatable, Sendable {
    public let distanceKm: Double
    public let waitingMinutes: Double
    public let fare: Double
    public let currency: String

    public init(distanceKm: Double, waitingMinutes: Double, fare: Double, currency: String) {
        self.distanceKm = distanceKm
        self.waitingMinutes = waitingMinutes
        self.fare = fare
        self.currency = currency
    }

    public var fareLabel: String {
        return String(format: "%.2f %@", fare, currency)
    }
}

public final class NavTripMeter: @unchecked Sendable {
    public let config: NavFareConfig
    private let maxAccuracyMeters: Double = 50.0
    private let countStepMeters: Double = 10.0
    private let maxGapSeconds: TimeInterval = 30.0

    private var anchor: NavPoint?
    private var last: NavPoint?
    private var distanceMeters: Double = 0.0
    private var waitingSeconds: Double = 0.0

    public init(config: NavFareConfig) {
        self.config = config
    }

    public func addFix(_ fix: NavPoint) -> NavTripTotals {
        guard fix.accuracy <= maxAccuracyMeters else { return totals }

        guard let prevLast = last, let prevAnchor = anchor else {
            last = fix
            anchor = fix
            return totals
        }

        last = fix
        let elapsed = fix.timestamp.timeIntervalSince(prevLast.timestamp)
        guard elapsed > 0 else { return totals }

        if elapsed > maxGapSeconds {
            anchor = fix
            return totals
        }

        let moved = prevAnchor.distance(to: fix)
        if moved >= countStepMeters {
            distanceMeters += moved
            anchor = fix
        } else if fix.speedKmh < config.waitingSpeedKmh {
            waitingSeconds += elapsed
        }

        return totals
    }

    public var totals: NavTripTotals {
        let km = distanceMeters / 1000.0
        let minutes = waitingSeconds / 60.0
        let fare = config.baseFare + (config.perKilometer * km) + (config.perWaitingMinute * minutes)
        return NavTripTotals(
            distanceKm: km,
            waitingMinutes: minutes,
            fare: fare,
            currency: config.currency
        )
    }
}

public final class TelemetryCollector: @unchecked Sendable {
    public let config: NavConfig
    private var buffer: [NavPoint] = []
    private var cumulativeDistance: Double = 0.0
    private var lastRecordedPoint: NavPoint?

    public init(config: NavConfig) {
        self.config = config
    }

    public var bufferedCount: Int { buffer.count }
    public var cumulativeDistanceMeters: Double { cumulativeDistance }

    public func recordPoint(_ point: NavPoint) {
        if let last = lastRecordedPoint {
            let dist = last.distance(to: point)
            cumulativeDistance += dist
        }
        lastRecordedPoint = point
        buffer.append(point)

        if buffer.count >= config.telemetryBatchSize {
            flush()
        }
    }

    public func flush() {
        buffer.removeAll()
    }
}
