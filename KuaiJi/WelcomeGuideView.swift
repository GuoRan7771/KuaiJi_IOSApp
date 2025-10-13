//
//  WelcomeGuideView.swift
//  KuaiJi
//
//  欢迎引导动画页面
//

import SwiftUI

// MARK: - 引导页数据
struct GuidePageData: Identifiable {
    let id: Int
    let emoji: String
    let title: String
    let description: String
    let accentColor: Color
    let animationType: AnimationType
    
    enum AnimationType {
        case pulse       // 脉动
        case rotate      // 旋转
        case bounce      // 弹跳
        case wave        // 波浪
        case shimmer     // 闪烁
    }
    
    static let pages: [GuidePageData] = [
        GuidePageData(
            id: 0,
            emoji: "👋",
            title: L.guideWelcomeTitle.localized,
            description: L.guideWelcomeDesc.localized,
            accentColor: .blue,
            animationType: .wave
        ),
        GuidePageData(
            id: 1,
            emoji: "👥",
            title: L.guideFriendsTitle.localized,
            description: L.guideFriendsDesc.localized + "\n" + L.guideFriendsSyncTip.localized,
            accentColor: .orange,
            animationType: .pulse
        ),
        GuidePageData(
            id: 2,
            emoji: "📖",
            title: L.guideLedgerTitle.localized,
            description: L.guideLedgerDesc.localized,
            accentColor: .green,
            animationType: .bounce
        ),
        GuidePageData(
            id: 3,
            emoji: "📡",
            title: L.guideSyncTitle.localized,
            description: L.guideSyncDesc.localized,
            accentColor: .purple,
            animationType: .rotate
        ),
        GuidePageData(
            id: 4,
            emoji: "🔒",
            title: L.guidePrivacyTitle.localized,
            description: L.guidePrivacyDesc.localized,
            accentColor: .pink,
            animationType: .shimmer
        ),
        // 新增：个人账本介绍
        GuidePageData(
            id: 5,
            emoji: "🧾",
            title: L.guidePersonalIntroTitle.localized,
            description: L.guidePersonalIntroDesc.localized,
            accentColor: .teal,
            animationType: .bounce
        ),
        // 新增：与共享账本独立
        GuidePageData(
            id: 6,
            emoji: "🧩",
            title: L.guideIndependenceTitle.localized,
            description: L.guideIndependenceDesc.localized,
            accentColor: .indigo,
            animationType: .wave
        )
    ]
}

// MARK: - 欢迎引导主视图
struct WelcomeGuideView: View {
    @State private var currentPage = 0
    @State private var showingGuide = true
    @State private var progress: CGFloat = 0
    @State private var isAnimating = false
    var onComplete: () -> Void
    
    private let pages = GuidePageData.pages
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [
                    pages[currentPage].accentColor.opacity(0.2),
                    pages[currentPage].accentColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.6), value: currentPage)
            
            VStack(spacing: 0) {
                // 跳过按钮
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            onComplete()
                        }
                    } label: {
                        Text(L.guideSkip.localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                            )
                    }
                }
                .padding()
                
                Spacer()
                
                // 页面内容
                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        GuidePageView(page: page, isActive: currentPage == page.id)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 500)
                
                Spacer()
                
                // 自定义页面指示器和按钮
                VStack(spacing: 30) {
                    // 页面指示器
                    HStack(spacing: 12) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? pages[currentPage].accentColor : Color.gray.opacity(0.3))
                                .frame(width: currentPage == index ? 12 : 8, height: currentPage == index ? 12 : 8)
                                .scaleEffect(currentPage == index ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                        }
                    }
                    
                    // 操作按钮
                    HStack(spacing: 20) {
                        // 上一页按钮
                        if currentPage > 0 {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentPage -= 1
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(L.guidePrevious.localized)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(pages[currentPage].accentColor)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(pages[currentPage].accentColor.opacity(0.15))
                                )
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        Spacer()
                        
                        // 下一页/开始按钮
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if currentPage < pages.count - 1 {
                                    currentPage += 1
                                } else {
                                    onComplete()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(currentPage < pages.count - 1 ? L.guideNext.localized : L.guideStart.localized)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                Image(systemName: currentPage < pages.count - 1 ? "chevron.right" : "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                pages[currentPage].accentColor,
                                                pages[currentPage].accentColor.opacity(0.8)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: pages[currentPage].accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                            )
                        }
                        .scaleEffect(isAnimating ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimating)
                    }
                    .padding(.horizontal, 32)
                }
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - 单个引导页面
struct GuidePageView: View {
    let page: GuidePageData
    let isActive: Bool
    
