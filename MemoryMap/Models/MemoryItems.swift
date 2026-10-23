import Foundation

/// A photo from the system library. Only metadata is kept in memory;
/// image data is requested on demand through `ImageLoader`.
struct PhotoItem: Identifiable, Hashable, Sendable {
    /// `PHAsset.localIdentifier`
    let id: String
    let date: Date?
    let location: GeoPoint?
    let isFavorite: Bool
}

/// An event from the system calendar (EventKit).
struct EventItem: Identifiable, Hashable, Sendable {
    /// Event identifier + start time, so each occurrence of a recurring event is unique.
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    /// The free-text location the user typed, e.g. "Leipzig Hbf".
    let locationName: String?
    /// Coordinates, only present when the event has a structured (map) location.
    let location: GeoPoint?
    let notes: String?
    let calendarID: String
}

/// A calendar the user keeps, e.g. "Travel", "Study". Used as a category.
struct CalendarInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let color: RGBAColor
}

/// A UI-framework-free color, so model types stay Sendable and testable.
struct RGBAColor: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let gray = RGBAColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
}

/// What the user currently wants to see on the map and timeline.
struct MemoryFilter: Equatable, Sendable {
    var showPhotos = true
    var showEvents = true
    /// Calendars the user switched off. Storing the hidden ones means new calendars show up by default.
    var hiddenCalendarIDs: Set<String> = []
    /// `nil` means all years.
    var year: Int?

    func includes(date: Date?, calendar: Calendar = .current) -> Bool {
        guard let year else { return true }
        guard let date else { return false }
        return calendar.component(.year, from: date) == year
    }

    func includes(_ event: EventItem, calendar: Calendar = .current) -> Bool {
        showEvents
            && !hiddenCalendarIDs.contains(event.calendarID)
            && includes(date: event.startDate, calendar: calendar)
    }

    func includes(_ photo: PhotoItem, calendar: Calendar = .current) -> Bool {
        showPhotos && includes(date: photo.date, calendar: calendar)
    }
}
