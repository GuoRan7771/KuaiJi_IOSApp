//
//  KeyboardDismissInstaller.swift
//  KuaiJi
//

import SwiftUI
import UIKit

// MARK: - 键盘相关扩展

struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        // 使用全局 window 级手势统一处理收起键盘；避免局部手势与子视图交互冲突
        content
    }
}

extension View {
    /// 添加点击空白处隐藏键盘的功能
    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardOnTapModifier())
    }
}

// 全局 Window 级键盘收起安装器（不拦截子视图点击，且仅在点击非输入控件时触发）
final class KeyboardDismissInstaller: NSObject, UIGestureRecognizerDelegate {
    private static var installed = false
    private var tapRecognizers: [UITapGestureRecognizer] = []
    static let shared = KeyboardDismissInstaller()

    static func installIfNeeded() {
        guard !installed else { return }
        installed = true
        shared.install()
    }

    private func install() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                tap.cancelsTouchesInView = false
                tap.delegate = self
                window.addGestureRecognizer(tap)
                tapRecognizers.append(tap)
            }
        }
    }

    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // 仅在点击非输入控件区域时触发，避免点击文本框本身也收起键盘
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view: UIView? = touch.view
        while let v = view {
            if v is UITextField || v is UITextView { return false }
            view = v.superview
        }
        return true
    }
}

// NOTE: This coordinator is not used anymore; tab switching is handled via state inside ContentView.
