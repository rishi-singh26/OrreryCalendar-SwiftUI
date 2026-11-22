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

/// Everything needed to render the polaroid, exported as a `.png` only when the share
/// sheet actually asks for the data — i.e. after the user taps Share — so nothing is
/// rendered while the date is merely being scrubbed or changed.
///
/// The PNG bytes are handed over directly via `DataRepresentation` rather than as a
/// `URL`, a `FileRepresentation` promise, or a SwiftUI `Image`: plain `URL` exports as a
/// generic file reference rather than typed image data, several third-party share
/// extensions (WhatsApp among them) fail to resolve a file promise, and `Image`'s
/// `Transferable` conformance re-renders at display size, losing the extra pixel
/// density from `renderer.scale`. Raw `Data` is typed as an image, needs no file
/// promise, and preserves the exact pixels the renderer produced.
struct PolaroidShareItem: Transferable {
    let snapshot: DaySnapshot
    let showOrbits: Bool
    let showLabels: Bool
    let showSunHalo: Bool
    let colorScheme: ColorScheme

    private enum ExportError: Error {
        case renderFailed
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            // `ImageRenderer` must run on the main actor.
            guard let data = await item.renderPNGData() else { throw ExportError.renderFailed }
            return data
        }
        .suggestedFileName { "OrreryCalendar-\(fileNameDateFormatter.string(from: $0.snapshot.date))" }
    }

    /// Renders `PolaroidShareView` off-screen at 3× and encodes it as PNG.
    @MainActor
    private func renderPNGData() -> Data? {
        let content = PolaroidShareView(
            snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, colorScheme: colorScheme
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = 3
        guard let cgImage = renderer.cgImage else { return nil }

        #if os(macOS)
        return NSBitmapImageRep(cgImage: cgImage).representation(using: .png, properties: [:])
        #else
        return UIImage(cgImage: cgImage, scale: renderer.scale, orientation: .up).pngData()
        #endif
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

/// Offers `PolaroidShareView` via `ShareLink`. The same button backs both "share the
/// currently viewed date" and "share a saved list entry" — spec §7's explicit
/// requirement that both flows share one render path. The render itself is deferred
/// until the share sheet requests the data (see `PolaroidShareItem`), so this view does
/// no work when its inputs change.
struct PolaroidShareButton: View {
    let snapshot: DaySnapshot
    let showOrbits: Bool
    let showLabels: Bool
    let showSunHalo: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        ShareLink(
            item: PolaroidShareItem(
                snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, colorScheme: colorScheme
            ),
            preview: SharePreview(captionText)
        ) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }
    
    private var captionText: String {
        SelectedDateTitleText.string(from: snapshot.date)
    }
}
