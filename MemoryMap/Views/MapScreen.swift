import MapKit
import SwiftUI
import UIKit

struct MapScreen: View {
    @Environment(MemoryStore.self) private var store

    @State private var position: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var clusters: [MemoryCluster] = []
    @State private var selectedCluster: MemoryCluster?
    @State private var isShowingFilters = false
    @State private var hasFramedMemories = false

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                ForEach(clusters) { cluster in
                    Annotation("", coordinate: cluster.center.coordinate, anchor: .center) {
                        Button {
                            selectedCluster = cluster
                        } label: {
                            ClusterBadge(cluster: cluster, tint: tint(for: cluster))
                        }
                        .buttonStyle(.plain)
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
                recluster()
            }
            .onChange(of: store.filter) { recluster() }
            .onChange(of: store.loadState) {
                guard store.loadState == .loaded else { return }
                recluster()
                // Frame all memories once, after the first load — not on every refresh.
                if !hasFramedMemories {
                    hasFramedMemories = true
                    position = .automatic
                }
            }
            .onAppear { recluster() }
            .safeAreaInset(edge: .top) { banner }
            .sheet(item: $selectedCluster) { cluster in
                PlaceDetailView(cluster: cluster)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingFilters) {
                FilterView()
                    .presentationDetents([.medium, .large])
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await store.reload() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.loadState == .loading)
                    .accessibilityLabel("Reload")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingFilters = true
                    } label: {
                        Image(systemName: store.filter == MemoryFilter()
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Filters")
                }
            }
            .navigationTitle(store.filter.year.map { String($0) } ?? "Memory Map")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Banner

    @ViewBuilder
    private var banner: some View {
        if store.loadState == .loading {
            Label("Loading your memories…", systemImage: "hourglass")
                .bannerStyle()
        } else if !store.hasAnyAccess {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("No access to Photos or Calendar. Tap to open Settings.", systemImage: "exclamationmark.triangle")
            }
            .bannerStyle()
        } else if store.isPhotoAccessLimited {
            Label("Only the photos you selected are shown.", systemImage: "photo.badge.exclamationmark")
                .bannerStyle()
        }
    }

    // MARK: - Clustering

    private func recluster() {
        guard let region = visibleRegion else {
            // Before the map reports a region, cluster coarsely over the whole world.
            clusters = store.clusters(in: nil, cellSize: 5)
            return
        }
        let bounds = GeoBounds(
            center: GeoPoint(region.center),
            latitudeDelta: region.span.latitudeDelta,
            longitudeDelta: region.span.longitudeDelta
        )
        let cellSize = GridClusterer.cellSize(
            latitudeDelta: region.span.latitudeDelta,
            longitudeDelta: region.span.longitudeDelta
        )
        clusters = store.clusters(in: bounds, cellSize: cellSize)
    }

    private func tint(for cluster: MemoryCluster) -> Color {
        guard
            let eventID = cluster.eventIDs.first,
            let event = store.event(id: eventID),
            let calendar = store.calendar(id: event.calendarID)
        else { return .accentColor }
        return calendar.color.swiftUIColor
    }
}

private extension View {
    func bannerStyle() -> some View {
        font(.footnote)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 6)
    }
}
