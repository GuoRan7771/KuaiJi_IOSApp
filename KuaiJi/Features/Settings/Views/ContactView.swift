//
//  ContactView.swift
//  KuaiJi
//
//  Contact and animated contact background views.
//

import SwiftUI
import UIKit
import Darwin

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var activeCard: ContactCardKind?
    
    var body: some View {
        ZStack {
            // Liquid glass background with animated gradient
            AnimatedLiquidBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Apple Logo with dynamic rainbow effect
                ZStack {
                    // Multiple animated gradient circles for liquid glass effect
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.0, blue: 0.0),    // Red
                                        Color(red: 1.0, green: 0.6, blue: 0.0),    // Orange
                                        Color(red: 1.0, green: 1.0, blue: 0.0),    // Yellow
                                        Color(red: 0.0, green: 1.0, blue: 0.0),    // Green
                                        Color(red: 0.0, green: 0.6, blue: 1.0),    // Blue
                                        Color(red: 0.4, green: 0.0, blue: 1.0),    // Indigo
                                        Color(red: 0.8, green: 0.0, blue: 1.0),    // Purple
                                        Color(red: 1.0, green: 0.0, blue: 0.0)     // Red
                                    ]),
                                    center: .center,
                                    angle: .degrees(rotationAngle + Double(index * 120))
                                )
                            )
                            .frame(width: 140 + CGFloat(index * 20), height: 140 + CGFloat(index * 20))
                            .blur(radius: 30 + CGFloat(index * 10))
                                .opacity(0.6 - Double(index) * 0.15)
                                .scaleEffect(pulseScale)
                        }
                        
                        appleMark
                    }
                    .scaleEffect(pulseScale)
                    
                    // Text content with liquid glass effect
                    VStack(spacing: 16) {
                    Text(L.contactAuthor.localized)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .white.opacity(0.5), radius: 8)
                    
                    GeometryReader { proxy in
                        let maxWidth = min(proxy.size.width * 0.88, 380)
                        let cardHeight = max(120, min(170, proxy.size.width * 0.38))
                        let overlap = cardHeight * 0.45
                        let cards = ContactCardKind.allCases
                        let totalHeight = cardHeight + overlap * CGFloat(cards.count - 1)
                        
                        ZStack(alignment: .top) {
                            ForEach(Array(cards.enumerated()), id: \.1) { index, card in
                                Button {
                                    bounceAndPerform(card)
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 10) {
                                            Image(systemName: card.icon)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.95))
                                                .frame(width: 32, height: 32)
                                                .background(Circle().fill(.white.opacity(0.12)))
                                            Text(title(for: card))
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.95))
                                        }
                                        Text(card.subtitle)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 18)
                                    .frame(width: maxWidth, height: cardHeight, alignment: .topLeading)
                                    .background(cardBackground(for: card))
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
                                }
                                .buttonStyle(.plain)
                                .offset(y: CGFloat(index) * overlap)
                                .scaleEffect(activeCard == card ? 1.03 : 1.0)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: activeCard)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: totalHeight, alignment: .top)
                    }
                    .frame(height: max(260, UIScreen.main.bounds.width * 0.6))
                }
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }

    private func bounceAndPerform(_ card: ContactCardKind) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            activeCard = card
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            perform(card)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    activeCard = nil
                }
            }
        }
    }

    private func title(for card: ContactCardKind) -> String {
        switch card {
        case .email: return L.contactEmail.localized
        case .rednote: return L.contactRednote.localized
        case .github: return L.contactGithub.localized
        }
    }

    private func perform(_ card: ContactCardKind) {
        switch card {
        case .email:
            let email = "rangertars777@gmail.com"
            let subject = "KuaiJi Feedback"
            let info = Bundle.main.infoDictionary
            let appVersion = (info?["CFBundleShortVersionString"] as? String) ?? ""
            let appBuild = (info?["CFBundleVersion"] as? String) ?? ""
            let osVersion = UIDevice.current.systemVersion
            let osBuild = ContactView.fetchOSBuildVersion() ?? ""
            let language = Locale.current.identifier
            let device = ContactView.marketingDeviceName()

            let lines: [String] = [
                "Device: \(device)",
                "iOS: \(osVersion)\(osBuild.isEmpty ? "" : " (\(osBuild))")",
                "App: \(appVersion) (\(appBuild))",
                "Language: \(language)",
                "",
                "",
                "Please write your suggestions below (you can add screenshots):",
                "",
                ""
            ]
            let body = lines.joined(separator: "\r\n")

            var components = URLComponents()
            components.scheme = "mailto"
            components.path = email
            components.queryItems = [
                URLQueryItem(name: "subject", value: subject),
                URLQueryItem(name: "body", value: body)
            ]
            if let url = components.url {
                openURL(url)
            }
        case .rednote:
            if let url = URL(string: "https://www.xiaohongshu.com/user/profile/5b815f2d47bf040001a99d94?xsec_token=YBZpK0YrWREW6VWRFKrUhGlh_jMjVWqu6nVjX2p9iNlIo=&xsec_source=app_share&xhsshare=CopyLink&shareRedId=N0g6MThLNk06PkdIOTwwNjY0SkA9ST89&apptime=1764280587&share_id=b2892ebc9b194468947fa9ba0efc65ba") {
                UIApplication.shared.open(url)
            }
        case .github:
            if let url = URL(string: "https://github.com/GuoRan7771/KuaiJi_IOSApp") {
                openURL(url)
            }
        }
    }

    @ViewBuilder
    private func cardBackground(for card: ContactCardKind) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(colors: card.colors,
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            )
            .opacity(0.9)
    }
}

