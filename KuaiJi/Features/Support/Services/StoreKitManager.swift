//
//  StoreKitManager.swift
//  KuaiJi
//
//  Minimal StoreKit 2 wrapper for tips
//

import Foundation
import Combine
import StoreKit
#if DEBUG && canImport(StoreKitTest)
import StoreKitTest
#endif

@MainActor
final class StoreKitManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasing = false
    @Published var alertTitle: String?
    @Published var alertMessage: String?
    private var handledTransactionIDs = Set<Transaction.ID>()
    
    private let productIds: Set<String> = [
        "tip.coffee.099",
        "tip.bakery.299",
        "tip.sushi.999"
    ]
    
    #if DEBUG && canImport(StoreKitTest)
    private static var testSession: SKTestSession?
    private func attachLocalTestSessionIfAvailable() {
        guard Self.testSession == nil else { return }
        if let url = Bundle.main.url(forResource: "Products", withExtension: "storekit") {
            do {
                let session = try SKTestSession(configurationFileURL: url)
                session.disableDialogs = false
                try? session.resetToDefaultState()
                if UserDefaults.standard.bool(forKey: "iap.failTransactions") {
                    session.failTransactionsEnabled = true
                    session.failureError = .unknown
                }
                Self.testSession = session
                debugLog("[IAP] StoreKitTest session attached from bundle")
            } catch {
                debugLog("[IAP] SKTestSession init error:", error.localizedDescription)
            }
        } else {
            debugLog("[IAP] Products.storekit not found in app bundle; Scheme-based configuration is required for local testing")
        }
    }
    #endif
    
    func load() async {
        do {
            #if DEBUG && canImport(StoreKitTest)
            attachLocalTestSessionIfAvailable()
            #endif
            products = try await Product.products(for: Array(productIds))
            debugLog("[IAP] loaded products:", products.map { $0.id })
        } catch {
            alertTitle = L.supportPurchaseTitle.localized
            alertMessage = "Load products failed: \(error.localizedDescription)"
            AppDelegate.appState?.iapAlertTitle = alertTitle
            AppDelegate.appState?.iapAlertMessage = alertMessage
            debugLog("[IAP] load error:", error.localizedDescription)
        }
    }
    
    func displayPrice(for id: String, fallback: String) -> String {
        if let p = products.first(where: { $0.id == id }) { return p.displayPrice }
        return fallback
    }
    
    func buy(_ id: String) async {
        guard let product = products.first(where: { $0.id == id }) else {
            alertTitle = L.supportPurchaseTitle.localized
            alertMessage = "Product not loaded: \(id)"
            AppDelegate.appState?.iapAlertTitle = alertTitle
            AppDelegate.appState?.iapAlertMessage = alertMessage
            debugLog("[IAP] buy aborted, product not loaded:", id)
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            debugLog("[IAP] start purchase:", product.id)
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx: Transaction = try verify(verification)
                await tx.finish()
                UserDefaults.standard.set(true, forKey: "support.hasSupported")
                alertTitle = L.supportPurchaseTitle.localized
                alertMessage = L.supportPurchaseSuccess.localized
                AppDelegate.appState?.iapAlertTitle = alertTitle
                AppDelegate.appState?.iapAlertMessage = alertMessage
                handledTransactionIDs.insert(tx.id)
                CelebrationManager.shared.trigger()
                debugLog("[IAP] purchase success & finished:", product.id)
            case .userCancelled:
                alertTitle = L.supportPurchaseTitle.localized
                alertMessage = L.supportPurchaseCancelled.localized
                AppDelegate.appState?.iapAlertTitle = alertTitle
                AppDelegate.appState?.iapAlertMessage = alertMessage
                debugLog("[IAP] user cancelled:", product.id)
            case .pending:
                alertTitle = L.supportPurchaseTitle.localized
                alertMessage = L.supportPurchasePending.localized
                AppDelegate.appState?.iapAlertTitle = alertTitle
                AppDelegate.appState?.iapAlertMessage = alertMessage
                debugLog("[IAP] pending:", product.id)
            @unknown default:
                break
            }
        } catch {
            alertTitle = L.supportPurchaseTitle.localized
            alertMessage = L.supportPurchaseFailed.localized
            AppDelegate.appState?.iapAlertTitle = alertTitle
            AppDelegate.appState?.iapAlertMessage = alertMessage
            debugLog("[IAP] purchase error:", error.localizedDescription)
        }
    }
    
    private func verify<T>(_ vr: VerificationResult<T>) throws -> T {
        switch vr {
        case .verified(let safe): return safe
        case .unverified(_, let error): throw error
        }
    }
    
    func listenForUpdates() {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let tx) = update else { continue }
                guard let shouldHandle = await self?.markShouldHandle(tx) else { await tx.finish(); continue }
                if shouldHandle {
                    await self?.showSuccessAndCelebrate()
                }
                await tx.finish()
            }
        }
    }

    @MainActor
    private func markShouldHandle(_ tx: Transaction) -> Bool {
        if handledTransactionIDs.contains(tx.id) { return false }
        handledTransactionIDs.insert(tx.id)
        return true
    }

    @MainActor
    private func showSuccessAndCelebrate() {
        UserDefaults.standard.set(true, forKey: "support.hasSupported")
        alertTitle = L.supportPurchaseTitle.localized
        alertMessage = L.supportPurchaseSuccess.localized
        AppDelegate.appState?.iapAlertTitle = alertTitle
        AppDelegate.appState?.iapAlertMessage = alertMessage
        CelebrationManager.shared.trigger()
    }
}


