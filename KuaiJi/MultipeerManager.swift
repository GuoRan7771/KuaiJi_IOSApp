//
//  MultipeerManager.swift
//  KuaiJi
//
//  蓝牙/近场数据共享管理器
//

import Foundation
import MultipeerConnectivity
import SwiftUI
import Combine
import UIKit

enum SyncStatus: Equatable {
    case idle
    case discovering
    case connecting
    case syncing(progress: Double)
    case completed
    case error(String)
}

@MainActor
final class MultipeerManager: NSObject, ObservableObject {
    @Published var availablePeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncTime: Date?
    
    private var peerID: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    private let serviceType = "kuaiji-sync"
    
    var onDataReceived: ((Data, MCPeerID) -> Void)?
    
    var currentDeviceName: String {
        Self.getDeviceName()
    }
    
    // 获取真实的设备名称（静态方法）
    private static func getDeviceName() -> String {
        var deviceName = ""
        
        // 方法1: 尝试从 ProcessInfo 获取（iOS 16+）
        if #available(iOS 16.0, *) {
            let hostName = ProcessInfo.processInfo.hostName
            if !hostName.isEmpty && hostName != "localhost" {
                deviceName = hostName
            }
        }
        
        // 方法2: 使用 UIDevice.current.name
        if deviceName.isEmpty {
            deviceName = UIDevice.current.name
        }
        
        // 清理设备名称：去除 .local 后缀
        if deviceName.hasSuffix(".local") {
            deviceName = String(deviceName.dropLast(6))
        }
        
        return deviceName
    }
    
    override init() {
        let deviceName = Self.getDeviceName()
        self.peerID = MCPeerID(displayName: deviceName)
        self.session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        
        super.init()
        
        self.session.delegate = self
    }
    
    // MARK: - 广播和发现
    
    func startAdvertising() {
        guard advertiser == nil else { return }
        
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        isAdvertising = true
        syncStatus = .discovering
    }
    
    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        isAdvertising = false
    }
    
    func startBrowsing() {
        guard browser == nil else { return }
        
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        isBrowsing = true
        syncStatus = .discovering
    }
    
    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        isBrowsing = false
        availablePeers.removeAll()
    }
    
    // MARK: - 连接管理
    
    func invitePeer(_ peer: MCPeerID) {
        guard let browser = browser else { return }
        syncStatus = .connecting
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    func disconnectPeer(_ peer: MCPeerID) {
        session.cancelConnectPeer(peer)
        connectedPeers.removeAll { $0 == peer }
    }
    
    func disconnectAll() {
        session.disconnect()
        connectedPeers.removeAll()
        stopAdvertising()
        stopBrowsing()
        syncStatus = .idle
    }
    
    // MARK: - 数据发送
    
    func sendData(_ data: Data, to peers: [MCPeerID]) throws {
        guard !peers.isEmpty else { return }
        
        let actuallyConnected = peers.filter { peer in
            session.connectedPeers.contains(peer)
        }
        
        guard !actuallyConnected.isEmpty else {
            throw NSError(domain: "MultipeerManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No connected peers"])
        }
        
        try session.send(data, toPeers: actuallyConnected, with: .reliable)
    }
    
    func sendDataToAll(_ data: Data) throws {
        guard !connectedPeers.isEmpty else {
            throw NSError(domain: "MultipeerManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No connected peers"])
        }
        
        let actuallyConnected = session.connectedPeers
        
        guard !actuallyConnected.isEmpty else {
            throw NSError(domain: "MultipeerManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No peers in connected state"])
        }
        
        try session.send(data, toPeers: actuallyConnected, with: .reliable)
    }
}

// MARK: - MCSessionDelegate

extension MultipeerManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                if !connectedPeers.contains(peerID) {
                    connectedPeers.append(peerID)
                }
                connectedPeers = session.connectedPeers
                syncStatus = .idle
                
            case .connecting:
                syncStatus = .connecting
                
            case .notConnected:
                connectedPeers.removeAll { $0 == peerID }
                connectedPeers = session.connectedPeers
                if connectedPeers.isEmpty {
                    syncStatus = .idle
                }
                
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            onDataReceived?(data, peerID)
        }
    }
    
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // 不使用流
    }
    
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // 不使用资源传输
    }
    
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // 不使用资源传输
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // 自动接受邀请
        Task { @MainActor in
            invitationHandler(true, self.session)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        Task { @MainActor in
            if !availablePeers.contains(where: { $0.displayName == peerID.displayName }) {
                availablePeers.append(peerID)
            }
        }
    }
    
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            availablePeers.removeAll { $0.displayName == peerID.displayName }
        }
    }
}

