//
//  View+AppStyles.swift
//  KuaiJi
//
//  Shared visual style helpers.
//

import SwiftUI
import UIKit

// MARK: - Theme Tokens
/// Centralized theme tokens for cute-minimal milk-cocoa style.
/// Keep all visual constants here so the rest of the app only references tokens,
/// not raw colors. This allows quick swapping to other palettes.
enum AppColors {
    // Palette - Milk Cocoa (warm brown)
    static let brandPrimary = Color("BrandPrimary")

    /// Adaptive page background: light -> #F6F2EE, dark -> #0E0E11
    static var background: Color {
        Color("Background")
    }

    static var surface: Color {
        Color("Surface")
    }
    static let surfaceAlt   = Color("SurfaceAlt")

    /// Primary text color: light -> #3A2B22, dark -> #C9C7C4
    static var textPrimary: Color {
        Color("TextPrimary")
    }

    /// Secondary text color: light -> #9C8F86, dark -> #C9C7C4
    static var secondaryText: Color {
        Color("SecondaryText")
    }

    /// Ledger content primary: light -> #3B291E, dark -> #C9C7C4
    static var ledgerContentText: Color {
        Color("LedgerContentText")
    }

    static let success = Color("Success")
    static let danger  = Color("Danger")
    static let info    = Color("Info")
    static let warning = Color("Warning")

    // Controls
    static let toggleOn  = Color("ToggleOn")
    static let toggleOff = Color("ToggleOff")
    static let selection = Color("Selection")
    static var appCardShadow: Color { AppColors.cardShadowColor }

    // Radii & Shadows
    static let cornerRadiusLarge: CGFloat = 22
    static var cardShadowColor: Color {
        Color("CardShadow")
    }
    static let cardShadowRadius: CGFloat = 10
    static let cardShadowY: CGFloat = 6
}

extension Color {
    static var appSecondaryText: Color { AppColors.secondaryText }
    static var appBackground: Color { AppColors.background }
    static var appSurface: Color { AppColors.surface }
    static var appSurfaceAlt: Color { AppColors.surfaceAlt }
    static var appBrand: Color { AppColors.brandPrimary }
    static var appTextPrimary: Color { AppColors.textPrimary }
    static var appLedgerContentText: Color { AppColors.ledgerContentText }
    static var appSuccess: Color { AppColors.success }
    static var appDanger: Color { AppColors.danger }
    static var appInfo: Color { AppColors.info }
    static var appWarning: Color { AppColors.warning }
    static var appToggleOn: Color { AppColors.toggleOn }
    static var appToggleOff: Color { AppColors.toggleOff }
    static var appSelection: Color { AppColors.selection }
    static var appCardShadow: Color { AppColors.cardShadowColor }
}

private struct SecondaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(AppColors.secondaryText)
    }
}

extension View {
    /// Applies the unified light gray text style across the app.
    func appSecondaryTextStyle() -> some View {
        modifier(SecondaryTextStyle())
    }

    /// Applies a rounded, soft card container used across the app.
    func appCardStyle() -> some View {
        background(
            RoundedRectangle(cornerRadius: AppColors.cornerRadiusLarge, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: AppColors.cardShadowColor,
                        radius: AppColors.cardShadowRadius,
                        x: 0,
                        y: AppColors.cardShadowY)
        )
    }

    /// A muted caption style for secondary metadata.
    func appMutedCaption() -> some View {
        font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(Color.appSecondaryText)
    }

    /// A full-width subtle separator that spans the readable width in forms.
    func fullWidthSeparator(color: Color = Color.secondary.opacity(0.2)) -> some View {
        Rectangle()
            .fill(color)
            .frame(height: 1 / UIScreen.main.scale)
            .listRowInsets(EdgeInsets())
    }

    /// Fixes the list row separator leading alignment on iOS 16+.
    @ViewBuilder
    func appListRowSeparatorLeading() -> some View {
        if #available(iOS 16.0, *) {
            alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        } else {
            self
        }
    }
}

struct FullWidthSeparator: View {
    var color: Color = Color.secondary.opacity(0.2)
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 1 / UIScreen.main.scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Remove default list row insets to span the full card width
            .listRowInsets(EdgeInsets())
    }
}
