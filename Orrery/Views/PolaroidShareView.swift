//
//  PolaroidShareView.swift
//  Orrery
//
//  Pure render target for sharing (spec §7): the orrery chart, Sun, planets, orbit
//  rings (if enabled), and both Moon phase discs with labels — no buttons, no settings
//  chrome, no scrub timeline. The polaroid frame itself (cream border, dark caption) is
//  fixed regardless of app theme; the chart content inside follows the current
//  orbit/label toggle state and color scheme, per spec.
//

import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PolaroidShareView: View {
    let snapshot: DaySnapshot
    let showOrbits: Bool
    let showLabels: Bool
    let showSunHalo: Bool
    let colorScheme: ColorScheme

    private var theme: ThemeColors { colorScheme == .dark ? .dark : .light }

    /// Corner radius of the mesh-gradient panel behind the chart.
    private let panelCornerRadius: CGFloat = 20
    /// Space between that panel and the outer polaroid edge.
    private let outerPadding: CGFloat = 24
    /// The outer edge's radius, kept concentric with `panelCornerRadius` — offset by
    /// exactly the padding between them so both corners share the same center.
    private var outerCornerRadius: CGFloat { panelCornerRadius + outerPadding - 6 }

    var body: some View {
        VStack(spacing: 18) {
            OrreryView(snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, theme: theme)
                .frame(width: 320, height: 320)
                .background(
                    // `BackgroundView` reads colorScheme from the environment, which
                    // `ImageRenderer` won't otherwise supply for an off-screen render —
                    // forced explicitly to the same `colorScheme` `theme` is derived from.
                    BackgroundView()
                        .environment(\.colorScheme, colorScheme)
                        .clipShape(RoundedRectangle(cornerRadius: panelCornerRadius, style: .continuous))
                )

            MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, theme: theme)

            SelectedDateTitleText(date: snapshot.date)
        }
        .padding(outerPadding)
        .padding(.bottom, 8)
        .background(ThemeColors.polaroidFrame) // fixed cream polaroid frame
        .clipShape(RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous))
    }
}

/// Wraps the rendered PNG bytes and declares them as `.png` to the share sheet's item
/// provider. Plain `URL` conforms to `Transferable` itself, but exports as a generic
/// file/URL reference rather than typed image data, and a `FileRepresentation` promise
/// (the natural-looking alternative) several third-party share extensions — WhatsApp
/// among them — fail to resolve. Handing over the raw `Data` directly via
/// `DataRepresentation` sidesteps both: it's typed as an image and needs no file promise.
struct PolaroidPNGFile: Transferable {
    let data: Data
    let date: Date

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
            .suggestedFileName { "OrreryCalendar-\(fileNameDateFormatter.string(from: $0.date))" }
    }

    /// `yyyy-MM-dd`, fixed to UTC/POSIX like `SelectedDateTitleText`'s formatter — a
    /// sortable, filesystem-safe stand-in for that one's display format (which contains
    /// commas and spaces).
    private static let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

/// Renders `PolaroidShareView` to an image and offers it via `ShareLink`. The same view
/// backs both "share the currently viewed date" and "share a saved list entry" — spec
/// §7's explicit requirement that both flows share one render path.
struct PolaroidShareButton: View {
    let snapshot: DaySnapshot
    let showOrbits: Bool
    let showLabels: Bool
    let showSunHalo: Bool
    let colorScheme: ColorScheme

    @State private var renderedImage: Image?
    @State private var pngData: Data?

    var body: some View {
        Group {
            if let renderedImage, let pngData {
                // Share the full-resolution PNG bytes rather than the SwiftUI `Image` itself:
                // ShareLink's Transferable conformance for `Image` re-renders at the view's
                // display size and loses the extra pixel density from `renderer.scale`,
                // producing a soft, low-quality export. Handing over `pngData` directly
                // preserves the exact pixels the renderer produced. `renderedImage` is kept
                // only for the (small) SharePreview thumbnail.
                ShareLink(item: PolaroidPNGFile(data: pngData, date: snapshot.date), preview: SharePreview(captionText, image: renderedImage)) {
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
            // would trigger a full off-screen render + PNG encode — all synchronous,
            // uninterruptible main-thread work — competing with the
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
        "\(snapshot.date.timeIntervalSince1970)-\(showOrbits)-\(showLabels)-\(showSunHalo)-\(colorScheme == .dark)"
    }

    private var captionText: String {
        SelectedDateTitleText.string(from: snapshot.date)
    }

    @MainActor
    private func render() {
        let content = PolaroidShareView(
            snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, colorScheme: colorScheme
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else { return }

        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        renderedImage = Image(nsImage: nsImage)
        pngData = NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
        #else
        let uiImage = UIImage(cgImage: cgImage, scale: renderer.scale, orientation: .up)
        renderedImage = Image(uiImage: uiImage)
        pngData = uiImage.pngData()
        #endif
    }
}
