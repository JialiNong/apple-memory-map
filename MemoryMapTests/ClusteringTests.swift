import XCTest
@testable import MemoryMap

final class ClusteringTests: XCTestCase {
    private func photo(_ id: String, _ lat: Double, _ lon: Double) -> MapPoint {
        MapPoint(id: id, kind: .photo, location: GeoPoint(latitude: lat, longitude: lon))
    }

    private func event(_ id: String, _ lat: Double, _ lon: Double) -> MapPoint {
        MapPoint(id: id, kind: .event, location: GeoPoint(latitude: lat, longitude: lon))
    }

    func testNearbyPointsShareACluster() {
        let clusters = GridClusterer.cluster(
            [photo("a", 51.34, 12.37), photo("b", 51.341, 12.371), event("e", 51.342, 12.372)],
            cellSize: 0.1
        )

        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(Set(clusters[0].photoIDs), ["a", "b"])
        XCTAssertEqual(clusters[0].eventIDs, ["e"])
        XCTAssertEqual(clusters[0].count, 3)
    }

    func testDistantPointsAreSeparate() {
        // Leipzig and Kyoto
        let clusters = GridClusterer.cluster(
            [photo("leipzig", 51.34, 12.37), photo("kyoto", 35.01, 135.77)],
            cellSize: 1
        )
        XCTAssertEqual(clusters.count, 2)
    }

    func testCenterIsTheAverageOfItsPoints() {
        let clusters = GridClusterer.cluster(
            [photo("a", 10.2, 20.2), photo("b", 10.4, 20.6)],
            cellSize: 1
        )
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].center.latitude, 10.3, accuracy: 1e-9)
        XCTAssertEqual(clusters[0].center.longitude, 20.4, accuracy: 1e-9)
    }

    func testNegativeCoordinatesDoNotMergeAcrossZero() {
        // Rounding toward zero would wrongly put -0.4 and 0.4 into the same cell.
        let clusters = GridClusterer.cluster(
            [photo("west", 0.4, -0.4), photo("east", 0.4, 0.4)],
            cellSize: 1
        )
        XCTAssertEqual(clusters.count, 2)
    }

    func testEmptyInputGivesNoClusters() {
        XCTAssertTrue(GridClusterer.cluster([], cellSize: 1).isEmpty)
    }

    func testOutputOrderIsStable() {
        let points = (0..<50).map { photo("p\($0)", Double($0), Double($0)) }
        let first = GridClusterer.cluster(points, cellSize: 1)
        let second = GridClusterer.cluster(points.shuffled(), cellSize: 1)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
    }

    func testCellSizeScalesWithZoomAndHasAFloor() {
        XCTAssertEqual(GridClusterer.cellSize(latitudeDelta: 8, longitudeDelta: 4), 1, accuracy: 1e-9)
        XCTAssertEqual(GridClusterer.cellSize(latitudeDelta: 0.000001, longitudeDelta: 0.000001), 0.0005, accuracy: 1e-12)
    }
}

final class GeoTests: XCTestCase {
    func testInvalidCoordinatesAreRejected() {
        XCTAssertFalse(GeoPoint(latitude: 0, longitude: 0).isValid)
        XCTAssertFalse(GeoPoint(latitude: 91, longitude: 10).isValid)
        XCTAssertFalse(GeoPoint(latitude: 10, longitude: 181).isValid)
        XCTAssertTrue(GeoPoint(latitude: 51.34, longitude: 12.37).isValid)
    }

    func testBoundsContainment() {
        let bounds = GeoBounds(center: GeoPoint(latitude: 50, longitude: 10), latitudeDelta: 2, longitudeDelta: 2, padding: 0)
        XCTAssertTrue(bounds.contains(GeoPoint(latitude: 50.9, longitude: 10.9)))
        XCTAssertFalse(bounds.contains(GeoPoint(latitude: 51.1, longitude: 10)))
        XCTAssertFalse(bounds.contains(GeoPoint(latitude: 50, longitude: 8.9)))
    }

    func testBoundsAcrossTheAntimeridianKeepLongitudesOnBothSides() {
        let bounds = GeoBounds(center: GeoPoint(latitude: 0, longitude: 179), latitudeDelta: 10, longitudeDelta: 10, padding: 0)
        XCTAssertTrue(bounds.contains(GeoPoint(latitude: 1, longitude: -178)))
        XCTAssertTrue(bounds.contains(GeoPoint(latitude: 1, longitude: 178)))
    }
}
