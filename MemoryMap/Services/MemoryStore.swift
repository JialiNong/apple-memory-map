import EventKit
import Foundation
import Observation
import Photos

/// The app's single source of truth: everything read from Photos and Calendar,
/// plus the current filter. All data stays in memory on the device — there is no backend.
@MainActor
@Observable
final class MemoryStore {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
    }

    private(set) var photos: [PhotoItem] = []
    private(set) var events: [EventItem] = []
    private(set) var calendars: [CalendarInfo] = []
    private(set) var photoAccess: PHAuthorizationStatus
    private(set) var calendarAccess: EKAuthorizationStatus
    private(set) var loadState: LoadState = .idle
    var filter = MemoryFilter()

    private let photoService = PhotoLibraryService()
    private let calendarService = CalendarService()
    @ObservationIgnored private var photosByID: [String: PhotoItem] = [:]
    @ObservationIgnored private var eventsByID: [String: EventItem] = [:]
    @ObservationIgnored private var calendarsByID: [String: CalendarInfo] = [:]

    init() {
        photoAccess = PhotoLibraryService.currentStatus
        calendarAccess = CalendarService.currentStatus
    }

    // MARK: - Access

    var canReadPhotos: Bool { PhotoLibraryService.canRead(photoAccess) }
    var canReadCalendar: Bool { calendarAccess == .fullAccess }
    var hasAnyAccess: Bool { canReadPhotos || canReadCalendar }
    var isPhotoAccessLimited: Bool { photoAccess == .limited }

    /// Show the onboarding screen until the user has answered both permission prompts.
    var needsOnboarding: Bool {
        photoAccess == .notDetermined || calendarAccess == .notDetermined
    }

    func requestAccess() async {
        if photoAccess == .notDetermined {
            photoAccess = await photoService.requestAuthorization()
        }
        if calendarAccess == .notDetermined {
            calendarAccess = await calendarService.requestAccess()
        }
        await reload()
    }

    // MARK: - Loading

    func reload() async {
        // The user may have changed access in Settings since launch.
        photoAccess = PhotoLibraryService.currentStatus
        calendarAccess = CalendarService.currentStatus
        loadState = .loading

        let photoService = self.photoService
        let calendarService = self.calendarService

        var loadedPhotos: [PhotoItem] = []
        if canReadPhotos {
            loadedPhotos = await Task.detached(priority: .userInitiated) {
                photoService.fetchAllPhotos()
            }.value
        }

        var loadedEvents: [EventItem] = []
        var loadedCalendars: [CalendarInfo] = []
        if canReadCalendar {
            (loadedEvents, loadedCalendars) = await Task.detached(priority: .userInitiated) {
                (calendarService.fetchEvents(), calendarService.fetchCalendars())
            }.value
        }

        photos = loadedPhotos
        events = loadedEvents
        calendars = loadedCalendars
        photosByID = Dictionary(loadedPhotos.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        eventsByID = Dictionary(loadedEvents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        calendarsByID = Dictionary(loadedCalendars.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        loadState = .loaded
    }

    // MARK: - Lookups

    func photo(id: String) -> PhotoItem? { photosByID[id] }
    func event(id: String) -> EventItem? { eventsByID[id] }
    func calendar(id: String) -> CalendarInfo? { calendarsByID[id] }

    // MARK: - Filtered views

    var visiblePhotos: [PhotoItem] { photos.filter { filter.includes($0) } }
    var visibleEvents: [EventItem] { events.filter { filter.includes($0) } }

    var availableYears: [Int] {
        let calendar = Calendar.current
        var years = Set<Int>()
        for photo in photos { if let date = photo.date { years.insert(calendar.component(.year, from: date)) } }
        for event in events { years.insert(calendar.component(.year, from: event.startDate)) }
        return years.sorted(by: >)
    }

    var locatedPhotoCount: Int { photos.lazy.filter { $0.location != nil }.count }
    var locatedEventCount: Int { events.lazy.filter { $0.location != nil }.count }

    /// Clusters for the map. Only points inside `bounds` are considered, so panning a
    /// zoomed-in map stays cheap even with a very large library.
    func clusters(in bounds: GeoBounds?, cellSize: Double) -> [MemoryCluster] {
        var points: [MapPoint] = []

        if filter.showPhotos {
            for photo in photos where filter.includes(photo) {
                guard let location = photo.location, bounds?.contains(location) ?? true else { continue }
                points.append(MapPoint(id: photo.id, kind: .photo, location: location))
            }
        }
        if filter.showEvents {
            for event in events where filter.includes(event) {
                guard let location = event.location, bounds?.contains(location) ?? true else { continue }
                points.append(MapPoint(id: event.id, kind: .event, location: location))
            }
        }
        return GridClusterer.cluster(points, cellSize: cellSize)
    }
}
