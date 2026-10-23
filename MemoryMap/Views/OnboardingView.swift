import SwiftUI

struct OnboardingView: View {
    @Environment(MemoryStore.self) private var store
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "map.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.tint)

            VStack(spacing: 10) {
                Text("Memory Map")
                    .font(.largeTitle.bold())
                Text("See your photos and calendar on one map — where you went, when, and what you wrote about it.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(symbol: "photo.on.rectangle", title: "Photos", text: "Placed on the map by where you took them.")
                FeatureRow(symbol: "calendar", title: "Calendar", text: "Events with a location, grouped by your own calendars.")
                FeatureRow(symbol: "lock.shield", title: "Stays on your iPhone", text: "Nothing is uploaded. There is no account and no server.")
            }
            .padding(.horizontal, 8)

            Spacer()

            Button {
                isRequesting = true
                Task {
                    await store.requestAccess()
                    isRequesting = false
                }
            } label: {
                Group {
                    if isRequesting {
                        ProgressView()
                    } else {
                        Text("Allow access")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRequesting)
        }
        .padding(28)
    }
}

private struct FeatureRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
