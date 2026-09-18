//
//  AppIconOptionButton.swift
//  Orrery
//
//  Created by Rishi Singh on 13/09/26.
//

#if os(iOS)
import SwiftUI

struct AppIconOptionButton: View {
    let option: AppIconOption
    let isSelected: Bool
    let action: () -> Void

    private static let size: CGFloat = 80

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(option.previewImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Self.size, height: Self.size)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
                    )

                Text(option.displayName)
                    .font(.footnote)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    HStack {
        AppIconOptionButton(option: .primary, isSelected: true, action: {})
        AppIconOptionButton(option: .two, isSelected: false, action: {})
    }
    .padding()
}
#endif
