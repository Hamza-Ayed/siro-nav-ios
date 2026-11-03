import Foundation

public enum NavigationStatus: Sendable {
    case idle
    case authenticating
    case navigating
    case rerouting
    case arrived
    case error
}

public protocol NavigationEngineDelegate: AnyObject {
    func navigationEngine(_ engine: NavigationEngine, didReceiveEvent event: NavEvent)
}

public final class NavigationEngine: @unchecked Sendable {
    public let config: NavConfig
    public weak var delegate: NavigationEngineDelegate?

    private let telemetryCollector: TelemetryCollector
    private let instructionScheduler = InstructionScheduler()
    private let cameraTracker = CameraTracker()

    private(set) public var status: NavigationStatus = .idle
    private(set) public var activeRoute: NavRoute?
    private(set) public var currentStepIndex: Int = 0
    private(set) public var lastKnownSegmentIndex: Int = 0
    private(set) public var displayPoint: NavPoint?

    private var offRouteStartTime: Date?
    private var isRerouting = false

    public init(config: NavConfig) {
        self.config = config
        self.telemetryCollector = TelemetryCollector(config: config)
    }

    public var cumulativeDistanceMeters: Double {
        telemetryCollector.cumulativeDistanceMeters
    }

    public func startNavigation(route: NavRoute) -> Bool {
        status = .authenticating

        // Licensing check
        let trimmedKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty || trimmedKey.contains(" ") {
            status = .error
            delegate?.navigationEngine(self, didReceiveEvent: .authError("ERR_INVALID_API_KEY", "Siro Maps API key is invalid or empty"))
            return false
        }

        guard route.isNotEmpty else {
            status = .error
            return false
        }

        activeRoute = route
        displayPoint = nil
        currentStepIndex = 0
        lastKnownSegmentIndex = 0
        offRouteStartTime = nil
        isRerouting = false
        instructionScheduler.reset()
        cameraTracker.reset()

        status = .navigating

        if let firstStep = route.steps.first {
            let ev = NavInstructionEvent(
                stepIndex: 0,
                instruction: firstStep.instruction,
                streetName: firstStep.streetName,
                maneuverType: firstStep.maneuverType,
                exitNumber: firstStep.exitNumber,
                distanceMeters: firstStep.distanceMeters,
                timeSeconds: Int(firstStep.durationSeconds),
                priority: 2
            )
            delegate?.navigationEngine(self, didReceiveEvent: .instruction(ev))
        }

        return true
    }

