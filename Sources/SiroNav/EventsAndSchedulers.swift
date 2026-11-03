import Foundation

public enum NavEvent: Sendable {
    case instruction(NavInstructionEvent)
    case progress(NavProgressEvent)
    case offRoute(NavOffRouteEvent)
    case rerouteTriggered(NavRerouteTriggeredEvent)
    case rerouteSuccess(NavRoute)
    case speedLimitExceeded(Double, Double) // (current, limit)
    case cameraWarning(SpeedCamera, Double) // (camera, distance)
    case arrival(NavPoint, Double) // (finalPos, totalDistance)
    case authError(String, String) // (code, message)
    case gpsSignalDegraded(Double) // accuracy
}

public struct NavInstructionEvent: Equatable, Sendable {
    public let stepIndex: Int
    public let instruction: String
    public let streetName: String
    public let maneuverType: Int
    public let exitNumber: Int?
    public let distanceMeters: Double
    public let timeSeconds: Int
    public let priority: Int

    public init(
        stepIndex: Int,
        instruction: String,
        streetName: String = "",
        maneuverType: Int = 0,
        exitNumber: Int? = nil,
        distanceMeters: Double = 0.0,
        timeSeconds: Int = 0,
        priority: Int = 2
    ) {
        self.stepIndex = stepIndex
        self.instruction = instruction
        self.streetName = streetName
        self.maneuverType = maneuverType
        self.exitNumber = exitNumber
        self.distanceMeters = distanceMeters
        self.timeSeconds = timeSeconds
        self.priority = priority
    }
}

public struct NavProgressEvent: Equatable, Sendable {
    public let rawPosition: NavPoint
    public let snappedPosition: NavPoint
    public let distanceToNextManeuverMeters: Double
    public let remainingDistanceMeters: Double
    public let remainingDurationSeconds: Int
    public let currentSpeedKmh: Double
    public let currentStepIndex: Int
    public let progressFraction: Double
}

public struct NavOffRouteEvent: Equatable, Sendable {
    public let currentPosition: NavPoint
    public let deviationMeters: Double
    public let offRouteDurationSeconds: Int
}

public struct NavRerouteTriggeredEvent: Equatable, Sendable {
    public let deviationPoint: NavPoint
    public let reason: String
}

public final class InstructionScheduler: @unchecked Sendable {
    private var lastAnnouncedDistance: Double = Double.infinity
    private var lastAnnouncedStepIndex: Int = -1

    public init() {}

    public func reset() {
        lastAnnouncedDistance = Double.infinity
        lastAnnouncedStepIndex = -1
    }

    public func evaluate(currentStep: NavStep, distanceToStepMeters: Double, speedKmh: Double) -> NavInstructionEvent? {
        if currentStep.index != lastAnnouncedStepIndex {
            lastAnnouncedStepIndex = currentStep.index
            lastAnnouncedDistance = distanceToStepMeters
            return NavInstructionEvent(
                stepIndex: currentStep.index,
                instruction: currentStep.instruction,
                streetName: currentStep.streetName,
                maneuverType: currentStep.maneuverType,
                exitNumber: currentStep.exitNumber,
                distanceMeters: distanceToStepMeters,
                timeSeconds: currentStep.durationSeconds > 0 ? Int(currentStep.durationSeconds) : 0,
                priority: 2
            )
        }

        let thresholds: [Double] = speedKmh > 70.0
            ? [1000.0, 500.0, 200.0, 50.0]
            : [500.0, 200.0, 50.0]

        for threshold in thresholds {
            if distanceToStepMeters <= threshold && lastAnnouncedDistance > threshold {
                lastAnnouncedDistance = distanceToStepMeters
                return NavInstructionEvent(
                    stepIndex: currentStep.index,
                    instruction: currentStep.instruction,
                    streetName: currentStep.streetName,
                    maneuverType: currentStep.maneuverType,
                    exitNumber: currentStep.exitNumber,
                    distanceMeters: distanceToStepMeters,
                    timeSeconds: Int(distanceToStepMeters / max(5.0, (speedKmh / 3.6))),
                    priority: threshold <= 50.0 ? 3 : 2
                )
            }
        }
        return nil
    }
}

public final class CameraTracker: @unchecked Sendable {
    private var alertedCameraIds = Set<String>()

    public init() {}

    public func reset() {
        alertedCameraIds.removeAll()
    }

    public func checkCameras(
        currentPosition: NavPoint,
        cameras: [SpeedCamera],
        overspeedToleranceKmh: Double = 5.0
    ) -> [NavEvent] {
        var events: [NavEvent] = []

        for cam in cameras {
            let camPos = NavPoint(latitude: cam.lat, longitude: cam.lng)
            let dist = currentPosition.distance(to: camPos)

            if dist <= 500.0 && !alertedCameraIds.contains(cam.id) {
                alertedCameraIds.insert(cam.id)
                events.append(.cameraWarning(cam, dist))
            }

            if dist <= 300.0 && currentPosition.speedKmh > (cam.speedLimitKmh + overspeedToleranceKmh) {
                events.append(.speedLimitExceeded(currentPosition.speedKmh, cam.speedLimitKmh))
            }
        }

        return events
    }
}
