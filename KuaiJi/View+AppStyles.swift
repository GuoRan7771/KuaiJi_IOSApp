//
//  View+AppStyles.swift
//  KuaiJi
//
//  Shared visual style helpers.
//

import SwiftUI

enum AppColors {
    static let secondaryText = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
}

extension Color {
    static let appSecondaryText = AppColors.secondaryText
}

private struct SecondaryTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13))
            .foregroundStyle(AppColors.secondaryText)
    }
}

extension View {
    /// Applies the unified light gray text style across the app.
    func appSecondaryTextStyle() -> some View {
        modifier(SecondaryTextStyle())
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
