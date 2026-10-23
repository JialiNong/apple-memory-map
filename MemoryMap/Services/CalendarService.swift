import CoreGraphics
import EventKit

/// Reads calendars and events from the on-device calendar database (EventKit).
final class CalendarService: @unchecked Sendable {
    private var store = EKEventStore()

    static var currentStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> EKAuthorizationStatus {
        do {
            let granted = try await store.requestFullAccessToEvents()
            if granted {
                // A store created before access was granted can keep returning empty results.
                store = EKEventStore()
            }
        } catch {
            // Treated the same as "denied"; the UI explains how to enable access in Settings.
        }
        return Self.currentStatus
    }

    func fetchCalendars() -> [CalendarInfo] {
        store.calendars(for: .event)
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, color: Self.rgba(from: $0.cgColor)) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Fetches all events in the window. Call off the main thread.
    ///
    /// EventKit refuses predicates longer than four years, so the window is walked one year at a time.
    /// Events that cross a chunk boundary come back twice and are de-duplicated by id.
    func fetchEvents(yearsBack: Int = 15, yearsAhead: Int = 1, now: Date = .now) -> [EventItem] {
        let calendar = Calendar.current
        guard
            let windowStart = calendar.date(byAdding: .year, value: -yearsBack, to: now),
            let windowEnd = calendar.date(byAdding: .year, value: yearsAhead, to: now)
        else { return [] }

        var seen = Set<String>()
        var items: [EventItem] = []
        var chunkStart = windowStart

        while chunkStart < windowEnd {
            let next = calendar.date(byAdding: .year, value: 1, to: chunkStart) ?? windowEnd
            let chunkEnd = min(next, windowEnd)
            let predicate = store.predicateForEvents(withStart: chunkStart, end: chunkEnd, calendars: nil)

            for event in store.events(matching: predicate) {
                guard let item = Self.makeItem(from: event), seen.insert(item.id).inserted else { continue }
                items.append(item)
            }
            chunkStart = chunkEnd
        }
        return items.sorted { $0.startDate > $1.startDate }
    }

    private static func makeItem(from event: EKEvent) -> EventItem? {
        guard let start = event.startDate, let end = event.endDate else { return nil }
        let baseID = event.eventIdentifier ?? event.calendarItemIdentifier
        let point = event.structuredLocation?.geoLocation.map { GeoPoint($0.coordinate) }

        return EventItem(
            id: "\(baseID)@\(Int(start.timeIntervalSince1970))",
            title: event.title ?? "",
            startDate: start,
            endDate: end,
            isAllDay: event.isAllDay,
            locationName: event.location,
            location: (point?.isValid ?? false) ? point : nil,
            notes: event.notes,
            calendarID: event.calendar?.calendarIdentifier ?? ""
        )
    }

    private static func rgba(from color: CGColor?) -> RGBAColor {
        guard
            let color,
            let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
            let converted = color.converted(to: sRGB, intent: .defaultIntent, options: nil),
            let components = converted.components,
            components.count >= 3
        else { return .gray }

        return RGBAColor(
            red: Double(components[0]),
            green: Double(components[1]),
            blue: Double(components[2]),
            alpha: components.count >= 4 ? Double(components[3]) : 1
        )
    }
}
