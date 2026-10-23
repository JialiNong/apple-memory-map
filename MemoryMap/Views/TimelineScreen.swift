import SwiftUI

/// Month-by-month list of photos and events, newest first.
/// Unlike the map, this also shows events and photos that have no location.
struct TimelineScreen: View {
    @Environment(MemoryStore.self) private var store
    @State private var path = NavigationPath()

    /// Only the first few photos of a month are shown as a strip, to keep scrolling smooth.
    private let photosPerMonth = 24

    var body: some View {
        let buckets = TimelineBuilder.buckets(photos: store.visiblePhotos, events: store.visibleEvents)

        NavigationStack(path: $path) {
            Group {
                if buckets.isEmpty, store.loadState == .loaded {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No photos or events match the current filters.")
                    )
                } else {
                    List {
                        ForEach(buckets) { bucket in
                            Section {
                                if !bucket.photos.isEmpty {
                                    photoStrip(for: bucket)
                                }
                                ForEach(bucket.events) { event in
                                    EventRow(event: event)
                                }
                            } header: {
                                HStack {
                                    Text(bucket.month.formatted(.dateTime.year().month(.wide)))
                                    Spacer()
                                    Text("\(bucket.photos.count) photos · \(bucket.events.count) events")
                                        .textCase(nil)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Timeline")
            .navigationDestination(for: PhotoItem.self) { photo in
                PhotoDetailView(photo: photo)
            }
            .overlay {
                if store.loadState == .loading, buckets.isEmpty {
                    ProgressView()
                }
            }
        }
    }

    private func photoStrip(for bucket: MonthBucket) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 4) {
                ForEach(bucket.photos.prefix(photosPerMonth)) { photo in
                    // A plain Button that pushes onto the path: several NavigationLinks
                    // inside one List row would all fire on a single tap.
                    Button {
                        path.append(photo)
                    } label: {
                        AssetThumbnail(localIdentifier: photo.id, side: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.borderless)
                }
                if bucket.photos.count > photosPerMonth {
                    Text("+\(bucket.photos.count - photosPerMonth)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(width: 76, height: 76)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }
}
