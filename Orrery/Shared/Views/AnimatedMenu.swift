//
//  AnimatedMenu.swift
//  Orrery
//
//  Created by Rishi Singh on 02/09/26.
//

import SwiftUI

enum AlignmentType: Hashable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    
    var alignment: Alignment {
        switch self {
        case .topLeading:
            return .topLeading
        case .topTrailing:
            return .topTrailing
        case .bottomLeading:
            return .bottomLeading
        case .bottomTrailing:
            return .bottomTrailing
        }
    }
}


struct AnimatedMenu<Content: View, Label: View>: View, Animatable {
    var alignment: Alignment
    var progress: CGFloat
    var labelSize: CGSize = .init(width: 55, height: 55)
    var cornerRadius: CGFloat = 30
    @ViewBuilder var content: Content
    @ViewBuilder var label: Label
    
    // View Properties
    @State private var contentSize: CGSize = .zero
    
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    
    var body: some View {
        let widthDiff = contentSize.width - labelSize.width
        let heightDiff = contentSize.height - labelSize.height
        
        let rWidth = widthDiff * contentOpacity
        let rHeight = heightDiff * contentOpacity
        
        ZStack(alignment: alignment) {
            content
                .compositingGroup()
                .scaleEffect(contentScale)
                .blur(radius: 14 * blurProgress)
                .opacity(contentOpacity)
                .onGeometryChange(for: CGSize.self) {
                    $0.size
                } action: { newValue in
                    contentSize = newValue
                }
                .fixedSize()
                .frame(
                    width: labelSize.width + rWidth,
                    height: labelSize.height + rHeight
                )
            
            
            label
                .compositingGroup()
                .blur(radius: 14 * blurProgress)
                .opacity(1 - labelOpacity)
                .frame(width: labelSize.width, height: labelSize.height)
        }
        .compositingGroup()
        .withOSSurface(in: .rect(cornerRadius: cornerRadius))
        .clipShape(.rect(cornerRadius: cornerRadius))
        .scaleEffect(
            x: 1 - (blurProgress * 0.35),
            y: 1 + (blurProgress * 0.35),
            anchor: scaleAnchor
        )
        .offset(y: offset * blurProgress)
    }
    
    var labelOpacity: CGFloat {
        min(progress / 0.35, 1)
    }
    
    var contentOpacity: CGFloat {
        max(progress - 0.35, 0) / 0.65
    }
    
    var contentScale: CGFloat {
        let minAspectScale = min(labelSize.width / contentSize.width, labelSize.height / contentSize.height)
        
        return minAspectScale + (1 - minAspectScale) * progress
    }
    
    var blurProgress: CGFloat {
        // 0 -> 0.5 -> 0
        return progress > 0.5 ? (1 - progress) / 0.5 : progress / 0.5
    }
    
    var offset: CGFloat {
        switch alignment {
        case .bottom, .bottomLeading, .bottomTrailing: return -75
        case .top, .topLeading, .topTrailing: return 75
        // Center
        default: return 0
        }
    }
    
    // Converting Alignment into UnitPoint for ScaleEffect
    var scaleAnchor: UnitPoint {
        switch alignment {
        case .bottomLeading: .bottomLeading
        case .bottom: .bottom
        case .bottomTrailing: .bottomTrailing
        case .topLeading: .topLeading
        case .top: .top
        case .topTrailing: .topTrailing
        case .leading: .leading
        case .trailing: .trailing
        default: .center
        }
    }
}

struct AnimatedMenuTile: View {
    var image: String, title: String
    
    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: image)
                .font(.title3)
                .symbolVariant(.fill)
                .frame(width: 45, height: 45)
                .background(.background, in: .circle)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .fontWeight(.semibold)
                
                Text("This is a sample text description")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .contentShape(.rect)
    }
}


#Preview {
    @Previewable @State var progress: CGFloat = 0
    @Previewable @State var alignment: AlignmentType = .bottomTrailing
    @Previewable @State var animation: Animation = .bouncy(duration: 0.3, extraBounce: 0.02)
    
    List {
        Section("Preview") {
            Rectangle()
                .foregroundStyle(.clear)
                .background {
                    Image("1")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .contentShape(.rect)
                        .onTapGesture {
                            withAnimation(animation) {
                                progress = 0
                            }
                        }
                }
                .overlay {
                    AnimatedMenu(alignment: alignment.alignment, progress: progress) {
                        VStack(alignment: .leading, spacing: 12) {
                            AnimatedMenuTile(image: "paperplane", title: "Send")
                            AnimatedMenuTile(image: "arrow.trianglehead.2.counterclockwise", title: "Swap")
                            AnimatedMenuTile(image: "arrow.down", title: "Receive")
                        }
                        .padding(10)
                    } label: {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.title3)
                            .frame(width: 50, height: 50)
                            .contentShape(.rect)
                            .onTapGesture {
                                withAnimation(animation) {
                                    progress = 1
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment.alignment)
                    .padding(15)
                }
                .frame(height: 330)
        }
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        
        Section("Properties") {
            Slider(value: $progress.animation())
        }
        
        Picker("", selection: $alignment) {
            Text("T-Lead")
                .tag(AlignmentType.topLeading)
            Text("T-Trail")
                .tag(AlignmentType.topTrailing)
            Text("B-Lead")
                .tag(AlignmentType.bottomLeading)
            Text("B-Trail")
                .tag(AlignmentType.bottomTrailing)
        }
        .pickerStyle(.segmented)
    }
}


