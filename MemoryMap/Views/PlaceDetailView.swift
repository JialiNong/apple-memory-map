import SwiftUI

/// Everything at one map cluster: when you were there, the events, and the photos.
struct PlaceDetailView: View {
    let cluster: MemoryCluster

    @Environment(MemoryStore.self) private var store
    @State private var placeName: String?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 2)]

    var body: some View {
        let photos = cluster.photoIDs
            .compactMap(store.photo(id:))
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        let events = cluster.eventIDs
            .compactMap(store.event(id:))
            .sorted { $0.startDate > $1.startDate }
        let summary = VisitSummary(dates: photos.compactMap(\.date) + events.map(\.startDate))

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SummaryCard(summary: summary, photoCount: photos.count, eventCount: events.count)

                    if !events.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "Events", count: events.count)
                            ForEach(events) { event in
                                EventRow(event: event)
                                if event.id != events.last?.id { Divider() }
                            }
                        }
                    }

                    if !photos.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "Photos", count: photos.count)
                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(photos) { photo in
                                    NavigationLink(value: photo) {
                                        AssetThumbnail(localIdentifier: photo.id)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(placeName ?? "This place")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PhotoItem.self) { photo in
                PhotoDetailView(photo: photo)
            }
            .task(id: cluster.id) {
                placeName = await PlaceNameResolver.name(for: cluster.center)
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.bold())
            Text("\(count)").foregroundStyle(.secondary)
        }
    }
}

private struct SummaryCard: View {
    let summary: VisitSummary
    let photoCount: Int
    let eventCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let first = summary.firstVisit, let last = summary.lastVisit {
                if Calendar.current.isDate(first, inSameDayAs: last) {
                    Label(first.formatted(date: .long, time: .omitted), systemImage: "calendar")
                } else {
                    Label("First here \(first.formatted(date: .long, time: .omitted))", systemImage: "flag")
                    Label("Last here \(last.formatted(date: .long, time: .omitted))", systemImage: "clock.arrow.circlepath")
                }
            }
            Label(
                "\(summary.distinctDays) \(summary.distinctDays == 1 ? "day" : "days") · \(photoCount) photos · \(eventCount) events",
                systemImage: "sparkles"
            )
            .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
