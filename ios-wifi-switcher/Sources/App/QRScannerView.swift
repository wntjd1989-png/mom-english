import AVFoundation
import SwiftUI
import UIKit

/// 공유기 라벨에 붙은 Wi-Fi QR 코드를 읽는 시트.
struct QRScannerSheet: View {

    /// 읽기에 성공하면 결과를, 취소하면 `nil` 을 넘깁니다.
    let onFinish: (WiFiQRParser.Result?) -> Void

    @State private var status: Status = .scanning
    @State private var cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)

    private enum Status: Equatable {
        case scanning
        /// Wi-Fi QR 이 아닌 코드를 읽은 경우
        case unsupported(String)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                switch cameraAuthorization {
                case .authorized:
                    scanner
                case .notDetermined:
                    requestView
                default:
                    deniedView
                }
            }
            .navigationTitle("QR 코드 스캔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { onFinish(nil) }
                }
            }
        }
    }

    private var scanner: some View {
        ZStack {
            QRCameraView { payload in
                guard let parsed = WiFiQRParser.parse(payload) else {
                    // Wi-Fi QR 이 아니면 계속 스캔합니다.
                    status = .unsupported(payload)
                    return false
                }
                onFinish(parsed)
                return true
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                VStack(spacing: 6) {
                    if case .unsupported = status {
                        Text("Wi-Fi QR 코드가 아닙니다")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Text("공유기 뒷면이나 안내문의 Wi-Fi QR 코드를 비춰 주세요.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private var requestView: some View {
        PermissionPrompt(
            icon: "camera",
            title: "카메라 권한이 필요합니다",
            message: "QR 코드를 읽기 위해서만 사용하며, 사진은 저장하지 않습니다.",
            actionTitle: "카메라 사용 허용"
        ) {
            AVCaptureDevice.requestAccess(for: .video) { _ in
                Task { @MainActor in
                    cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
                }
            }
        }
    }

    private var deniedView: some View {
        PermissionPrompt(
            icon: "camera.badge.ellipsis",
            title: "카메라가 꺼져 있습니다",
            message: "설정에서 카메라 접근을 허용하거나, 네트워크를 직접 입력해 주세요.",
            actionTitle: "설정 열기"
        ) {
            SettingsLauncher.openAppSettings()
        }
    }
}

private struct PermissionPrompt: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(actionTitle, action: action)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

/// `AVCaptureSession` 기반 QR 리더.
///
/// `onDetect` 가 `true` 를 돌려주면 세션을 멈춥니다(원하는 코드를 찾은 경우).
/// `false` 면 계속 스캔합니다.
private struct QRCameraView: UIViewControllerRepresentable {

    let onDetect: (String) -> Bool

    func makeUIViewController(context: Context) -> QRCameraViewController {
        let controller = QRCameraViewController()
        controller.onDetect = onDetect
        return controller
    }

    func updateUIViewController(_ controller: QRCameraViewController, context: Context) {
        controller.onDetect = onDetect
    }
}

private final class QRCameraViewController: UIViewController {

    var onDetect: ((String) -> Bool)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    /// 같은 코드를 연속으로 처리하지 않도록 쓰는 잠금.
    private var isHandling = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func configureSession() {
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { return }

        session.beginConfiguration()
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            // addOutput 이후에 지정해야 지원 타입 목록이 채워집니다.
            output.metadataObjectTypes = [.qr]
        }
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    private func startIfNeeded() {
        guard !session.isRunning, !session.inputs.isEmpty else { return }
        // 세션 시작은 메인 스레드를 수백 ms 붙잡을 수 있어 백그라운드에서 호출합니다.
        Task.detached { [session] in
            session.startRunning()
        }
    }
}

extension QRCameraViewController: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !isHandling else { return }
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            object.type == .qr,
            let payload = object.stringValue
        else { return }

        isHandling = true
        let shouldStop = onDetect?(payload) ?? false
        if shouldStop {
            session.stopRunning()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            // 다른 코드를 계속 읽을 수 있게 짧게 쉬고 잠금을 풉니다.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.isHandling = false
            }
        }
    }
}
