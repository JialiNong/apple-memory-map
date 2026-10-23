import CoreLocation

/// A plain, hashable latitude/longitude pair.
/// `CLLocationCoordinate2D` is not `Hashable`, so the model layer uses this instead.
struct GeoPoint: Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Rejects out-of-range values and the (0, 0) "null island" that broken EXIF data often produces.
    var isValid: Bool {
        (-90...90).contains(latitude)
            && (-180...180).contains(longitude)
            && !(latitude == 0 && longitude == 0)
    }
}

/// An axis-aligned lat/lon rectangle, used to keep map clustering to what is on screen.
struct GeoBounds: Equatable, Sendable {
    var minLatitude: Double
    var maxLatitude: Double
    var minLongitude: Double
    var maxLongitude: Double

    /// - Parameter padding: extra margin as a fraction of the span on each side (0.5 = half a screen).
    init(center: GeoPoint, latitudeDelta: Double, longitudeDelta: Double, padding: Double = 0.5) {
        let halfLat = latitudeDelta * (0.5 + padding)
        let halfLon = longitudeDelta * (0.5 + padding)
        minLatitude = center.latitude - halfLat
        maxLatitude = center.latitude + halfLat
        minLongitude = center.longitude - halfLon
        maxLongitude = center.longitude + halfLon
    }

    init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }

    /// When the box crosses the antimeridian we skip the longitude check rather than
    /// handling the wrap-around — over-including a few points is harmless.
    private var spansAntimeridian: Bool {
        minLongitude < -180 || maxLongitude > 180
    }

    func contains(_ point: GeoPoint) -> Bool {
        guard point.latitude >= minLatitude, point.latitude <= maxLatitude else { return false }
        if spansAntimeridian { return true }
        return point.longitude >= minLongitude && point.longitude <= maxLongitude
    }
}
