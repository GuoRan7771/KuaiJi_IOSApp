//
//  AppReviewManager.swift
//  KuaiJi
//
//  Lightweight helper for the system App Store rating dialog.
//

import Foundation
import StoreKit
import UIKit

enum AppReviewManager {
    private static var appStoreID: String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: "APP_STORE_ID") as? String
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static var writeReviewURL: URL? {
        guard let id = appStoreID else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(id)?action=write-review")
    }

    @MainActor
    static func requestInAppReview() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    @discardableResult
    @MainActor
    static func openWriteReviewPage() -> Bool {
        guard let url = writeReviewURL else { return false }
        UIApplication.shared.open(url)
        return true
    }
}
