//
//  GlassButton.swift
//  Orrery
//
//  Created by Rishi Singh on 06/09/26.
//

import SwiftUI

struct GlassButton<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled

    // MARK: - Properties
    let systemName: String?
    let label: Label?
    let circular: Bool
    let size: CGFloat
    let useInteractiveGlass: Bool
    let action: () -> Void

    // MARK: - Initialiser 1: Icon Only (Circular)
    init(
        systemName: String,
        size: CGFloat = 50.0,
        useInteractiveGlass: Bool = true,
        action: @escaping () -> Void
    ) where Label == EmptyView {
        self.systemName = systemName
        self.label = nil
        self.circular = true
        self.size = size
        self.useInteractiveGlass = useInteractiveGlass
        self.action = action
    }

    // MARK: - Initialiser 2: Custom Label
    init(
        circular: Bool = false,
        size: CGFloat = 50.0,
        useInteractiveGlass: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.label = label()
        self.systemName = nil
        self.circular = circular
        self.size = size
        self.useInteractiveGlass = useInteractiveGlass
        self.action = action
    }

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            let glass: Glass = useInteractiveGlass ? .regular.interactive() : .regular
            
            buildButton
                .glassEffect(glass, in: AnyShape(circular ? AnyShape(Circle()) : AnyShape(Capsule())))
                .contentShape(circular ? AnyShape(Circle()) : AnyShape(Capsule()))
        } else {
            buildButton
                .withSurface(in: AnyShape(circular ? AnyShape(Circle()) : AnyShape(Capsule())))
                .contentShape(circular ? AnyShape(Circle()) : AnyShape(Capsule()))
        }
    }
    
    var buildButton: some View {
        Button(action: action) {
            Group {
                if let systemName, label == nil {
                    Image(systemName: systemName)
                        .font(.title2)
                }
                
                if let label, systemName == nil {
                    label
                }
            }
            .foregroundStyle(isEnabled ? .primary : Color.secondary.opacity(0.7))
            .padding(.horizontal, circular ? 0 : 20)
            .frame(height: size)
            .frame(width: circular ? size : nil)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        // 1. Icon Only — Circular
        GlassButton(systemName: "plus") {
            print("Icon button tapped!")
        }

        // 2. Simple Text Label — Capsule
        GlassButton(
            action: {
                print("Label button tapped!")
            }
        ) {
            Text("Add Item")
                .font(.headline)
        }

        // 3. Custom View Label
        GlassButton(
            action: {
                print("Custom label tapped!")
            }
        ) {
            HStack(spacing: 6) {
                Text("Favourite")
                Image(systemName: "heart.fill")
            }
            .font(.headline)
        }

        // 4. SwiftUI Label View
        GlassButton(
            action: {
                print("Locked button tapped!")
            }
        ) {
            Label("Locked", systemImage: "checkmark")
                .font(.headline)
        }
        .disabled(true)

        // 5. Rich Custom Label
        GlassButton(
            action: {
                print("Cart tapped!")
            }
        ) {
            VStack(spacing: 2) {
                Text("Add to Cart")
                    .font(.headline)

                Text("$24.99")
                    .font(.caption)
                    .opacity(0.7)
            }
        }
    }
}

