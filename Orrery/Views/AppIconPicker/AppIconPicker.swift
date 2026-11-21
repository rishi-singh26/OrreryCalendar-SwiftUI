//
//  AppIconPicker.swift
//  TesterApp
//
//  Created by Rishi Singh on 21/11/26.
//  Code from this video: https://youtu.be/o_insSNkXds?si=qCfLpNy_BW-hO_4g
//

#if os(iOS)
import SwiftUI

extension View {
    @ContentBuilder
    func appIconPicker(
        isPresented: Binding<Bool>,
        @ContentBuilder primaryIconThumbnail: @escaping () -> Image,
        @ContentBuilder alternateIconThumbnail: @escaping (_ iconName: String) -> Image,
        @ContentBuilder alternateIconTitle: @escaping (_ iconName: String) -> Text,
    ) -> some View {
        self
            .sheet(isPresented: isPresented) {
                AppIconPicker(
                    primaryIconThumbnail: primaryIconThumbnail,
                    alternateIconThumbnail: alternateIconThumbnail,
                    alternateIconTitle: alternateIconTitle
                )
            }
    }
}

struct AppIconPicker: View {
    @ContentBuilder var primaryIconThumbnail: Image
    @ContentBuilder var alternateIconThumbnail: (_ iconName: String) -> Image
    @ContentBuilder var alternateIconTitle: (_ iconName: String) -> Text
    
    // View Properties
    @Environment(\.dismiss) private var dismiss
    @State private var activeIcon: String?
    @State private var iconsList: [String] = Bundle.main.iconsList
    @State private var scrollOffset: CGFloat = 0
    
    var body: some View {
        Rectangle()
            .foregroundStyle(.clear)
            .overlay {
                GeometryReader {
                    let size = $0.size
                    let iconSize = size.height * 0.5
                    
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 0) {
                            // Primary Icon
                            IconView("", isPrimary: true, iconSize: iconSize)
                                .id("Primary")
                            
                            ForEach(iconsList, id: \.self) { icon in
                                IconView(icon, isPrimary: false, iconSize: iconSize)
                                    .id(icon)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
                    .scrollPosition(id: $activeIcon)
                    .safeAreaPadding(.horizontal, (size.width - iconSize) / 2)
                    .overlay(alignment: .top) {
                        IndicatorView()
                    }
                    .overlay(alignment: .bottom) {
                        IconTitleView(iconSize)
                    }
                    .onScrollGeometryChange(for: CGFloat.self) {
                        $0.contentOffset.x + $0.contentInsets.leading
                    } action: { oldValue, newValue in
                        scrollOffset = newValue
                    }

                }
            }
            .bottomSafeAreaBar {
                BottomBar()
            }
            .overlay(alignment: .topLeading) {
                // Close Button
                GlassButton(circular: true, size: 50, useInteractiveGlass: true) {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 20, height: 30)
                }
            }
            .safeAreaPadding(15)
            .ignoresSafeArea(.all, edges: .bottom)
            .presentationDetents([.height(400)])
            .presentationCompactAdaptation(.sheet)
            .onAppear {
                if activeIcon == nil {
                    activeIcon = activeSystemIcon
                }
            }
    }
    
    // Icon View
    @ContentBuilder
    private func IconView(_ icon: String, isPrimary: Bool, iconSize: CGFloat) -> some View {
        ZStack {
            if isPrimary {
                primaryIconThumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            } else {
                alternateIconThumbnail(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            }
        }
        .frame(width: iconSize, height: iconSize)
        .visualEffect { content, proxy in
            let minX = proxy.frame(in: .scrollView).minX
            let progress = min(abs(minX / iconSize), 1)
            let angle = iconSize / 2
            
            return content
                .scaleEffect(1 - (progress * 0.3))
                .blur(radius: progress * 4)
                .offset(x: minX / 2)
                // Adjust the angle, according to your own liking
                .rotationEffect(.init(degrees: progress * -angle))
        }
    }
    
    // Indicator View
    @ContentBuilder
    private func IndicatorView() -> some View {
        let icons = ["Primary"] + self.iconsList
        let index = icons.firstIndex(of: activeIcon ?? "") ?? 0
        
        HStack(alignment: .bottom, spacing: 2) {
            Text(String(format: "%02d", index + 1))
                .font(.title3.bold())
                .foregroundStyle(.tint)
                .contentTransition(.numericText(value: Double(index)))
            
            Group {
                Text("/")
                
                Text(String(format: "%02d", icons.count))
            }
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
        }
        .monospaced()
        .animation(.easeInOut(duration: 0.25), value: activeIcon)
        .offset(y: 3)
    }
    
    // Title View
    @ContentBuilder
    private func IconTitleView(_ iconSize: CGFloat) -> some View {
        let icons = ["Primary"] + self.iconsList
        let scrollProgress = scrollOffset / iconSize
        
        ZStack {
            ForEach(icons.indices, id: \.self) { index in
                let icon = icons[index]
                let progress = scrollProgress - CGFloat(index)
                let cappedProgress = abs(progress)
                
                alternateIconTitle(icon)
                    .font(.title2.bold())
                    .offset(x: progress * -150)
                    .opacity(1 - (cappedProgress * 2))
            }
        }
        .offset(y: -25)
    }
    
    // Bottom Bar content
    @ContentBuilder
    private func BottomBar() -> some View {
        let isActive = activeIcon == activeSystemIcon
        
        VStack (spacing: 15) {
            Text ("Choose a look for your home screen. You can switch back to any icon at any time.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Button {
                // Primary icons means default one, so nil value!
                UIApplication.shared.setAlternateIconName(activeIcon == "Primary" ? nil : activeIcon) { _ in
                    // When set successfully, dismissing view!
                    dismiss()
                }
            } label: {
                Text(isActive ? "Currently Active" : "Activate App Icon")
                    .contentTransition(.numericText())
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .prominentGlassButtonStyle()
            .disabled(isActive)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .padding(.bottom, 10)
            .padding(.top, 5)
        }
        .padding(.horizontal, 15)
    }
    
    var activeSystemIcon: String {
        UIApplication.shared.alternateIconName ?? "Primary"
    }
}

fileprivate extension View {
    /// Uses `glassProminent` on iOS 26+, falling back to `borderedProminent` on earlier versions.
    @ViewBuilder
    func prominentGlassButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }

    /// Uses `safeAreaBar` on iOS 26+, falling back to `safeAreaInset` on earlier versions.
    @ViewBuilder
    func bottomSafeAreaBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            self.safeAreaBar(edge: .bottom, spacing: 0) {
                content()
            }
        } else {
            self.safeAreaInset(edge: .bottom, spacing: 0) {
                content()
            }
        }
    }
}

// Extracting all available alternate app icons via bundle
fileprivate extension Bundle {
    var iconsList: [String] {
        guard let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
              let alternateIcons = icons["CFBundleAlternateIcons"] as? [String: Any]
                else {
            return []
        }
        
        return Array(alternateIcons.keys.sorted())
    }
}

#Preview {
    @Previewable @State var showPicker: Bool = false
    NavigationStack {
        List {
            Button("Change App Icon") {
                showPicker.toggle()
            }
        }
        .navigationTitle("App Icon Picker")
        .appIconPicker(isPresented: $showPicker) {
            Image("AppIcon")
        } alternateIconThumbnail: { iconName in
            Image("\(iconName)")
        } alternateIconTitle: { iconName in
            // Use custom icon title accordingly, if needed.
            Text(iconName)
        }
    }
}

#endif
