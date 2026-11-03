import Foundation

/// Decodes Google-style encoded polylines (precision 5).
public struct PolylineCodec {
    public static func decode(_ encoded: String, precision: Int = 5) throws -> [NavPoint] {
        let factor = pow(10.0, Double(precision))
        var points: [NavPoint] = []
        let now = Date()
        var index = encoded.startIndex

        func readDelta() throws -> Int {
            var result = 0
            var shift = 0
            var chunk = 0
            repeat {
                if index >= encoded.endIndex {
                    throw NSError(domain: "PolylineCodec", code: 1, userInfo: [NSLocalizedDescriptionKey: "Truncated polyline"])
                }
                let scalar = encoded[index].unicodeScalars.first?.value ?? 0
                index = encoded.index(after: index)
                chunk = Int(scalar) - 63
                result |= (chunk & 0x1f) << shift
                shift += 5
            } while chunk >= 0x20

            return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        }

        var lat = 0
        var lng = 0
        while index < encoded.endIndex {
            lat += try readDelta()
            lng += try readDelta()
            points.append(NavPoint(
                latitude: Double(lat) / factor,
                longitude: Double(lng) / factor,
                timestamp: now
            ))
        }
        return points
    }
}
