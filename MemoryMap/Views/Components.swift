import SwiftUI
import UIKit

extension RGBAColor {
    var swiftUIColor: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

/// A square thumbnail for a photo-library asset, loaded lazily.
/// Pass `side` for a fixed size; leave it `nil` to fill a grid cell.
struct AssetThumbnail: View {
    let localIdentifier: String
    var side: CGFloat?

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Color.secondary.opacity(0.15)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: side, height: side)
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .contentShape(Rectangle())
            .task(id: localIdentifier) {
                let pixels = (side ?? 160) * displayScale
                image = await ImageLoader.shared.image(
                    for: localIdentifier,
                    targetSize: CGSize(width: pixels, height: pixels)
                )
            }
    }
}

/// The marker drawn on the map for a cluster.
struct ClusterBadge: View {
    let cluster: MemoryCluster
    /// Color of the calendar for event-only clusters.
    let tint: Color

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let firstPhoto = cluster.photoIDs.first {
                    AssetThumbnail(localIdentifier: firstPhoto, side: 46)
                } else {
                    Image(systemName: "calendar")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(tint)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white, lineWidth: 2.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)

            if cluster.count > 1 {
                Text(cluster.count, format: .number.notation(.compactName))
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
                    .offset(x: 10, y: -10)
            }

            // A small dot when the cluster also holds calendar events.
            if !cluster.eventIDs.isEmpty, !cluster.photoIDs.isEmpty {
                Circle()
                    .fill(tint)
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    .frame(width: 12, height: 12)
                    .offset(x: -40, y: 40)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cluster.photoIDs.count) photos, \(cluster.eventIDs.count) events")
    }
}

/// One calendar event, with its calendar color as a leading bar.
struct EventRow: View {
    let event: EventItem

    @Environment(MemoryStore.self) private var store
    @State private var isExpanded = false

    private var color: Color {
        store.calendar(id: event.calendarID)?.color.swiftUIColor ?? .gray
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title.isEmpty ? "Untitled event" : event.title)
                    .font(.headline)

                Text(dateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let calendarTitle = store.calendar(id: event.calendarID)?.title {
                    Text(calendarTitle)
                        .font(.caption)
                        .foregroundStyle(color)
                }

                if let place = event.locationName, !place.isEmpty {
                    Label(place, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let notes = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines), !notes.isEmpty {
                    Text(notes)
                        .font(.callout)
                        .lineLimit(isExpanded ? nil : 3)
                        .padding(.top, 2)
                        .onTapGesture { withAnimation { isExpanded.toggle() } }
                }
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var dateText: String {
        let time: Date.FormatStyle.TimeStyle = event.isAllDay ? .omitted : .shortened
        let start = event.startDate.formatted(date: .abbreviated, time: time)
        let sameDay = Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate)
        if sameDay || (event.isAllDay && isSingleAllDay) {
            return start
        }
        return "\(start) – \(event.endDate.formatted(date: .abbreviated, time: time))"
    }

    /// All-day events end at midnight the next day; treat that as a single day.
    private var isSingleAllDay: Bool {
        event.endDate.timeIntervalSince(event.startDate) <= 24 * 60 * 60
    }
}

/// Full-screen view of one photo.
struct PhotoDetailView: View {
    let photo: PhotoItem

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
            }
            .task(id: photo.id) {
                let size = CGSize(
                    width: proxy.size.width * displayScale,
                    height: proxy.size.height * displayScale
                )
                image = await ImageLoader.shared.image(for: photo.id, targetSize: size, contentMode: .aspectFit)
            }
        }
        .navigationTitle(photo.date?.formatted(date: .abbreviated, time: .shortened) ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
