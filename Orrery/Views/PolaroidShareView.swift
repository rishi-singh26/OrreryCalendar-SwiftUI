//
//  PolaroidShareView.swift
//  Orrery
//
//  Pure render target for sharing (spec §7): the orrery chart, Sun, planets, orbit
//  rings (if enabled), and both Moon phase discs with labels — no buttons, no settings
//  chrome, no scrub timeline. The polaroid frame itself (cream border, dark caption) is
//  fixed regardless of app theme; the chart content inside follows the current
//  orbit/small-moon toggle state and color scheme, per spec.
//

import SwiftUI

struct PolaroidShareView: View {
    let snapshot: DaySnapshot
    let showOrbits: Bool
    let smallMoon: Bool
    let colorScheme: ColorScheme

    private var theme: ThemeColors { colorScheme == .dark ? .dark : .light }

    var body: some View {
        VStack(spacing: 18) {
            OrreryView(snapshot: snapshot, showOrbits: showOrbits, theme: theme)
                .frame(width: 320, height: 285)
                .padding(12)
                .background(theme.background)

            MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, smallMoon: smallMoon, theme: theme)

            Text(snapshot.date.formatted(.dateTime.year().month(.wide).day()))
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.75))
        }
        .padding(24)
        .padding(.bottom, 8)
        .background(Color(red: 0.98, green: 0.97, blue: 0.94)) // fixed cream polaroid frame
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}

/// Renders `PolaroidShareView` to an image and offers it via `ShareLink`. The same view
/// backs both "share the currently viewed date" and "share a saved list entry" — spec
/// §7's explicit requirement that both flows share one render path.
struct PolaroidShareButton: View {
    let snapshot: DaySnapshot
    let showOrbits: Bool
    let smallMoon: Bool
    let colorScheme: ColorScheme

    @State private var renderedImage: Image?

    var body: some View {
        Group {
            if let renderedImage {
                ShareLink(item: renderedImage, preview: SharePreview(captionText, image: renderedImage)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } else {
                Label("Share", systemImage: "square.and.arrow.up")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: renderKey) {
            render()
        }
    }

    private var renderKey: String {
        "\(snapshot.date.timeIntervalSince1970)-\(showOrbits)-\(smallMoon)-\(colorScheme == .dark)"
    }

    private var captionText: String {
        snapshot.date.formatted(.dateTime.year().month(.wide).day())
    }

    @MainActor
    private func render() {
        let content = PolaroidShareView(
            snapshot: snapshot, showOrbits: showOrbits, smallMoon: smallMoon, colorScheme: colorScheme
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        #if os(macOS)
        if let nsImage = renderer.nsImage {
            renderedImage = Image(nsImage: nsImage)
        }
        #else
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
        #endif
    }
}
