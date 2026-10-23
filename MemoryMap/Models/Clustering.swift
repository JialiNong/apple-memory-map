import Foundation

enum MemoryKind: Hashable, Sendable {
    case photo
    case event
}

/// Anything that can be placed on the map.
struct MapPoint: Hashable, Sendable {
    let id: String
    let kind: MemoryKind
    let location: GeoPoint
}

/// A group of photos and events that are close together at the current zoom level.
struct MemoryCluster: Identifiable, Hashable, Sendable {
    let id: String
    let center: GeoPoint
    let photoIDs: [String]
    let eventIDs: [String]

    var count: Int { photoIDs.count + eventIDs.count }
}

/// Grid-based clustering: the world is cut into square cells of `cellSize` degrees and
/// every point falls into exactly one cell. O(n), stable, and fast enough for tens of
/// thousands of photos on every camera change.
///
/// Trade-off: two points just either side of a cell edge end up in different clusters
/// even when they are close. Good enough for v1; a distance-based pass can come later.
enum GridClusterer {
    static func cluster(_ points: [MapPoint], cellSize: Double) -> [MemoryCluster] {
        precondition(cellSize > 0, "cellSize must be positive")

        struct Cell: Hashable {
            let row: Int
            let column: Int
        }

        struct Bucket {
            var latitudeSum = 0.0
            var longitudeSum = 0.0
            var photoIDs: [String] = []
            var eventIDs: [String] = []

            mutating func add(_ point: MapPoint) {
                latitudeSum += point.location.latitude
                longitudeSum += point.location.longitude
                switch point.kind {
                case .photo: photoIDs.append(point.id)
                case .event: eventIDs.append(point.id)
                }
            }
        }

        var buckets: [Cell: Bucket] = [:]
        for point in points {
            let cell = Cell(
                row: Int((point.location.latitude / cellSize).rounded(.down)),
                column: Int((point.location.longitude / cellSize).rounded(.down))
            )
            buckets[cell, default: Bucket()].add(point)
        }

        return buckets
            .map { cell, bucket in
                let count = Double(bucket.photoIDs.count + bucket.eventIDs.count)
                return MemoryCluster(
                    id: "\(cell.row):\(cell.column)",
                    center: GeoPoint(
                        latitude: bucket.latitudeSum / count,
                        longitude: bucket.longitudeSum / count
                    ),
                    photoIDs: bucket.photoIDs,
                    eventIDs: bucket.eventIDs
                )
            }
            .sorted { $0.id < $1.id }
    }

    /// Picks a cell size so that roughly `cellsAcross` clusters fit across the visible map.
    static func cellSize(latitudeDelta: Double, longitudeDelta: Double, cellsAcross: Double = 8) -> Double {
        let span = max(latitudeDelta, longitudeDelta)
        // Never smaller than ~50 m, so a street-level zoom still groups shots taken on the spot.
        return max(span / cellsAcross, 0.0005)
    }
}