private extension ContactView {
    enum ContactCardKind: CaseIterable {
        case email
        case rednote
        case github

        var icon: String {
            switch self {
            case .email: return "envelope.fill"
            case .rednote: return "globe.asia.australia.fill"
            case .github: return "chevron.left.forwardslash.chevron.right"
            }
        }

        var subtitle: String {
            switch self {
            case .email:
                return L.contactEmailSubtitle.localized
            case .rednote:
                return L.contactRednoteSubtitle.localized
            case .github:
                return L.contactGithubSubtitle.localized
            }
        }

        var colors: [Color] {
            switch self {
            case .email:
                return [Color(red: 0.18, green: 0.35, blue: 0.9), Color(red: 0.08, green: 0.16, blue: 0.46)]
            case .rednote:
                return [Color(red: 0.92, green: 0.26, blue: 0.32), Color(red: 0.62, green: 0.12, blue: 0.18)]
            case .github:
                return [Color(red: 0.1, green: 0.1, blue: 0.1), Color(red: 0.2, green: 0.2, blue: 0.2)]
            }
        }
    }

    static func fetchOSBuildVersion() -> String? {
        var size: size_t = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("kern.osversion", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    static func hardwareIdentifier() -> String {
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.machine", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    static func marketingDeviceName() -> String {
        let id = hardwareIdentifier()
        let map: [String: String] = [
            // iPhone 15 family
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            // iPhone 14 family
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            // iPhone 13 family
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            // iPhone 12 family
            "iPhone13,1": "iPhone 12 mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            // iPhone 11 family
            "iPhone12,1": "iPhone 11",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,5": "iPhone 11 Pro Max",
            // iPhone X / XS / XR / 8
            "iPhone10,3": "iPhone X",
            "iPhone10,6": "iPhone X",
            "iPhone11,2": "iPhone XS",
            "iPhone11,4": "iPhone XS Max",
            "iPhone11,6": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",
            "iPhone10,1": "iPhone 8",
            "iPhone10,4": "iPhone 8",
            "iPhone10,2": "iPhone 8 Plus",
            "iPhone10,5": "iPhone 8 Plus"
        ]
        return map[id] ?? "iPhone (\(id))"
    }
    
    var appleMark: some View {
        Group {
            if UIImage(systemName: "apple.logo") != nil {
                Image(systemName: "apple.logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if let appIcon = UIImage(named: "AppIcon") {
                Image(uiImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .shadow(color: .white.opacity(0.5), radius: 10)
    }
}

struct AnimatedLiquidBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base dark background
            Color.black
            
            // Multiple liquid gradient layers
            ForEach(0..<3) { index in
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                rainbowColor(for: index).opacity(0.3),
                                rainbowColor(for: index).opacity(0.15),
                                .clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 400
                        )
                    )
                    .frame(width: 500, height: 500)
                    .offset(
                        x: animate ? randomOffset(index) : -randomOffset(index),
                        y: animate ? randomOffset(index + 1) : -randomOffset(index + 1)
                    )
                    .blur(radius: 60)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
    
    private func rainbowColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.0, blue: 0.5),    // Pink
            Color(red: 0.0, green: 0.5, blue: 1.0),    // Blue
            Color(red: 0.5, green: 0.0, blue: 1.0)     // Purple
        ]
        return colors[index % colors.count]
    }
    
    private func randomOffset(_ seed: Int) -> CGFloat {
        let offsets: [CGFloat] = [100, -80, 120, -90, 110]
        return offsets[seed % offsets.count]
    }
}
