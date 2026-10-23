# Memory Map

A private-first iOS app that puts my **photos** and **calendar events** on one map, so I can revisit where I've been, when, and what I wrote about it at the time.

Everything is read on-device through Apple's own frameworks. There is no account, no server and no analytics — the photo library and calendar never leave the phone.

> Status: **v1 in progress** — map, place details, timeline and filters.

## Features (v1)

- **Map of memories** — photos (by GPS) and calendar events (by their map location) grouped into clusters that re-form as you zoom.
- **Place details** — tap a cluster to see when you were first and last there, how many days you spent, the events (with your notes) and every photo.
- **Timeline** — month-by-month view of photos and events, including those without a location.
- **Filters** — by year, by calendar (my calendars double as categories: Travel, Study, …), and photos vs. events.

## Tech

| Area | Choice |
| --- | --- |
| UI | SwiftUI, iOS 17+ |
| State | Observation (`@Observable`) |
| Photos | PhotoKit (`PHAsset`, `PHCachingImageManager`) |
| Calendar | EventKit (full access, iOS 17 API) |
| Map | MapKit for SwiftUI |
| Project | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml` is the source of truth) |
| Tests | XCTest for the pure model logic |

### Architecture

```
MemoryMap/
├── App/          App entry point and root view
├── Models/       Plain value types + pure logic (clustering, summaries, filters) — no UIKit/MapKit
├── Services/     PhotoKit, EventKit, reverse geocoding, and MemoryStore (the single source of truth)
└── Views/        SwiftUI screens and components
```

- **`MemoryStore`** loads photo *metadata* (id, date, location) and events once, off the main thread, and keeps them in memory. Image data is only requested when a thumbnail is on screen.
- **Clustering** is a grid over latitude/longitude whose cell size follows the zoom level. It only considers points inside the visible region (plus a margin), so it stays fast with tens of thousands of photos.
- **EventKit** rejects queries longer than four years, so events are fetched one year at a time and de-duplicated.

## Getting started

Requirements: a Mac with Xcode 16 or later, and an iPhone (the simulator has no real photo library).

```bash
brew install xcodegen
git clone https://github.com/JialiNong/apple-memory-map.git
cd apple-memory-map
xcodegen generate
open MemoryMap.xcodeproj
```

In Xcode: select the **MemoryMap** target → *Signing & Capabilities* → choose your Team (a free Apple ID works), then run on your iPhone.

Run the tests with ⌘U.

## Roadmap

- [x] **v1** — map, place details, timeline, filters
- [ ] **v1.x** — calendar/heatmap view, cache place names, remember filters
- [ ] **v2** — suggest locations for untagged photos from same-day calendar events, and batch-apply them
- [ ] **v3** — link my Obsidian diary (Markdown, by date) to the map and timeline, read-only
- [ ] **v4** — AI recaps per place ("every time I've been to Kyoto"), on-device first

## Privacy

Memory Map has no backend. It reads Photos and Calendar locally and keeps nothing outside the app's own memory. The only network request is Apple's reverse geocoding, used to show a place name when you open a place.