    public func updateLocation(_ rawPoint: NavPoint) {
        guard status == .navigating, let route = activeRoute else { return }

        telemetryCollector.recordPoint(rawPoint)

        if rawPoint.accuracy > 40.0 {
            delegate?.navigationEngine(self, didReceiveEvent: .gpsSignalDegraded(rawPoint.accuracy))
        }

        let snapped = MapMatcher.snapToPolyline(
            rawPoint: rawPoint,
            polyline: route.polyline,
            lastKnownSegmentIndex: lastKnownSegmentIndex
        )
        lastKnownSegmentIndex = snapped.segmentIndex

        if snapped.crossTrackDistanceMeters > config.offRouteThresholdMeters {
            displayPoint = rawPoint
            handleOffRoute(rawPoint, deviationMeters: snapped.crossTrackDistanceMeters)
            return
        }

        offRouteStartTime = nil
        displayPoint = snapped.snappedPoint

        updateStepProgression(snapped.snappedPoint)

        // Arrival detection
        if let dest = route.polyline.last, snapped.snappedPoint.distance(to: dest) < 25.0 {
            status = .arrived
            delegate?.navigationEngine(self, didReceiveEvent: .arrival(snapped.snappedPoint, telemetryCollector.cumulativeDistanceMeters))
            stopNavigation()
            return
        }

        // Progress
        let remainingDist = max(0.0, route.totalDistanceMeters - snapped.distanceAlongRouteMeters)
        let fraction = route.totalDistanceMeters > 0 ? min(1.0, max(0.0, snapped.distanceAlongRouteMeters / route.totalDistanceMeters)) : 1.0

        let currentStep = currentStepIndex < route.steps.count ? route.steps[currentStepIndex] : route.steps.last
        let distToManeuver: Double
        if let step = currentStep {
            distToManeuver = snapped.snappedPoint.distance(to: NavPoint(latitude: step.lat, longitude: step.lng))
        } else {
            distToManeuver = remainingDist
        }

        let progress = NavProgressEvent(
            rawPosition: rawPoint,
            snappedPosition: snapped.snappedPoint,
            distanceToNextManeuverMeters: distToManeuver,
            remainingDistanceMeters: remainingDist,
            remainingDurationSeconds: Int(remainingDist / 11.0),
            currentSpeedKmh: rawPoint.speedKmh,
            currentStepIndex: currentStepIndex,
            progressFraction: fraction
        )
        delegate?.navigationEngine(self, didReceiveEvent: .progress(progress))

        if let step = currentStep,
           let instEvent = instructionScheduler.evaluate(currentStep: step, distanceToStepMeters: distToManeuver, speedKmh: rawPoint.speedKmh) {
            delegate?.navigationEngine(self, didReceiveEvent: .instruction(instEvent))
        }

        let camEvents = cameraTracker.checkCameras(
            currentPosition: rawPoint,
            cameras: route.speedCameras,
            overspeedToleranceKmh: config.overspeedToleranceKmh
        )
        for ev in camEvents {
            delegate?.navigationEngine(self, didReceiveEvent: ev)
        }
    }

    private func handleOffRoute(_ rawPoint: NavPoint, deviationMeters: Double) {
        let now = Date()
        if offRouteStartTime == nil {
            offRouteStartTime = now
        }

        let elapsed = Int(now.timeIntervalSince(offRouteStartTime!))
        delegate?.navigationEngine(self, didReceiveEvent: .offRoute(NavOffRouteEvent(currentPosition: rawPoint, deviationMeters: deviationMeters, offRouteDurationSeconds: elapsed)))

        if elapsed >= config.offRouteDebounceSeconds && !isRerouting {
            isRerouting = true
            status = .rerouting
            delegate?.navigationEngine(self, didReceiveEvent: .rerouteTriggered(NavRerouteTriggeredEvent(deviationPoint: rawPoint, reason: "continuous_deviation_detected")))
        }
    }

    private func updateStepProgression(_ snappedPoint: NavPoint) {
        guard let route = activeRoute, !route.steps.isEmpty else { return }

        while currentStepIndex < route.steps.count - 1 {
            let step = route.steps[currentStepIndex]
            let target = NavPoint(latitude: step.lat, longitude: step.lng)
            if snappedPoint.distance(to: target) < 25.0 {
                currentStepIndex += 1
                let nextStep = route.steps[currentStepIndex]
                let ev = NavInstructionEvent(
                    stepIndex: currentStepIndex,
                    instruction: nextStep.instruction,
                    streetName: nextStep.streetName,
                    maneuverType: nextStep.maneuverType,
                    exitNumber: nextStep.exitNumber,
                    distanceMeters: nextStep.distanceMeters,
                    timeSeconds: Int(nextStep.durationSeconds),
                    priority: 2
                )
                delegate?.navigationEngine(self, didReceiveEvent: .instruction(ev))
            } else {
                break
            }
        }
    }

    public func updateRouteAfterReroute(_ newRoute: NavRoute) {
        activeRoute = newRoute
        currentStepIndex = 0
        lastKnownSegmentIndex = 0
        offRouteStartTime = nil
        isRerouting = false
        status = .navigating
        instructionScheduler.reset()
        delegate?.navigationEngine(self, didReceiveEvent: .rerouteSuccess(newRoute))
    }

    public func stopNavigation() {
        status = .idle
        displayPoint = nil
        telemetryCollector.flush()
    }
}
