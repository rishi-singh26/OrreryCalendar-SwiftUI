//
//  SavedListView.swift
//  Orrery
//
//  Saved dates list (spec §7): most recent first, swipe-to-delete, per-row share via
//  the same `PolaroidShareButton` used for the current date. Tapping a row jumps the
//  main timeline to that date.
//

import SwiftUI
import SwiftData

struct SavedListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedSnapshot.date, order: .reverse) private var savedSnapshots: [SavedSnapshot]

    @AppStorage(AppStorageKeys.showOrbits) private var showOrbits = true
    @AppStorage(AppStorageKeys.smallMoon) private var smallMoon = false

    /// Jumps the main timeline to `Date` and dismisses this list.
    let onJumpToDate: (Date) -> Void

    var body: some View {
        ThemeReader { theme, colorScheme in
            List {
                if savedSnapshots.isEmpty {
                    ContentUnavailableView(
                        "No saved dates",
                        systemImage: "bookmark",
                        description: Text("Save a date from the main view to see it here.")
                    )
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(savedSnapshots) { entry in
                        row(for: entry, theme: theme, colorScheme: colorScheme)
                    }
                }
            }
        }
    }

    private func row(for entry: SavedSnapshot, theme: ThemeColors, colorScheme: ColorScheme) -> some View {
        Button {
            onJumpToDate(entry.date)
            dismiss()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(theme.moonDark)
                    MoonPhaseShape(fraction: entry.moonPhaseDeg / 360)
                        .fill(theme.ink)
                }
                .frame(width: 32, height: 32)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.date.formatted(.dateTime.year().month(.wide).day()))
                        .foregroundStyle(theme.ink)
                    Text("Saved \(entry.savedAt.formatted(.relative(presentation: .named)))")
                        .font(.footnote)
                        .foregroundStyle(theme.muted)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu(menuItems: {
            PolaroidShareButton(
                snapshot: entry.daySnapshot, showOrbits: showOrbits, smallMoon: smallMoon, colorScheme: colorScheme
            )
            
            Divider()
            
            Button(role: .destructive) {
                modelContext.delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        })
#if os(iOS)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            PolaroidShareButton(
                snapshot: entry.daySnapshot, showOrbits: showOrbits, smallMoon: smallMoon, colorScheme: colorScheme
            )
            .labelStyle(.iconOnly)
            .tint(theme.brassDim)
        }
#endif
    }
}
