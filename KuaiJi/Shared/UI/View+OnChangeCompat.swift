//
//  View+OnChangeCompat.swift
//  KuaiJi
//

import SwiftUI

// iOS 18 项目，直接使用现代 onChange API
extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping () -> Void) -> some View {
        // iOS 17+ onChange API with oldValue and newValue parameters
        onChange(of: value, initial: false) { _, _ in action() }
    }
}

// MARK: - Main ContentView & Navigation
