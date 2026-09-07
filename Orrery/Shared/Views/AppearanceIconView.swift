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
    let twoFifthSize: CGFloat
    
    init(size: CGFloat = 50) {
        self.size = size
        twoFifthSize = (size / 5) * 2
    }
    
    var body: some View {
        ZStack {
            Image(systemName: colorScheme == .dark ? "circle.righthalf.filled" : "circle.lefthalf.filled")
                .resizable()
                .frame(width: size, height: size)
                .foregroundStyle(colorScheme == .dark ? .white : .black)
            Semicircle(direction: .left)
                .frame(width: twoFifthSize, height: twoFifthSize)
                .foregroundStyle(colorScheme == .dark ? .black : .white)
            Semicircle(direction: .right)
                .frame(width: twoFifthSize, height: twoFifthSize)
                .foregroundStyle(colorScheme == .dark ? .white : .black)
        }
    }
}

#Preview {
    AppearanceIconView()
}
