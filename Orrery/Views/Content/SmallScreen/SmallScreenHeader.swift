//
//  SmallScreenHeader.swift
//  Orrery
//

#if os (iOS)
import SwiftUI

/// Selected-date title plus the "Planets" toggle at the top of `SmallScreenView`.
struct SmallScreenHeader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let viewModel: ContentViewModel
    
    var body: some View {
        HStack {
            SelectedDateTitleText(date: viewModel.selectedDate)
            
            Spacer()
            
            PlanetsButton {
                withAnimation(viewModel.effectiveAnimation(reduceMotion: reduceMotion)) {
                    viewModel.toggleControlPresentation(.planets)
                }
            }
        }
        .padding(.horizontal, 25)
        .padding(.top, 17)
    }
}

private struct PlanetsButton: View {
    let action: () -> Void
    
    private var button: some View {
        Button(action: action) {
            Text("Planets")
                .font(.caption)
                .monospaced()
        }
    }
    
    var body: some View {
        if #available(iOS 26.0, *) {
            button
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
        } else {
            button
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
        }
    }
}
#endif
