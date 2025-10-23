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
    static let brandPrimary = Color(red: 122/255, green: 74/255, blue: 42/255)        // #7A4A2A

    /// Adaptive page background: light -> #F6F2EE, dark -> #0E0E11
    static var background: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 14/255, green: 14/255, blue: 17/255, alpha: 1.0) // #0E0E11
            } else {
                return UIColor(red: 246/255, green: 242/255, blue: 238/255, alpha: 1.0) // #F6F2EE
            }
        })
    }

    static var surface: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 24/255, green: 24/255, blue: 27/255, alpha: 1.0)
            } else {
                return UIColor.white
            }
        })
    }
    static let surfaceAlt   = Color(red: 251/255, green: 248/255, blue: 244/255)      // #FBF8F4

    /// Primary text color: light -> #3A2B22, dark -> #C9C7C4
    static var textPrimary: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 201/255, green: 199/255, blue: 196/255, alpha: 1.0) // #C9C7C4
            } else {
                return UIColor(red: 58/255, green: 43/255, blue: 34/255, alpha: 1.0) // #3A2B22
            }
        })
    }

    /// Secondary text color: light -> #9C8F86, dark -> #C9C7C4
    static var secondaryText: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 201/255, green: 199/255, blue: 196/255, alpha: 1.0) // #C9C7C4
            } else {
                return UIColor(red: 156/255, green: 143/255, blue: 134/255, alpha: 1.0) // #9C8F86
            }
        })
    }

    /// Ledger content primary: light -> #3B291E, dark -> #C9C7C4
    static var ledgerContentText: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 201/255, green: 199/255, blue: 196/255, alpha: 1.0) // #C9C7C4
            } else {
                return UIColor(red: 59/255, green: 41/255, blue: 30/255, alpha: 1.0) // #3B291E
            }
        })
    }

    static let success = Color(red: 59/255, green: 175/255, blue: 106/255)
    static let danger  = Color(red: 229/255, green: 106/255, blue: 94/255)
    static let info    = Color(red: 122/255, green: 147/255, blue: 224/255)
    static let warning = Color.orange

    // Controls
    static let toggleOn  = Color(red: 245/255, green: 151/255, blue: 60/255)   // #F5973C
    static let toggleOff = Color(red: 225/255, green: 217/255, blue: 211/255)  // #E1D9D3

    // Radii & Shadows
    static let cornerRadiusLarge: CGFloat = 22
    static var cardShadowColor: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 1.0, alpha: 0.06)
            } else {
                return UIColor(white: 0.0, alpha: 0.06)
            }
        })
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
