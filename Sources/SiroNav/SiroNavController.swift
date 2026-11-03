import Foundation
import CoreLocation

public enum NavTripPhase: Sendable {
    case pickup
    case trip
}

public protocol SiroNavListener: AnyObject {
    func onInstructionChanged(_ instruction: NavInstructionEvent)
    func onProgressUpdated(_ progress: NavProgressEvent)
    func onSpeedExceeded(currentSpeed: Double, speedLimit: Double)
    func onCameraApproaching(camera: SpeedCamera, distance: Double)
    func onTripArrived(totals: NavTripTotals)
    func onError(_ error: String)
}

public final class SiroNavController: NSObject, @unchecked Sendable, NavigationEngineDelegate, CLLocationManagerDelegate {
    public let config: NavConfig
    public let engine: NavigationEngine
    public let voiceEngine = NavVoiceEngine()
    private var tripMeter: NavTripMeter?
    private var locationManager: CLLocationManager?

    public weak var listener: SiroNavListener?

    private(set) public var isNavigating = false

    public var activeRoute: NavRoute? {
        return engine.activeRoute
    }
    private(set) public var lastTripTotals: NavTripTotals?
    private(set) public var currentInstruction: NavInstructionEvent?
    private(set) public var currentProgress: NavProgressEvent?
    private(set) public var activeError: String?
    private(set) public var tripStartTime: Date?

    public init(config: NavConfig) {
        self.config = config
        self.engine = NavigationEngine(config: config)
        super.init()
        self.engine.delegate = self
    }

    public func startNavigation(
        route: NavRoute,
        fare: NavFareConfig? = nil
    ) -> Bool {
        if let fareConfig = fare {
            self.tripMeter = NavTripMeter(config: fareConfig)
        } else {
            self.tripMeter = nil
        }

        tripStartTime = Date()
        let started = engine.startNavigation(route: route)
        if started {
            isNavigating = true
            activeError = nil
            voiceEngine.playPrompt(id: "start_route")
        }
        return started
    }

    public func stopNavigation() {
        engine.stopNavigation()
        isNavigating = false
        voiceEngine.stop()
    }

    public func updateLocation(_ location: CLLocation) {
        let point = NavPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            heading: location.course >= 0 ? location.course : 0.0,
            speedKmh: location.speed >= 0 ? location.speed * 3.6 : 0.0,
            altitude: location.altitude,
            accuracy: location.horizontalAccuracy,
            timestamp: location.timestamp
        )
        engine.updateLocation(point)

        if let meter = tripMeter {
            lastTripTotals = meter.addFix(point)
        }
    }

    public func navigationEngine(_ engine: NavigationEngine, didReceiveEvent event: NavEvent) {
        switch event {
        case .instruction(let inst):
            currentInstruction = inst
            listener?.onInstructionChanged(inst)
            voiceEngine.handleInstruction(
                maneuverType: inst.maneuverType,
                distanceMeters: inst.distanceMeters,
                priority: inst.priority,
                exitNumber: inst.exitNumber
            )
        case .progress(let prog):
            currentProgress = prog
            listener?.onProgressUpdated(prog)
        case .speedLimitExceeded(let current, let limit):
            listener?.onSpeedExceeded(currentSpeed: current, speedLimit: limit)
            voiceEngine.playPrompt(id: "slow_down")
        case .cameraWarning(let cam, let dist):
            listener?.onCameraApproaching(camera: cam, distance: dist)
            voiceEngine.playPrompt(id: "fixed_radar_warning")
        case .arrival(_, _):
            isNavigating = false
            let totals = tripMeter?.totals ?? NavTripTotals(distanceKm: engine.cumulativeDistanceMeters / 1000.0, waitingMinutes: 0.0, fare: 0.0, currency: "JOD")
            lastTripTotals = totals
            listener?.onTripArrived(totals: totals)
            voiceEngine.playPrompt(id: "arrived_destination")
        case .authError(_, let msg):
            activeError = msg
            listener?.onError(msg)
        case .offRoute(let offRoute):
            if offRoute.offRouteDurationSeconds == 0 {
                voiceEngine.playPrompt(id: "rerouting_notice")
            }
        default:
            break
        }
    }
}
