import CoreLocation

/// Turns coordinates into a readable place name ("Kyoto, Japan").
///
/// Reverse geocoding goes to Apple's servers and is rate-limited, so results are cached
/// and this is only called for the place the user opened — never for every photo.
@MainActor
enum PlaceNameResolver {
    private static var cache: [GeoPoint: String] = [:]

    static func name(for point: GeoPoint) async -> String? {
        if let cached = cache[point] { return cached }

        let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
        guard
            let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
            let placemark = placemarks.first
        else { return nil }

        let local = placemark.locality ?? placemark.administrativeArea ?? placemark.name
        let name = [local, placemark.country]
            .compactMap { $0 }
            .reduce(into: [String]()) { parts, part in
                if !parts.contains(part) { parts.append(part) }
            }
            .joined(separator: ", ")

        guard !name.isEmpty else { return nil }
        cache[point] = name
        return name
    }
}
