import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                    cameraPermissionDeniedView
                } else {
                    BarcodeCameraView(onScan: onScan)
                        .overlay(alignment: .center) {
                            scanOverlay
                        }
                        .overlay(alignment: .bottom) {
                            Text("Point at the barcode on the medicine package")
                                .font(A11y.bodyFont)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                                .padding(.bottom, 40)
                        }
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(A11y.bodyFont)
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Scan overlay

    private var scanOverlay: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.green, lineWidth: 3)
            .frame(width: 260, height: 160)
            .overlay {
                // Corner marks
                ForEach(Corner.allCases, id: \.self) { corner in
                    cornerMark(corner)
                }
            }
    }

    private func cornerMark(_ corner: Corner) -> some View {
        let length: CGFloat = 24
        let thickness: CGFloat = 4
        return ZStack {
            Rectangle()
                .frame(width: corner.isLeft ? length : thickness,
                       height: corner.isLeft ? thickness : length)
            Rectangle()
                .frame(width: corner.isLeft ? thickness : length,
                       height: corner.isLeft ? length : thickness)
        }
        .foregroundStyle(Color.green)
        .frame(width: 260, height: 160, alignment: corner.alignment)
    }

    // MARK: - Permission denied

    private var cameraPermissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Camera Access Required")
                .font(A11y.labelFont)
            Text("MedTrack needs camera access to scan medicine barcodes.")
                .font(A11y.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(A11y.actionFont)
            .buttonStyle(.borderedProminent)
            .frame(minHeight: A11y.minRowHeight)
        }
        .padding()
    }

    // MARK: - Helpers

    private enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        var isLeft: Bool { self == .topLeft || self == .bottomLeft }
        var alignment: Alignment {
            switch self {
            case .topLeft: return .topLeading
            case .topRight: return .topTrailing
            case .bottomLeft: return .bottomLeading
            case .bottomRight: return .bottomTrailing
            }
        }
    }
}

// MARK: - UIViewControllerRepresentable Camera

struct BarcodeCameraView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> BarcodeCameraViewController {
        let vc = BarcodeCameraViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: BarcodeCameraViewController, context: Context) {}
}

final class BarcodeCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureSession()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        // EAN-13 covers UPC-A with a leading zero prepended by iOS
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean13, .upce, .code128, .dataMatrix, .pdf417]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        self.previewLayer = preview

        captureSession = session
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = object.stringValue else { return }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onScan?(barcode)
    }
}
