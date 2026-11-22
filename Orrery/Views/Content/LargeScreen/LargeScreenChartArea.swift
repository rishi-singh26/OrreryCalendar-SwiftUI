//
//  LargeScreenChartArea.swift
//  Orrery
//

import SwiftUI

/// `LargeScreenView`'s title, orrery chart and Moon phase row, laid out side by side when the
/// available area is wider than tall and stacked otherwise.
struct LargeScreenChartArea: View {
    let viewModel: ContentViewModel
    let snapshot: DaySnapshot?
    let theme: ThemeColors
    let size: CGSize
    let showOrbits: Bool
    let showLabels: Bool
    let showSunHalo: Bool
    let moonSizeMultiplier: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SelectedDateTitleText(date: viewModel.selectedDate)
                .padding([.top, .leading])
            
            let isWide = size.width > size.height
            let layout: AnyLayout = isWide ? AnyLayout(HStackLayout()) : AnyLayout(VStackLayout())
            
            layout {
                if isWide {
                    Spacer()
                }
                // Always mounted — `OrreryView` shows its own loading pose (planets
                // lined up left of their orbits) while `snapshot` is nil, then eases
                // into place once it arrives, rather than the chart not appearing
                // at all until data is ready.
                OrreryView(
                    snapshot: snapshot, showOrbits: showOrbits, showLabels: showLabels, showSunHalo: showSunHalo, theme: theme,
                    aspectRatio: 1, dateChangeAnimationTrigger: viewModel.dateChangeAnimationTrigger
                )
                
                Spacer()
                
                if let snapshot {
                    MoonPhaseRow(moonPhaseDeg: snapshot.moonPhaseDeg, theme: theme, sizeMultiplier: moonSizeMultiplier, horizontal: !isWide)
                }
                
                if isWide {
                    Spacer()
                }
            }
        }
        .padding(.bottom, 100)
    }
}