    @State private var emojiScale: CGFloat = 0.5
    @State private var textOpacity: Double = 0
    @State private var slideOffset: CGFloat = 50
    @State private var animationProgress: CGFloat = 0
    @State private var rotationAngle: Double = 0
    @State private var bounceOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 32) {
            // Emoji 图标容器
            ZStack {
                // 背景光晕效果
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                page.accentColor.opacity(0.3),
                                page.accentColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .scaleEffect(pulseScale)
                    .opacity(isActive ? 1 : 0)
                
                // Emoji 图标
                Text(page.emoji)
                    .font(.system(size: 120))
                    .scaleEffect(emojiScale)
                    .rotationEffect(.degrees(rotationAngle))
                    .offset(y: bounceOffset)
                    .shadow(color: page.accentColor.opacity(0.4), radius: 20, x: 0, y: 10)
            }
            
            VStack(spacing: 20) {
                // 标题
                Text(page.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [page.accentColor, page.accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .multilineTextAlignment(.center)
                    .opacity(textOpacity)
                    .offset(y: slideOffset)
                
                // 描述
                Text(page.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 32)
                    .opacity(textOpacity)
                    .offset(y: slideOffset)
                
                // 特殊视觉元素（根据页面类型）
                if isActive {
                    pageSpecificView
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startEnterAnimation()
                startContinuousAnimation()
            } else {
                stopAnimations()
            }
        }
        .onAppear {
            if isActive {
                startEnterAnimation()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startContinuousAnimation()
                }
            }
        }
    }
    
    // 页面特殊视觉元素
    @ViewBuilder
    private var pageSpecificView: some View {
        switch page.id {
        case 1: // 朋友页面 - 显示二维码图标 + 同步提示
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 40))
                            .foregroundStyle(page.accentColor)
                        Text(L.guideScanQRCode.localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(page.accentColor.opacity(0.1))
                    )
                    
                    Image(systemName: "arrow.right")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(page.accentColor)
                        Text(L.guideBecomeFriends.localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(page.accentColor.opacity(0.1))
                    )
                }
                .padding(.top, 16)
                
                Text(L.guideFriendsSyncTip.localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
        case 2: // 账本页面 - 显示时间轴
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundStyle(page.accentColor)
                    Text(L.guideExampleTrip.localized)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(L.guideSampleAmount1.localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(page.accentColor)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(page.accentColor.opacity(0.1))
                )
                
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundStyle(page.accentColor)
                    Text(L.guideExampleDinner.localized)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(L.guideSampleAmount2.localized)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(page.accentColor)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(page.accentColor.opacity(0.1))
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 16)
            
        case 3: // 同步页面 - 显示设备连接
            HStack(spacing: 0) {
                // 设备 A
                VStack(spacing: 8) {
                    Image(systemName: "iphone")
                        .font(.system(size: 40))
                        .foregroundStyle(page.accentColor)
                    Text(L.guideYourDevice.localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // 连接线
                ZStack {
                    // 虚线
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: 0))
                        path.addLine(to: CGPoint(x: 80, y: 0))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(page.accentColor.opacity(0.5))
                    
                    // 传输图标
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title3)
                        .foregroundStyle(page.accentColor)
                        .background(
                            Circle()
                                .fill(.background)
                                .frame(width: 30, height: 30)
                        )
                }
                .frame(width: 80, height: 40)
                
                // 设备 B
                VStack(spacing: 8) {
                    Image(systemName: "iphone")
                        .font(.system(size: 40))
                        .foregroundStyle(page.accentColor)
                    Text(L.guideFriendDevice.localized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 16)
            
        case 4: // 隐私页面 - 显示安全图标
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(page.accentColor)
                    Text(L.guideLocalStorage.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 36))
                        .foregroundStyle(page.accentColor)
                    Text(L.guideNoServer.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(page.accentColor)
                    Text(L.guideFullyPrivate.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 16)
            
        default:
            EmptyView()
        }
    }
    
    // 进入动画
    private func startEnterAnimation() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            emojiScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            textOpacity = 1.0
            slideOffset = 0
        }
    }
    
    // 持续动画
    private func startContinuousAnimation() {
        switch page.animationType {
        case .pulse:
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
            
        case .rotate:
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            
        case .bounce:
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                bounceOffset = -15
            }
            
        case .wave:
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                emojiScale = 1.1
            }
            
        case .shimmer:
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.2
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                emojiScale = 1.05
            }
        }
    }
    
    // 停止动画
    private func stopAnimations() {
        emojiScale = 0.5
        textOpacity = 0
        slideOffset = 50
        pulseScale = 1.0
        rotationAngle = 0
        bounceOffset = 0
    }
}

// MARK: - 预览
#Preview {
    WelcomeGuideView {
        // Guide completed
    }
}
