//
//  QRCodeHelper.swift
//  KuaiJi
//
//  二维码生成和扫描相关功能
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import AVFoundation

// MARK: - 用户信息数据模型（用于二维码）

struct UserQRCodeData: Codable {
    var userId: String  // 唯一用户ID，用于防止重复添加
    var name: String
    var emoji: String
    var currency: String
    
    func toJSONString() -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    static func fromJSONString(_ string: String) -> UserQRCodeData? {
        guard let data = string.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(UserQRCodeData.self, from: data)
    }
}

// MARK: - 二维码生成器

struct QRCodeGenerator {
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    func generate(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        
        filter.message = data
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // 放大二维码以提高清晰度
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - 显示二维码的视图

struct MyQRCodeView: View {
    let userData: UserQRCodeData
    @Environment(\.dismiss) private var dismiss
    @State private var qrCodeImage: UIImage?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                // 用户信息展示
                VStack(spacing: 16) {
                    Text(userData.emoji)
                        .font(.system(size: 80))
                    
                    Text(userData.name)
                        .font(.title.bold())
                    
                    Text(L.profileCurrencyLabel.localized(userData.currency))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                
                // 二维码
                if let image = qrCodeImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10)
                } else {
                    ProgressView()
                        .frame(width: 250, height: 250)
                }
                
                Text(L.qrcodeScanInstruction.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                
                Spacer()
                Spacer()
            }
            .padding()
            .navigationTitle(L.qrcodeMyTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close.localized) { dismiss() }
                }
            }
            .onAppear {
                generateQRCode()
            }
        }
    }
    
    private func generateQRCode() {
        guard let jsonString = userData.toJSONString() else { return }
        let generator = QRCodeGenerator()
        qrCodeImage = generator.generate(from: jsonString)
    }
}

// MARK: - 二维码扫描器视图

struct QRCodeScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onScanSuccess: (UserQRCodeData) -> Void
    
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasScanned = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                QRCodeScannerRepresentable(
                    onScanSuccess: { code in
                        guard !hasScanned else { return }
                        hasScanned = true
                        handleScannedCode(code)
                    },
                    onError: { error in
                        errorMessage = error
                        showingError = true
                    }
                )
                .edgesIgnoringSafeArea(.all)
                
                // 扫描框
                VStack {
                    Spacer()
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 250, height: 250)
                    
                    Text(L.qrcodeScannerInstruction.localized)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding()
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.6))
                        )
                        .padding(.top, 20)
                    
                    Spacer()
                }
            }
            .navigationTitle(L.qrcodeScannerTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                }
            }
            .alert(L.qrcodeScanError.localized, isPresented: $showingError) {
                Button(L.ok.localized, role: .cancel) {
                    hasScanned = false
                }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func handleScannedCode(_ code: String) {
        guard let userData = UserQRCodeData.fromJSONString(code) else {
            errorMessage = L.qrcodeInvalidFormat.localized
            showingError = true
            return
        }
        
        onScanSuccess(userData)
        dismiss()
    }
}

// MARK: - UIKit 二维码扫描器封装

struct QRCodeScannerRepresentable: UIViewControllerRepresentable {
    let onScanSuccess: (String) -> Void
    let onError: (String) -> Void
    
    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let scanner = QRCodeScannerViewController()
        scanner.onScanSuccess = onScanSuccess
        scanner.onError = onError
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {}
}

class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onScanSuccess: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captureSession?.isRunning == false {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession?.isRunning == true {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.stopRunning()
            }
        }
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            onError?(L.qrcodeCameraError.localized)
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            onError?(L.qrcodeCameraInitError.localized)
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            onError?(L.qrcodeCameraInputError.localized)
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            onError?(L.qrcodeMetadataOutputError.localized)
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onScanSuccess?(stringValue)
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession?.stopRunning()
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }
}

