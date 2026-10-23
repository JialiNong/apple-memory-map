import XCTest
@testable import MemoryMap

final class SummaryTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func photo(_ id: String, _ date: Date?) -> PhotoItem {
        PhotoItem(id: id, date: date, location: nil, isFavorite: false)
    }

    private func event(_ id: String, _ start: Date, calendarID: String = "travel") -> EventItem {
        EventItem(
            id: id, title: id, startDate: start, endDate: start.addingTimeInterval(3600),
            isAllDay: false, locationName: nil, location: nil, notes: nil, calendarID: calendarID
        )
    }

    // MARK: VisitSummary

    func testVisitSummaryCountsDistinctDays() {
        let dates = [date(2024, 5, 1, 9), date(2024, 5, 1, 18), date(2024, 5, 3), date(2023, 1, 2)]
        let summary = VisitSummary(dates: dates, calendar: calendar)

        XCTAssertEqual(summary.distinctDays, 3)
        XCTAssertEqual(summary.firstVisit, date(2023, 1, 2))
        XCTAssertEqual(summary.lastVisit, date(2024, 5, 3))
    }

    func testVisitSummaryOfNothing() {
        let summary = VisitSummary(dates: [], calendar: calendar)
        XCTAssertNil(summary.firstVisit)
        XCTAssertEqual(summary.distinctDays, 0)
    }

    // MARK: TimelineBuilder

    func testTimelineGroupsByMonthNewestFirst() {
        let buckets = TimelineBuilder.buckets(
            photos: [photo("p1", date(2024, 5, 2)), photo("p2", date(2024, 5, 20)), photo("old", date(2023, 12, 31))],
            events: [event("e1", date(2024, 6, 1))],
            calendar: calendar
        )

        XCTAssertEqual(buckets.map(\.month), [date(2024, 6, 1, 0), date(2024, 5, 1, 0), date(2023, 12, 1, 0)])
        XCTAssertEqual(buckets[1].photos.map(\.id), ["p2", "p1"], "photos inside a month are newest first")
        XCTAssertEqual(buckets[0].events.map(\.id), ["e1"])
    }

    func testTimelineSkipsUndatedPhotos() {
        let buckets = TimelineBuilder.buckets(photos: [photo("nodate", nil)], events: [], calendar: calendar)
        XCTAssertTrue(buckets.isEmpty)
    }

    // MARK: MemoryFilter

    func testFilterByYear() {
        var filter = MemoryFilter()
        XCTAssertTrue(filter.includes(date: nil, calendar: calendar), "no year filter includes undated items")

        filter.year = 2024
        XCTAssertTrue(filter.includes(date: date(2024, 7, 1), calendar: calendar))
        XCTAssertFalse(filter.includes(date: date(2023, 7, 1), calendar: calendar))
        XCTAssertFalse(filter.includes(date: nil, calendar: calendar))
    }

    func testFilterHidesCalendarsAndKinds() {
        var filter = MemoryFilter()
        let travel = event("trip", date(2024, 1, 1), calendarID: "travel")
        let study = event("class", date(2024, 1, 1), calendarID: "study")

        filter.hiddenCalendarIDs = ["study"]
        XCTAssertTrue(filter.includes(travel, calendar: calendar))
        XCTAssertFalse(filter.includes(study, calendar: calendar))

        filter.showEvents = false
        XCTAssertFalse(filter.includes(travel, calendar: calendar))

        filter.showPhotos = false
        XCTAssertFalse(filter.includes(photo("p", date(2024, 1, 1)), calendar: calendar))
    }
}
