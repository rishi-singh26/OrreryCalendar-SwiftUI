//
//  AppearanceIconView.swift
//  Orrery
//
//  Created by Rishi Singh on 07/09/26.
//

import SwiftUI

struct AppearanceIconView: View {
    @Environment(\.colorScheme) private var colorScheme
    var size: CGFloat
    var tint: Color?
    let twoFifthSize: CGFloat
    
    init(size: CGFloat = 50, tint: Color? = nil) {
        self.size = size
        self.tint = tint
        twoFifthSize = (size / 5) * 2
    }
    
    /// The tint when provided, otherwise black/white based on the color scheme.
    private var primaryColor: Color {
        tint ?? (colorScheme == .dark ? .white : .black)
    }
    
    /// The reversed color used by the left semicircle. It is not tinted, so it keeps
    /// contrasting with the (tinted) filled half.
    private var contrastColor: Color {
        colorScheme == .dark ? .black : .white
    }
    
    var body: some View {
        ZStack {
            Image(systemName: colorScheme == .dark ? "circle.righthalf.filled" : "circle.lefthalf.filled")
                .resizable()
                .frame(width: size, height: size)
                .foregroundStyle(primaryColor)
            Semicircle(direction: .left)
                .frame(width: twoFifthSize, height: twoFifthSize)
                .foregroundStyle(contrastColor)
            Semicircle(direction: .right)
                .frame(width: twoFifthSize, height: twoFifthSize)
                .foregroundStyle(primaryColor)
        }
    }
}

#Preview {
    AppearanceIconView()
}
