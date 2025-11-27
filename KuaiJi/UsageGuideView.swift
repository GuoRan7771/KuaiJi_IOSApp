//
//  UsageGuideView.swift
//  KuaiJi
//
//  App usage instructions with scenario switching and adaptive styling.
//

import SwiftUI

struct UsageGuideView: View {
    enum FlowScenario: CaseIterable, Identifiable {
        case oneToOne
        case oneRecorder
        case everyoneViews
        case personalPlusShared

        var id: String { title }
        var title: String {
            switch self {
            case .oneToOne: return L.personalUsageFlow1.localized
            case .oneRecorder: return L.personalUsageFlow2.localized
            case .everyoneViews: return L.personalUsageFlow3.localized
            case .personalPlusShared: return L.personalUsageFlow4.localized
            }
        }

        var steps: [String] {
            switch self {
            case .oneToOne:
                return [
                    "完成基础设置：昵称、头像、常用币种，并在设置开启“共享账本”。",
                    "互加好友：共享账本页面点同步连接，或在朋友页扫码互加。",
                    "新建账本并添加双方成员。",
                    "规则：谁付谁记；同一消费只记一次。",
                    "如有错误账目，双方设备都删除后重记。",
                    "活动/一天结束，再次同步保持一致。"
                ]
            case .oneRecorder:
                return [
                    "记账人手动添加参与者（只保存在本机）。",
                    "在共享账本新建活动账本。",
                    "活动中所有付款都由记账人记录一遍。",
                    "结束后在账本查看应收应付，口头或截图发送。"
                ]
            case .everyoneViews:
                return [
                    "所有人完成基础设置并开启共享账本。",
                    "互加好友（同步或二维码）。",
                    "新建共享账本并添加所有成员。",
                    "约定记账方式：谁付谁记，或指定一人记；同一消费只记一次。",
                    "阶段性同步：共享账本页面点同步，两两或逐个与管理员同步。"
                ]
            case .personalPlusShared:
                return [
                    "设置里同时打开个人账本和共享账本。",
                    "在个人账本添加资产（银行卡/现金等）。",
                    "日常支出先记到个人账本。",
                    "需要 AA 的支出，使用“同步到共享账本”并选择目标账本。"
                ]
            }
        }
    }

    @State private var selectedScenario: FlowScenario = .oneToOne

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                flowsSection
                philosophySection
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle(L.settingsUsageGuide.localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var flowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.personalUsageFlowsTitle.localized)
                .font(.headline)
                .foregroundStyle(Color.appLedgerContentText)
            Text(L.personalUsageFlowSummary.localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            flowSelector
            guideCard(title: selectedScenario.title, subtitle: L.personalUsageFlowsTitle.localized, bullets: steps(for: selectedScenario))
        }
    }

    private var philosophySection: some View {
        let items = [
            L.personalUsageDesign1.localized,
            L.personalUsageDesign2.localized,
            L.personalUsageDesign3.localized,
            L.personalUsageDesign4.localized,
            L.personalUsageDesign5.localized
        ]
        return guideCard(title: L.personalUsageDesignTitle.localized,
                         subtitle: L.personalUsagePhilosophy.localized,
                         bullets: items)
    }

    private var flowSelector: some View {
        VStack(spacing: 10) {
            ForEach(FlowScenario.allCases) { scenario in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedScenario = scenario
                    }
                } label: {
                    HStack {
                        Text(scenario.title)
                            .font(.footnote.weight(.semibold))
                        Spacer()
                        if selectedScenario == scenario {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.appSelection)
                        }
                    }
                    .padding()
                    .background(capsuleBackground(isSelected: selectedScenario == scenario))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func steps(for scenario: FlowScenario) -> [String] {
        switch scenario {
        case .oneToOne:
            return [
                L.personalUsageFlow1Step1.localized,
                L.personalUsageFlow1Step2.localized,
                L.personalUsageFlow1Step3.localized,
                L.personalUsageFlow1Step4.localized,
                L.personalUsageFlow1Step5.localized,
                L.personalUsageFlow1Step6.localized
            ]
        case .oneRecorder:
            return [
                L.personalUsageFlow2Step1.localized,
                L.personalUsageFlow2Step2.localized,
                L.personalUsageFlow2Step3.localized,
                L.personalUsageFlow2Step4.localized
            ]
        case .everyoneViews:
            return [
                L.personalUsageFlow3Step1.localized,
                L.personalUsageFlow3Step2.localized,
                L.personalUsageFlow3Step3.localized,
                L.personalUsageFlow3Step4.localized,
                L.personalUsageFlow3Step5.localized
            ]
        case .personalPlusShared:
            return [
                L.personalUsageFlow4Step1.localized,
                L.personalUsageFlow4Step2.localized,
                L.personalUsageFlow4Step3.localized,
                L.personalUsageFlow4Step4.localized
            ]
        }
    }

    @ViewBuilder
    private func guideCard(title: String, subtitle: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.appLedgerContentText)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.appSelection)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    Text(bullet)
                        .font(.body)
                        .foregroundStyle(Color.appLedgerContentText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding()
        .background(glassSurface())
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func capsuleBackground(isSelected: Bool) -> some View {
        if #available(iOS 26.0, *) {
            Capsule(style: .continuous)
                .fill(.thinMaterial)
                .overlay(Capsule().stroke(isSelected ? Color.appSelection : Color.appSurfaceAlt, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
        } else {
            Capsule(style: .continuous)
                .fill(
                    isSelected
                    ? AnyShapeStyle(LinearGradient(colors: [Color.appSelection.opacity(0.2), Color.appSelection.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Color.appSurfaceAlt)
                )
        }
    }

    @ViewBuilder
    private func glassSurface() -> some View {
        if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(colors: [
                        Color.appSurfaceAlt.opacity(0.9),
                        Color.appSurfaceAlt.opacity(0.7)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)
        }
    }
}
