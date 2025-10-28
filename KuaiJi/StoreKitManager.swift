//
//  StoreKitManager.swift
//  KuaiJi
//
//  Minimal StoreKit 2 wrapper for tips
//

import Foundation
import Combine
import StoreKit

@MainActor
final class StoreKitManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasing = false
    @Published var lastMessage: String?
    
    private let productIds: Set<String> = [
        "tip.coffee.099",
        "tip.bakery.299",
        "tip.sushi.999"
    ]
    
    func load() async {
        do {
            products = try await Product.products(for: Array(productIds))
        } catch {
            lastMessage = "Load products failed: \(error.localizedDescription)"
        }
    }
    
    func displayPrice(for id: String, fallback: String) -> String {
        if let p = products.first(where: { $0.id == id }) { return p.displayPrice }
        return fallback
    }
    
    func buy(_ id: String) async {
        guard let product = products.first(where: { $0.id == id }) else { return }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx: Transaction = try verify(verification)
                await tx.finish()
                UserDefaults.standard.set(true, forKey: "support.hasSupported")
                lastMessage = "success"
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastMessage = error.localizedDescription
        }
    }
    
    private func verify<T>(_ vr: VerificationResult<T>) throws -> T {
        switch vr {
        case .verified(let safe): return safe
        case .unverified(_, let error): throw error ?? NSError(domain: "IAP", code: -1)
        }
    }
    
    func listenForUpdates() {
        Task.detached { [weak self] in
            guard let self else { return }
            for await update in Transaction.updates {
                if case .verified(let tx) = update { await tx.finish() }
            }
        }
    }
}


