import Foundation

/// "How often have I been here?" — derived from the dates of photos and events at a place.
struct VisitSummary: Equatable, Sendable {
    let firstVisit: Date?
    let lastVisit: Date?
    /// Number of distinct calendar days with at least one photo or event.
    let distinctDays: Int

    init(dates: [Date], calendar: Calendar = .current) {
        firstVisit = dates.min()
        lastVisit = dates.max()
        distinctDays = Set(dates.map { calendar.startOfDay(for: $0) }).count
    }
}

/// One month on the timeline.
struct MonthBucket: Identifiable, Equatable, Sendable {
    /// First instant of the month.
    let month: Date
    var photos: [PhotoItem]
    var events: [EventItem]

    var id: Date { month }
}

enum TimelineBuilder {
    /// Groups photos and events by month, newest month first.
    /// Photos without a date are left out because they cannot be placed in time.
    static func buckets(photos: [PhotoItem], events: [EventItem], calendar: Calendar = .current) -> [MonthBucket] {
        var byMonth: [Date: MonthBucket] = [:]

        func monthStart(_ date: Date) -> Date {
            calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }

        for photo in photos {
            guard let date = photo.date else { continue }
            let key = monthStart(date)
            byMonth[key, default: MonthBucket(month: key, photos: [], events: [])].photos.append(photo)
        }
        for event in events {
            let key = monthStart(event.startDate)
            byMonth[key, default: MonthBucket(month: key, photos: [], events: [])].events.append(event)
        }

        return byMonth.values
            .map { bucket in
                var bucket = bucket
                bucket.photos.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
                bucket.events.sort { $0.startDate > $1.startDate }
                return bucket
            }
            .sorted { $0.month > $1.month }
    }
}
