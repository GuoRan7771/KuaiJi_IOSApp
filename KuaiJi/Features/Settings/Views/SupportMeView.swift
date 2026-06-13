//
//  SupportMeView.swift
//  KuaiJi
//
//  Voluntary support sheet.
//

import SwiftUI

// MARK: - Support Me Page (Sheet)

struct SupportMeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("support.hasSupported") private var hasSupported = false
    @StateObject private var store = StoreKitManager()
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(L.supportTitle.localized)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.appTextPrimary)
                    if hasSupported {
                        Text(L.supportSuccess.localized)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.appSuccess)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 28)

                Text(L.supportDisclaimer.localized)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.appSecondaryText)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                VStack(spacing: 12) {
                    let hasCoffee = store.products.contains { $0.id == "tip.coffee.099" }
                    let hasCake   = store.products.contains { $0.id == "tip.bakery.299" }
                    let hasSushi  = store.products.contains { $0.id == "tip.sushi.999" }

                    TipCard(title: L.supportCoffee.localized,
                            emoji: "☕️",
                            price: store.displayPrice(for: "tip.coffee.099", fallback: "$0.99"),
                            color: .appTextPrimary,
                            action: {
                                Task { await store.buy("tip.coffee.099") }
                            },
                            isEnabled: hasCoffee)
                    TipCard(title: L.supportCheesecake.localized,
                            emoji: "🍰",
                            price: store.displayPrice(for: "tip.bakery.299", fallback: "$2.99"),
                            color: .appTextPrimary,
                            action: {
                                Task { await store.buy("tip.bakery.299") }
                            },
                            isEnabled: hasCake)
                    TipCard(title: L.supportSushi.localized,
                            emoji: "🍱",
                            price: store.displayPrice(for: "tip.sushi.999", fallback: "$9.99"),
                            color: .appTextPrimary,
                            action: {
                                Task { await store.buy("tip.sushi.999") }
                            },
                            isEnabled: hasSushi)
                    if store.products.isEmpty {
                        Text("Loading prices…")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
                .padding(.horizontal)

                // Move the feature note below the tip options
                Text(L.supportNoFeatureNote.localized)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.appSecondaryText)
                    .padding(.horizontal)
                    .padding(.top, 4)

                Spacer(minLength: 20)
            }
            .padding(.bottom, 24)
        }
        .background(
            Group {
                if colorScheme == .dark {
                    // Deep dark background for readability (#0E0E11)
                    Color.appBackground
                } else {
                    LinearGradient(colors: [Color.appSurfaceAlt, Color.appBackground], startPoint: .top, endPoint: .bottom)
                }
            }
        )
        .ignoresSafeArea()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if store.purchasing { ProgressView().controlSize(.small) }
            }
        }
        .onAppear {
            Task { await store.load(); store.listenForUpdates() }
            appState.isSupportSheetVisible = true
        }
        .task {
            await store.load()
            store.listenForUpdates()
        }
        .onDisappear { appState.isSupportSheetVisible = false }
        .alert(isPresented: Binding(get: { (appState.iapAlertMessage?.isEmpty == false) && appState.isSupportSheetVisible }, set: { _ in appState.iapAlertTitle = nil; appState.iapAlertMessage = nil })) {
            Alert(title: Text(appState.iapAlertTitle ?? L.supportPurchaseTitle.localized), message: Text(appState.iapAlertMessage ?? ""), dismissButton: .default(Text(L.ok.localized)))
        }
    }
}

private struct TipCard: View {
    let title: String
    let emoji: String
    let price: String
    let color: Color
    let action: () -> Void
    var isEnabled: Bool = true

    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pressed = true }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring()) { pressed = false }
            }
        }) {
            HStack(spacing: 16) {
                Text(emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                    Text(price).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(color)
                }
                Spacer()
                Image(systemName: "heart.fill").foregroundStyle(Color.appToggleOn)
            }
            .padding(16)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.appSurface))
            .shadow(color: Color.appCardShadow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}
