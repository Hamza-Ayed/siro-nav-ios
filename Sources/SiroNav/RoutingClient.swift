import Foundation

public final class RoutingClient: @unchecked Sendable {
    private let config: NavConfig

    public init(config: NavConfig) {
        self.config = config
    }

    public func getRoute(origin: NavPoint, destination: NavPoint, locale: String = "ar") async throws -> NavRoute {
        let osrmUrlStr = "https://router.project-osrm.org/route/v1/driving/\(origin.longitude),\(origin.latitude);\(destination.longitude),\(destination.latitude)?overview=full&geometries=polyline&steps=true"
        guard let url = URL(string: osrmUrlStr) else {
            throw NSError(domain: "SiroRouting", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid routing URL"])
        }

        var request = URLRequest(url: url)
        request.setValue("SiroNav-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "SiroRouting", code: 502, userInfo: [NSLocalizedDescriptionKey: "Routing service unavailable"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let routes = json["routes"] as? [[String: Any]],
              let firstRoute = routes.first,
              let geometry = firstRoute["geometry"] as? String else {
            throw NSError(domain: "SiroRouting", code: 500, userInfo: [NSLocalizedDescriptionKey: "Malformed routing response"])
        }

        let polyline = try PolylineCodec.decode(geometry)
        let distance = firstRoute["distance"] as? Double ?? 0.0
        let duration = firstRoute["duration"] as? Double ?? 0.0

        var steps: [NavStep] = []
        if let legs = firstRoute["legs"] as? [[String: Any]],
           let firstLeg = legs.first,
           let legSteps = firstLeg["steps"] as? [[String: Any]] {

            for (index, st) in legSteps.enumerated() {
                let maneuver = st["maneuver"] as? [String: Any] ?? [:]
                let mType = maneuver["type"] as? String ?? ""
                let modifier = maneuver["modifier"] as? String ?? ""
                let loc = maneuver["location"] as? [Double] ?? [0.0, 0.0]
                let exitNumber = maneuver["exit"] as? Int
                let street = st["name"] as? String ?? ""

                let isRoundabout = mType == "roundabout" || mType == "rotary" || modifier.contains("roundabout")
                let sign: Int
                if isRoundabout {
                    sign = 6
                } else if modifier == "uturn" {
                    sign = -98
                } else if ["right", "slight right", "sharp right"].contains(modifier) {
                    sign = 1
                } else if ["left", "slight left", "sharp left"].contains(modifier) {
                    sign = -1
                } else {
                    sign = 0
                }

                let instText: String
                if isRoundabout {
                    let exitNameAr: String
                    switch exitNumber {
                    case 1: exitNameAr = "المخرج الأول"
                    case 2: exitNameAr = "المخرج الثاني"
                    case 3: exitNameAr = "المخرج الثالث"
                    case 4: exitNameAr = "المخرج الرابع"
                    case 5: exitNameAr = "المخرج الخامس"
                    case 6: exitNameAr = "المخرج السادس"
                    default: exitNameAr = exitNumber != nil ? "المخرج رقم \(exitNumber!)" : "المخرج المناسب"
                    }
                    if !street.isEmpty {
                        instText = "عند الدوار، اسلك \(exitNameAr) إلى \(street)"
                    } else {
                        instText = "عند الدوار، اسلك \(exitNameAr)"
                    }
                } else {
                    switch sign {
                    case 1:
                        instText = !street.isEmpty ? "انعطف يميناً إلى \(street)" : "انعطف يميناً"
                    case -1:
                        instText = !street.isEmpty ? "انعطف يساراً إلى \(street)" : "انعطف يساراً"
                    case -98:
                        instText = "قم بالدوران للخلف"
                    default:
                        instText = !street.isEmpty ? "تابع السير على \(street)" : "تابع السير على الطريق"
                    }
                }

                steps.append(
                    NavStep(
                        index: index,
                        instruction: instText,
                        streetName: street,
                        maneuverType: sign,
                        exitNumber: exitNumber,
                        distanceMeters: st["distance"] as? Double ?? 0.0,
                        durationSeconds: st["duration"] as? Double ?? 0.0,
                        lat: loc.count > 1 ? loc[1] : 0.0,
                        lng: loc.count > 0 ? loc[0] : 0.0
                    )
                )
            }
        }

        return NavRoute(
            id: "osrm_route_\(Int(Date().timeIntervalSince1970))",
            routeName: "مسار الطرق المعتمد",
            polyline: polyline,
            steps: steps,
            totalDistanceMeters: distance,
            totalDurationSeconds: duration
        )
    }
}
