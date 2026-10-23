# Notes for coding agents (Claude, Cursor, Codex, …)

## Project

SwiftUI iOS app (iOS 17+) that shows the user's own photos (PhotoKit) and calendar events (EventKit) on a map (MapKit). Private-first: no backend, no third-party SDKs, no data leaves the device.

## Build

- The Xcode project is **generated** — edit `project.yml`, never the `.xcodeproj` (it is git-ignored).
- After adding, removing or moving files: `xcodegen generate`.
- Tests: `xcodebuild test -scheme MemoryMap -destination 'platform=iOS Simulator,name=iPhone 16'` or ⌘U in Xcode.

## Layout and rules

- `Models/` — value types and pure functions only. Import Foundation/CoreLocation at most; no SwiftUI, UIKit, MapKit, Photos or EventKit. Everything here should be unit-tested.
- `Services/` — the only place that touches PhotoKit, EventKit and CLGeocoder. Heavy fetches run off the main thread (`Task.detached`), results are applied on the main actor.
- `MemoryStore` is the single source of truth, injected with `.environment(store)`.
- `Views/` — SwiftUI only; no direct framework calls except through `ImageLoader` for thumbnails.
- Keep only photo **metadata** in memory; request images on demand.
- Reverse geocoding is rate-limited: call it for what the user opened, cache the result.
- Code, comments and UI strings are in English.
