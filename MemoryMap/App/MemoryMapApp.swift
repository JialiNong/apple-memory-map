import SwiftUI

@main
struct MemoryMapApp: App {
    @State private var store = MemoryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}

struct RootView: View {
    @Environment(MemoryStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.needsOnboarding {
                OnboardingView()
            } else {
                TabView {
                    MapScreen()
                        .tabItem { Label("Map", systemImage: "map") }
                    TimelineScreen()
                        .tabItem { Label("Timeline", systemImage: "calendar") }
                }
            }
        }
        .task {
            if !store.needsOnboarding, store.loadState == .idle {
                await store.reload()
            }
        }
        .onChange(of: scenePhase) {
            // Pick up access changed in Settings, and new photos/events, when returning to the app.
            if scenePhase == .active, !store.needsOnboarding, store.loadState == .loaded {
                Task { await store.reload() }
            }
        }
    }
}
