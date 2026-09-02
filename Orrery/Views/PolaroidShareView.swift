//
//  PolaroidShareView.swift
//  Orrery
//
//  Pure render target for sharing (spec §7): the orrery chart, Sun, planets, orbit
//  rings (if enabled), and both Moon phase discs with labels — no buttons, no settings
//  chrome, no scrub timeline. The polaroid frame itself (cream border, dark caption) is
//  fixed regardless of app theme; the chart content inside follows the current
//  orbit/label/small-moon toggle state and color scheme, per spec.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PolaroidShareView: View {
    let snapshot: DaySnapshot
    let showOrbits: Bool
    let showLabels: Bool
    let smallMoon: Bool
    let colorScheme: ColorScheme

    private var theme: ThemeColors { colorScheme == .dark ? .dark : .light }

    var body: some View {
        VStack(spacing: 18) {
            OrreryView(snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, theme: theme)
                .frame(width: 320, height: 285)
                .padding(12)
                .background(theme.background)

            MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, smallMoon: smallMoon, theme: theme)

            Text(snapshot.date.formatted(.dateTime.year().month(.wide).day()))
                .font(.system(.title, design: .serif))
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
    let showLabels: Bool
    let smallMoon: Bool
    let colorScheme: ColorScheme

    @State private var renderedImage: Image?
    @State private var shareURL: URL?

    var body: some View {
        Group {
            if let renderedImage, let shareURL {
                // Share the full-resolution PNG file rather than the SwiftUI `Image` itself:
                // ShareLink's Transferable conformance for `Image` re-renders at the view's
                // display size and loses the extra pixel density from `renderer.scale`,
                // producing a soft, low-quality export. A file URL preserves the exact
                // pixels the renderer produced. `renderedImage` is kept only for the
                // (small) SharePreview thumbnail.
                ShareLink(item: shareURL, preview: SharePreview(captionText, image: renderedImage)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            } else {
                Label("Share", systemImage: "square.and.arrow.up")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: renderKey) {
            // Debounce: `renderKey` embeds the selected date, which changes on every
            // day the scrub timeline's drag/scroll gesture crosses (updated
            // continuously, not just on release). Without this, each of those days
            // would trigger a full off-screen render + PNG encode + disk write — all
            // synchronous, uninterruptible main-thread work — competing with the
            // gesture for every frame. Waiting here for the id to settle means only
            // the final date (or a deliberate settings change) actually renders;
            // `Task.sleep` is cancellable, so a superseded id never reaches `render()`.
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            render()
        }
    }

    private var renderKey: String {
        "\(snapshot.date.timeIntervalSince1970)-\(showOrbits)-\(showLabels)-\(smallMoon)-\(colorScheme == .dark)"
    }

    private var captionText: String {
        snapshot.date.formatted(.dateTime.year().month(.wide).day())
    }

    @MainActor
    private func render() {
        let content = PolaroidShareView(
            snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, smallMoon: smallMoon, colorScheme: colorScheme
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else { return }

        let pngData: Data?
        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        renderedImage = Image(nsImage: nsImage)
        pngData = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
        #else
        let uiImage = UIImage(cgImage: cgImage, scale: renderer.scale, orientation: .up)
        renderedImage = Image(uiImage: uiImage)
        pngData = uiImage.pngData()
        #endif

        guard let pngData else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("png")
        do {
            try pngData.write(to: url)
            // Each render writes a fresh UUID-named file rather than overwriting the
            // last one, so the previous render's file (if any) is now orphaned —
            // remove it now that the new one has taken its place, otherwise every
            // render (one per date/settings change) leaks a PNG into the temp
            // directory for the rest of the session.
            if let previousURL = shareURL, previousURL != url {
                try? FileManager.default.removeItem(at: previousURL)
            }
            shareURL = url
        } catch {
            shareURL = nil
        }
    }
}
