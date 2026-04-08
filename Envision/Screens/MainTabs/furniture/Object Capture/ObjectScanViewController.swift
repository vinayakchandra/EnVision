//
//  ObjectScanViewController.swift
//  Envision
//

import UIKit
import AVFoundation
import RealityKit

final class ObjectScanViewController: UIViewController {

    private struct InstructionStep {
        let icon: String
        let title: String
        let detail: String
    }

    // MARK: - Camera
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var captureTimer: Timer?

    // MARK: - Storage
    private var tempFolderURL: URL!
    private var images: [URL] = []

    // MARK: - UI Elements
    private let instructionBackdropView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        return view
    }()
    private let instructionCard = UIView()
    private let instructionIconView = UIImageView()
    private let instructionTitle = UILabel()
    private let instructionDetails = UILabel()
    private let instructionDots = UIStackView()
    private let instructionNextButton = UIButton(type: .system)
    private let instructionSkipButton = UIButton(type: .system)
    private var instructionDotViews: [UIView] = []
    private var currentInstructionStep = 0
    private let instructionSteps: [InstructionStep] = [
        InstructionStep(
            icon: "lightbulb.max",
            title: "Good lighting helps",
            detail: "Use bright, even lighting and avoid harsh shadows on the object."
        ),
        InstructionStep(
            icon: "cube.transparent",
            title: "Clear space around object",
            detail: "Keep the object isolated so the capture focuses on clean geometry."
        ),
        InstructionStep(
            icon: "arrow.triangle.2.circlepath.camera",
            title: "Move slowly around 360°",
            detail: "Walk around the furniture steadily and capture all sides and heights."
        ),
        InstructionStep(
            icon: "checkmark.seal",
            title: "Capture enough photos",
            detail: "Aim for at least 30 photos before finishing for better reconstruction."
        ),
    ]

    private let flashlightButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "flashlight.off.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        btn.layer.cornerRadius = 25
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let stopButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Start Capture", for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        btn.backgroundColor = .systemBlue
        btn.tintColor = .white
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let helpButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let helpLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 12, weight: .semibold)
        lbl.textColor = .white
        lbl.text = "Help"
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let counterLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .monospacedDigitSystemFont(ofSize: 28, weight: .bold)
        lbl.textColor = .white
        lbl.text = "0"
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let counterSubLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 14, weight: .medium)
        lbl.textColor = .white.withAlphaComponent(0.8)
        lbl.text = "photos"
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let qualityIndicator: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 13, weight: .semibold)
        lbl.textColor = .systemYellow
        lbl.text = "Ready to scan"
        lbl.textAlignment = .center
        lbl.layer.cornerRadius = 12
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        lbl.clipsToBounds = true
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let guidanceLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 15, weight: .semibold)
        lbl.textColor = .white
        lbl.text = "Open Help (?) for tips"
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let guidanceContainer: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 18
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        view.clipsToBounds = true
        return view
    }()

    private var isFlashOn = false
    private var captureStartTime: Date?
    private var isCaptureRunning = false

    // MARK: - Init
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        hidesBottomBarWhenPushed = true
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupTempFolder()
        setupCamera()
        setupPreviewUI()
        setupInstructionCard()

        session.startRunning()
        applyIdleCaptureState()
    }

    // MARK: - Folder Setup
    private func setupTempFolder() {
        tempFolderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("scan-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(
            at: tempFolderURL,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Camera Setup
    private func setupCamera() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        session.commitConfiguration()

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)
    }

    // MARK: - UI Setup
    private func setupPreviewUI() {

        // Flashlight Button
        view.addSubview(flashlightButton)
        NSLayoutConstraint.activate([
            flashlightButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashlightButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            flashlightButton.widthAnchor.constraint(equalToConstant: 50),
            flashlightButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        flashlightButton.addTarget(self, action: #selector(toggleFlashlight), for: .touchUpInside)

        // Counter Stack
        let counterStack = UIStackView(arrangedSubviews: [counterLabel, counterSubLabel])
        counterStack.axis = .vertical
        counterStack.spacing = 2
        counterStack.alignment = .center
        counterStack.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(counterStack)
        NSLayoutConstraint.activate([
            counterStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            counterStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 15),
        ])
        
        // Quality Indicator
        view.addSubview(qualityIndicator)
        NSLayoutConstraint.activate([
            qualityIndicator.topAnchor.constraint(equalTo: counterStack.bottomAnchor, constant: 12),
            qualityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            qualityIndicator.heightAnchor.constraint(equalToConstant: 28),
            qualityIndicator.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
        
        // Stop Button (ADD BEFORE guidanceLabel to avoid constraint error)
        view.addSubview(stopButton)
        NSLayoutConstraint.activate([
            stopButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -25),
            stopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stopButton.widthAnchor.constraint(equalToConstant: 200),
            stopButton.heightAnchor.constraint(equalToConstant: 56)
        ])
        stopButton.addTarget(self, action: #selector(handleCaptureActionButton), for: .touchUpInside)

        let helpStack = UIStackView(arrangedSubviews: [helpButton, helpLabel])
        helpStack.axis = .vertical
        helpStack.spacing = 4
        helpStack.alignment = .center
        helpStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(helpStack)
        NSLayoutConstraint.activate([
            helpStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            helpStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            helpButton.widthAnchor.constraint(equalToConstant: 40),
            helpButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        helpButton.addTarget(self, action: #selector(showTipsFromHelp), for: .touchUpInside)
        
        // Guidance Card
        view.addSubview(guidanceContainer)
        guidanceContainer.contentView.addSubview(guidanceLabel)
        NSLayoutConstraint.activate([
            guidanceContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guidanceContainer.bottomAnchor.constraint(equalTo: stopButton.topAnchor, constant: -18),
            guidanceContainer.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 36),
            guidanceContainer.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -36),
            guidanceContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            guidanceLabel.topAnchor.constraint(equalTo: guidanceContainer.contentView.topAnchor, constant: 12),
            guidanceLabel.leadingAnchor.constraint(equalTo: guidanceContainer.contentView.leadingAnchor, constant: 16),
            guidanceLabel.trailingAnchor.constraint(equalTo: guidanceContainer.contentView.trailingAnchor, constant: -16),
            guidanceLabel.bottomAnchor.constraint(equalTo: guidanceContainer.contentView.bottomAnchor, constant: -12)
        ])
    }

    // MARK: - Instruction Card
    private func setupInstructionCard() {
        instructionCard.backgroundColor = .secondarySystemBackground
        instructionCard.layer.cornerRadius = 24
        instructionCard.layer.shadowColor = UIColor.black.cgColor
        instructionCard.layer.shadowOpacity = 0.18
        instructionCard.layer.shadowRadius = 20
        instructionCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        instructionCard.translatesAutoresizingMaskIntoConstraints = false

        instructionIconView.translatesAutoresizingMaskIntoConstraints = false
        instructionIconView.contentMode = .scaleAspectFit
        instructionIconView.tintColor = AppColors.accent

        instructionTitle.font = .systemFont(ofSize: 20, weight: .bold)
        instructionTitle.textAlignment = .center
        instructionTitle.textColor = .label
        instructionTitle.numberOfLines = 2
        instructionTitle.translatesAutoresizingMaskIntoConstraints = false

        instructionDetails.numberOfLines = 0
        instructionDetails.textAlignment = .center
        instructionDetails.textColor = .secondaryLabel
        instructionDetails.font = .systemFont(ofSize: 15)
        instructionDetails.translatesAutoresizingMaskIntoConstraints = false

        instructionDots.translatesAutoresizingMaskIntoConstraints = false
        instructionDots.axis = .horizontal
        instructionDots.spacing = 8
        instructionDots.alignment = .center

        instructionNextButton.setTitle("Next", for: .normal)
        instructionNextButton.setTitleColor(.white, for: .normal)
        instructionNextButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        instructionNextButton.backgroundColor = AppColors.accent
        instructionNextButton.layer.cornerRadius = 14
        instructionNextButton.translatesAutoresizingMaskIntoConstraints = false
        instructionNextButton.addTarget(self, action: #selector(instructionNextTapped), for: .touchUpInside)

        instructionSkipButton.setTitle("Skip", for: .normal)
        instructionSkipButton.setTitleColor(.secondaryLabel, for: .normal)
        instructionSkipButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        instructionSkipButton.translatesAutoresizingMaskIntoConstraints = false
        instructionSkipButton.addTarget(self, action: #selector(hideInstructionCard), for: .touchUpInside)

        instructionDotViews.removeAll()
        instructionDots.arrangedSubviews.forEach { v in
            instructionDots.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        for i in 0..<instructionSteps.count {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.layer.cornerRadius = 4
            dot.backgroundColor = i == 0 ? AppColors.accent : .systemGray4
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
            instructionDots.addArrangedSubview(dot)
            instructionDotViews.append(dot)
        }

        view.addSubview(instructionBackdropView)
        instructionBackdropView.contentView.addSubview(instructionCard)
        instructionCard.addSubview(instructionIconView)
        instructionCard.addSubview(instructionTitle)
        instructionCard.addSubview(instructionDetails)
        instructionCard.addSubview(instructionDots)
        instructionCard.addSubview(instructionNextButton)
        instructionCard.addSubview(instructionSkipButton)

        NSLayoutConstraint.activate([
            instructionBackdropView.topAnchor.constraint(equalTo: view.topAnchor),
            instructionBackdropView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            instructionBackdropView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            instructionBackdropView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            instructionCard.centerXAnchor.constraint(equalTo: instructionBackdropView.contentView.centerXAnchor),
            instructionCard.centerYAnchor.constraint(equalTo: instructionBackdropView.contentView.centerYAnchor),
            instructionCard.widthAnchor.constraint(equalTo: instructionBackdropView.contentView.widthAnchor, multiplier: 0.88),

            instructionIconView.topAnchor.constraint(equalTo: instructionCard.topAnchor, constant: 32),
            instructionIconView.centerXAnchor.constraint(equalTo: instructionCard.centerXAnchor),
            instructionIconView.widthAnchor.constraint(equalToConstant: 56),
            instructionIconView.heightAnchor.constraint(equalToConstant: 56),

            instructionTitle.topAnchor.constraint(equalTo: instructionIconView.bottomAnchor, constant: 20),
            instructionTitle.leadingAnchor.constraint(equalTo: instructionCard.leadingAnchor, constant: 24),
            instructionTitle.trailingAnchor.constraint(equalTo: instructionCard.trailingAnchor, constant: -24),

            instructionDetails.topAnchor.constraint(equalTo: instructionTitle.bottomAnchor, constant: 12),
            instructionDetails.leadingAnchor.constraint(equalTo: instructionCard.leadingAnchor, constant: 24),
            instructionDetails.trailingAnchor.constraint(equalTo: instructionCard.trailingAnchor, constant: -24),

            instructionDots.topAnchor.constraint(equalTo: instructionDetails.bottomAnchor, constant: 24),
            instructionDots.centerXAnchor.constraint(equalTo: instructionCard.centerXAnchor),

            instructionNextButton.topAnchor.constraint(equalTo: instructionDots.bottomAnchor, constant: 20),
            instructionNextButton.leadingAnchor.constraint(equalTo: instructionCard.leadingAnchor, constant: 24),
            instructionNextButton.trailingAnchor.constraint(equalTo: instructionCard.trailingAnchor, constant: -24),
            instructionNextButton.heightAnchor.constraint(equalToConstant: 50),

            instructionSkipButton.topAnchor.constraint(equalTo: instructionNextButton.bottomAnchor, constant: 10),
            instructionSkipButton.centerXAnchor.constraint(equalTo: instructionCard.centerXAnchor),
            instructionSkipButton.bottomAnchor.constraint(equalTo: instructionCard.bottomAnchor, constant: -20),
        ])

        instructionCard.alpha = 0
        instructionBackdropView.alpha = 0
        instructionBackdropView.isHidden = true
        instructionBackdropView.isUserInteractionEnabled = false
        updateInstructionContent(animated: false)
    }

    private func updateInstructionContent(animated: Bool) {
        let step = instructionSteps[currentInstructionStep]
        let isLast = currentInstructionStep == instructionSteps.count - 1

        let updateBlock = {
            self.instructionIconView.image = UIImage(
                systemName: step.icon,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
            )
            self.instructionTitle.text = step.title
            self.instructionDetails.text = step.detail
            self.instructionNextButton.setTitle(isLast ? "Done" : "Next", for: .normal)

            for (i, dot) in self.instructionDotViews.enumerated() {
                UIView.animate(withDuration: animated ? 0.25 : 0) {
                    dot.backgroundColor = i == self.currentInstructionStep ? AppColors.accent : .systemGray4
                    dot.transform = i == self.currentInstructionStep
                        ? CGAffineTransform(scaleX: 1.4, y: 1.4)
                        : .identity
                }
            }
        }

        if animated {
            UIView.transition(
                with: instructionCard,
                duration: 0.3,
                options: [.transitionCrossDissolve],
                animations: updateBlock
            )
        } else {
            updateBlock()
        }
    }

    private func showInstructionCard() {
        currentInstructionStep = 0
        updateInstructionContent(animated: false)
        instructionBackdropView.isHidden = false
        instructionBackdropView.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.4) {
            self.instructionBackdropView.alpha = 1
            self.instructionCard.alpha = 1
        }
    }

    @objc private func hideInstructionCard() {
        UIView.animate(withDuration: 0.3) {
            self.instructionBackdropView.alpha = 0
            self.instructionCard.alpha = 0
        } completion: { _ in
            self.instructionBackdropView.isHidden = true
            self.instructionBackdropView.isUserInteractionEnabled = false
        }
    }

    @objc private func instructionNextTapped() {
        if currentInstructionStep < instructionSteps.count - 1 {
            currentInstructionStep += 1
            updateInstructionContent(animated: true)
        } else {
            hideInstructionCard()
        }
    }

    @objc private func showTipsFromHelp() {
        showInstructionCard()
    }

    // MARK: - Flashlight
    @objc private func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = isFlashOn ? .off : .on
            isFlashOn.toggle()
            flashlightButton.setImage(
                UIImage(systemName: isFlashOn ? "flashlight.on.fill" : "flashlight.off.fill"),
                for: .normal
            )
            device.unlockForConfiguration()
        } catch {
            print("Flashlight error:", error)
        }
    }

    // MARK: - Auto Capture
    private func startAutoCapture() {
        guard captureTimer == nil else { return }
        // Capture every 0.4 seconds for good overlap between photos
        // Faster capture = more photos = better reconstruction but longer processing
        // 0.4s is a good balance for walking pace around object
        captureTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.takePhoto()
        }
    }

    private func takePhoto() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Quality Feedback
    private func updateQualityIndicator() {
        guard isCaptureRunning else { return }
        let count = images.count
        
        if count < 20 {
            qualityIndicator.text = " Keep capturing"
            qualityIndicator.textColor = .systemYellow
            qualityIndicator.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.2)
            stopButton.isEnabled = false
            stopButton.alpha = 0.5
        } else if count < 30 {
            qualityIndicator.text = "✓ Minimum reached"
            qualityIndicator.textColor = .systemGreen
            qualityIndicator.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
            stopButton.isEnabled = true
            stopButton.alpha = 1.0
            guidanceLabel.text = "Good! Continue for better quality"
        } else if count < 50 {
            qualityIndicator.text = " Good coverage"
            qualityIndicator.textColor = .systemGreen
            qualityIndicator.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
            guidanceLabel.text = "Excellent! Almost there..."
        } else if count < 80 {
            qualityIndicator.text = " Excellent!"
            qualityIndicator.textColor = .systemTeal
            qualityIndicator.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.3)
            guidanceLabel.text = "Perfect coverage! Tap Finish"
        } else {
            qualityIndicator.text = " Maximum coverage"
            qualityIndicator.textColor = .systemPurple
            qualityIndicator.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.3)
            guidanceLabel.text = "Outstanding! Ready to process"
        }
    }

    @objc private func handleCaptureActionButton() {
        if isCaptureRunning {
            stopCapture()
        } else {
            startCapture()
        }
    }

    private func startCapture() {
        isCaptureRunning = true
        captureStartTime = Date()
        stopButton.setTitle("Finish Capture", for: .normal)
        stopButton.isEnabled = false
        stopButton.alpha = 0.5
        guidanceLabel.text = "Walk slowly around the object"
        updateQualityIndicator()
        startAutoCapture()
    }

    private func applyIdleCaptureState() {
        isCaptureRunning = false
        stopButton.setTitle("Start Capture", for: .normal)
        stopButton.isEnabled = true
        stopButton.alpha = 1.0
        qualityIndicator.text = "Ready to scan"
        qualityIndicator.textColor = .white
        qualityIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        guidanceLabel.text = "Open Help (?) for tips"
    }

    // MARK: - Stop Capture
    @objc private func stopCapture() {
        captureTimer?.invalidate()
        captureTimer = nil
        session.stopRunning()
        
        // Calculate capture duration
        if let startTime = captureStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print(" Capture completed:")
            print("   • Photos: \(images.count)")
            print("   • Duration: \(String(format: "%.1f", duration))s")
            print("   • Average: \(String(format: "%.1f", duration / Double(images.count)))s per photo")
        }
        
        // Haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        let preview = ObjectCapturePreviewController(imagesFolder: tempFolderURL)
        navigationController?.pushViewController(preview, animated: true)
    }
}

// MARK: - Photo Delegate
extension ObjectScanViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            print(" Photo capture error: \(error.localizedDescription)")
            return
        }
        guard let rawData = photo.fileDataRepresentation() else { return }
        // Normalize every captured sample to actual JPEG bytes for Object Capture stability.
        let data: Data
        if let image = UIImage(data: rawData), let jpeg = image.jpegData(compressionQuality: 0.95) {
            data = jpeg
        } else {
            data = rawData
        }

        let filename = "IMG_\(String(format: "%04d", images.count + 1)).jpg"
        let url = tempFolderURL.appendingPathComponent(filename)

        try? data.write(to: url)
        images.append(url)

        // Update UI
        counterLabel.text = "\(images.count)"
        updateQualityIndicator()
        
        // Subtle haptic every 10 photos
        if images.count % 10 == 0 {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
        
        // Flash animation
        let flashView = UIView(frame: view.bounds)
        flashView.backgroundColor = .white
        flashView.alpha = 0.3
        view.addSubview(flashView)
        UIView.animate(withDuration: 0.1) {
            flashView.alpha = 0
        } completion: { _ in
            flashView.removeFromSuperview()
        }
    }
}
