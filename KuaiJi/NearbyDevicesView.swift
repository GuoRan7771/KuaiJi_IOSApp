//
//  NearbyDevicesView.swift
//  KuaiJi
//
//  附近设备同步界面
//

import SwiftUI
import MultipeerConnectivity

struct NearbyDevicesView: View {
    @StateObject private var multipeerManager = MultipeerManager()
    @ObservedObject var rootViewModel: AppRootViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showSyncWarning = false
    @State private var showSyncResult = false
    @State private var syncResultMessage = ""
    @State private var selectedPeers: Set<MCPeerID> = []
    
    private let suppressWarningKey = "SuppressSyncWarning"
    
    var body: some View {
        List {
            // 当前设备
            Section {
                HStack(spacing: 16) {
                    Image(systemName: deviceIcon(for: multipeerManager.currentDeviceName))
                        .font(.title)
                        .foregroundStyle(.blue)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(Color.blue.opacity(0.1)))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.syncCurrentDevice.localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(multipeerManager.currentDeviceName)
                            .font(.headline)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            
            // 附近的设备
            if multipeerManager.isBrowsing {
                Section {
                    if multipeerManager.availablePeers.isEmpty {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text(L.syncNoDevicesFound.localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(multipeerManager.availablePeers, id: \.self) { peer in
                            peerRow(peer)
                        }
                    }
                } header: {
                    Text(L.syncNearbyDevices.localized)
                }
            }
            
            // 同步按钮（仅在有连接设备时显示）
            if !multipeerManager.connectedPeers.isEmpty {
                Section {
                    Button {
                        handleSyncButtonTap()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(L.syncStartSync.localized)
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
        }
        .navigationTitle(L.syncShareLedger.localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L.syncWarningTitle.localized, isPresented: $showSyncWarning) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.syncWarningConfirm.localized) {
                performSync()
            }
            Button(L.syncWarningConfirmNoRemind.localized) {
                UserDefaults.standard.set(true, forKey: suppressWarningKey)
                performSync()
            }
        } message: {
            Text(L.syncWarningMessage.localized)
        }
        .alert(L.syncResultTitle.localized, isPresented: $showSyncResult) {
            Button(L.ok.localized) {
                dismiss()
            }
        } message: {
            Text(syncResultMessage)
        }
        .onAppear {
            setupSyncHandler()
            // 自动开始搜索设备
            multipeerManager.startAdvertising()
            multipeerManager.startBrowsing()
        }
        .onDisappear {
            multipeerManager.stopBrowsing()
            multipeerManager.stopAdvertising()
            multipeerManager.disconnectAll()
        }
    }
    
    // 处理同步按钮点击
    private func handleSyncButtonTap() {
        // 检查是否已经选择不再提醒
        let suppressWarning = UserDefaults.standard.bool(forKey: suppressWarningKey)
        if suppressWarning {
            performSync()
        } else {
            showSyncWarning = true
        }
    }
    
    // 设备行组件
    @ViewBuilder
    private func peerRow(_ peer: MCPeerID) -> some View {
        let isConnected = multipeerManager.connectedPeers.contains(peer)
        HStack(spacing: 16) {
            Image(systemName: deviceIcon(for: peer.displayName))
                .font(.title2)
                .foregroundStyle(isConnected ? .green : .blue)
                .frame(width: 40, height: 40)
                .background(Circle().fill(isConnected ? Color.green.opacity(0.1) : Color.blue.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(cleanDeviceName(peer.displayName))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if isConnected {
                    Text(L.syncDeviceConnected.localized)
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text(L.syncDeviceAvailable.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
                } else {
                    Button(L.syncConnect.localized) {
                        multipeerManager.invitePeer(peer)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
        }
        .padding(.vertical, 4)
    }
    
    // 清理设备名称（去除.local后缀）
    private func cleanDeviceName(_ name: String) -> String {
        if name.hasSuffix(".local") {
            return String(name.dropLast(6))
        }
        return name
    }
    
    private func deviceIcon(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("ipad") {
            return "ipad"
        } else if lowercased.contains("mac") {
            return "laptopcomputer"
        } else if lowercased.contains("watch") {
            return "applewatch"
        } else if lowercased.contains("mini") {
            return "iphone.gen3"
        } else {
            return "iphone"
        }
    }
    
    private func setupSyncHandler() {
        multipeerManager.onDataReceived = { data, peer in
            handleReceivedData(data, from: peer)
        }
    }
    
    private func performSync() {
        guard let dataManager = rootViewModel.dataManager,
              let currentUser = dataManager.currentUser else {
            syncResultMessage = L.defaultUnknown.localized
            showSyncResult = true
            return
        }
        
        multipeerManager.syncStatus = .syncing(progress: 0.5)
        
        // 准备同步数据
        guard let syncPackage = SyncEngine.prepareSyncData(
            from: dataManager,
            currentUserId: currentUser.userId
        ) else {
            syncResultMessage = L.syncErrorPreparing.localized
            showSyncResult = true
            multipeerManager.syncStatus = .error("Failed to prepare data")
            return
        }
        
        // 编码数据
        guard let data = try? JSONEncoder().encode(syncPackage) else {
            syncResultMessage = L.syncErrorEncoding.localized
            showSyncResult = true
            multipeerManager.syncStatus = .error("Encoding failed")
            return
        }
        
        // 发送给所有连接的设备
        do {
            try multipeerManager.sendDataToAll(data)
            
            // 注意：接收方会自动回传他们的数据
            // handleReceivedData 方法会处理接收到的数据
            
            multipeerManager.syncStatus = .completed
            syncResultMessage = L.syncCompleted.localized + "\n" + L.syncWaitingResponse.localized(multipeerManager.connectedPeers.count)
            // 不立即显示结果，等待接收完成
        } catch {
            syncResultMessage = L.syncSendBackError.localized(error.localizedDescription)
            showSyncResult = true
            multipeerManager.syncStatus = .error("Send failed")
        }
    }
    
    private func handleReceivedData(_ data: Data, from peer: MCPeerID) {
        guard let dataManager = rootViewModel.dataManager,
              let currentUser = dataManager.currentUser else {
            return
        }
        
        // 解码数据
        guard let syncPackage = try? JSONDecoder().decode(SyncPackage.self, from: data) else {
            syncResultMessage = L.syncErrorInvalidData.localized
            showSyncResult = true
            return
        }
        
        // 基于 exchangeId / replyTo 防止 Ping-Pong
        struct ExchangeGuard {
            static var seen = Set<UUID>()
        }
        // 若我们已经处理过该交换ID，则忽略
        if ExchangeGuard.seen.contains(syncPackage.exchangeId) {
            return
        }
        ExchangeGuard.seen.insert(syncPackage.exchangeId)
        
        // 合并数据
        let result = SyncEngine.mergeSyncData(
            syncPackage,
            into: dataManager,
            currentUserId: currentUser.userId
        )
        
        // 刷新视图
        rootViewModel.loadFromPersistence()
        
        // 自动回传本地数据（实现双向同步）。若这是对方的回复（replyTo 非空），则不再回传，避免循环。
        if syncPackage.replyTo == nil, var myData = SyncEngine.prepareSyncData(from: dataManager, currentUserId: currentUser.userId) {
            // 设置回复链路，避免对方再次回传
            myData.replyTo = syncPackage.exchangeId
            guard let encodedData = try? JSONEncoder().encode(myData) else {
                syncResultMessage = L.syncErrorEncoding.localized
                showSyncResult = true
                return
            }
            do {
                try multipeerManager.sendData(encodedData, to: [peer])
                
                // 显示完整的双向同步结果
                syncResultMessage = L.syncBidirectionalComplete.localized + "\n\n" +
                    L.syncReceivedFrom.localized(syncPackage.senderName) + "\n" +
                    result.summary + "\n\n" +
                    L.syncSentBack.localized
                showSyncResult = true
                multipeerManager.syncStatus = .completed
            } catch {
                // 即使回传失败，也显示接收结果
                syncResultMessage = L.syncReceivedFrom.localized(syncPackage.senderName) + "\n" +
                    result.summary + "\n\n" +
                    L.syncSendBackError.localized(error.localizedDescription)
                showSyncResult = true
            }
        } else {
            // 显示接收结果
            syncResultMessage = L.syncReceivedFrom.localized(syncPackage.senderName) + "\n" +
                result.summary
            showSyncResult = true
        }
    }
}

struct NearbyDevicesHost: View {
    @ObservedObject var rootViewModel: AppRootViewModel
    
    var body: some View {
        NavigationStack {
            NearbyDevicesView(rootViewModel: rootViewModel)
        }
    }
}

