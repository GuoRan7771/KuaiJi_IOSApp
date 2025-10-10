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
}
