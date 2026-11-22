//
//  AppIconPicker.swift
//  Orrery
//
//  Created by Rishi Singh on 21/11/26.
//

#if os(iOS)
import SwiftUI

/// The app icons the picker offers. Each raw value is both the alternate icon name
/// declared in the asset catalog and the name of the matching preview image in
/// `IconPreview`, so adding an icon means adding a case here and nothing else.
enum AppIcon: String, CaseIterable {
    case primary = "Primary"
    case primaryGray = "PrimaryGray"
    case rings = "Rings"
    case ringsGray = "RingsGray"
    case saturn = "Saturn"
    case tics = "Tics"
    case ticsGray = "TicsGray"
    
    /// Name passed to `UIApplication.setAlternateIconName(_:)`. `nil` selects the primary icon.
    var alternateIconName: String? {
        self == .primary ? nil : rawValue
    }
    
    /// Flat image used to preview the icon (app icon assets can't be rendered directly).
    var previewImageName: String { rawValue }
    
    var title: String { rawValue }
    
    /// The icon the app is currently showing.
    static var current: AppIcon {
        guard let name = UIApplication.shared.alternateIconName else { return .primary }
        return allCases.first { $0.rawValue == name } ?? .primary
    }
}

extension View {
    @ContentBuilder
    func appIconPicker(isPresented: Binding<Bool>) -> some View {
        self
            .sheet(isPresented: isPresented) {
                AppIconPicker()
            }
    }
}

struct AppIconPicker: View {
    // View Properties
    @Environment(\.dismiss) private var dismiss
    @State private var activeIcon: AppIcon?
    /// The icon that is active on the device (updated after a successful change).
    @State private var currentIcon: AppIcon
    @State private var isApplying = false
    @State private var scrollOffset: CGFloat = 0
    
    init() {
        let current = AppIcon.current
        _currentIcon = State(initialValue: current)
        _activeIcon = State(initialValue: current)
    }
    
    var body: some View {
        GeometryReader {
            let size = $0.size
            let iconSize = size.height * 0.5
            
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(AppIcon.allCases, id: \.self) { icon in
                        IconView(icon, iconSize: iconSize)
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
    }
    
    // Icon View
    @ContentBuilder
    private func IconView(_ icon: AppIcon, iconSize: CGFloat) -> some View {
        Image(icon.previewImageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
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
        let icons = AppIcon.allCases
        let index = icons.firstIndex(of: activeIcon ?? .primary) ?? 0
        
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
        let icons = AppIcon.allCases
        let scrollProgress = scrollOffset / iconSize
        
        ZStack {
            ForEach(icons.indices, id: \.self) { index in
                let icon = icons[index]
                let progress = scrollProgress - CGFloat(index)
                let cappedProgress = abs(progress)
                
                Text(icon.title)
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
        let isActive = activeIcon == currentIcon
        
        VStack (spacing: 15) {
            Text ("Choose a look for your home screen. You can switch back to any icon at any time.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            Button {
                if let activeIcon { apply(activeIcon) }
            } label: {
                Text(isActive ? "Currently Active" : "Activate App Icon")
                    .contentTransition(.numericText())
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .prominentGlassButtonStyle()
            .disabled(isActive || isApplying)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .padding(.bottom, 10)
            .padding(.top, 5)
        }
        .padding(.horizontal, 15)
    }
    
    /// Asks the system to switch to `icon`. Dismisses on success; on failure the sheet
    /// stays open and a toast explains what happened.
    private func apply(_ icon: AppIcon) {
        guard !isApplying else { return }
        isApplying = true
        Task { @MainActor in
            defer { isApplying = false }
            do {
                guard UIApplication.shared.supportsAlternateIcons else {
                    throw AppIconError.unsupported
                }
                try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
                currentIcon = icon
                dismiss()
            } catch {
                InAppNotificationManager.shared.showToast(
                    title: "Couldn't change the app icon. Please try again.",
                    type: .error
                )
            }
        }
    }
    
    private enum AppIconError: Error {
        case unsupported
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

#Preview {
    @Previewable @State var showPicker: Bool = false
    NavigationStack {
        List {
            Button("Change App Icon") {
                showPicker.toggle()
            }
        }
        .navigationTitle("App Icon Picker")
        .appIconPicker(isPresented: $showPicker)
    }
}

#endif
