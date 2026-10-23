import SwiftUI

struct FilterView: View {
    @Environment(MemoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store

        NavigationStack {
            Form {
                Section("Show") {
                    Toggle("Photos", isOn: $store.filter.showPhotos)
                    Toggle("Events", isOn: $store.filter.showEvents)
                }

                Section("Year") {
                    Picker("Year", selection: $store.filter.year) {
                        Text("All years").tag(Int?.none)
                        ForEach(store.availableYears, id: \.self) { year in
                            // String(year) avoids the "2,024" thousands separator.
                            Text(String(year)).tag(Int?.some(year))
                        }
                    }
                }

                if !store.calendars.isEmpty {
                    Section {
                        ForEach(store.calendars) { calendar in
                            Toggle(isOn: isShown(calendar)) {
                                Label {
                                    Text(calendar.title)
                                } icon: {
                                    Circle()
                                        .fill(calendar.color.swiftUIColor)
                                        .frame(width: 12, height: 12)
                                }
                            }
                        }
                    } header: {
                        Text("Calendars")
                    } footer: {
                        Text("Your calendars work as categories, e.g. Travel or Study.")
                    }
                }

                Section {
                    LabeledContent("Photos with a location", value: "\(store.locatedPhotoCount) of \(store.photos.count)")
                    LabeledContent("Events with a location", value: "\(store.locatedEventCount) of \(store.events.count)")
                } footer: {
                    Text("Only items with a location appear on the map. The timeline shows everything.")
                }

                Section {
                    Button("Reset filters", role: .destructive) {
                        store.filter = MemoryFilter()
                    }
                    .disabled(store.filter == MemoryFilter())
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func isShown(_ calendar: CalendarInfo) -> Binding<Bool> {
        Binding(
            get: { !store.filter.hiddenCalendarIDs.contains(calendar.id) },
            set: { isShown in
                if isShown {
                    store.filter.hiddenCalendarIDs.remove(calendar.id)
                } else {
                    store.filter.hiddenCalendarIDs.insert(calendar.id)
                }
            }
        )
    }
}
