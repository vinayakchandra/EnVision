//
//  ObjectScanViewController.swift
//  Envision
//

import UIKit
import AVFoundation
import RealityKit

final class ObjectScanViewController: UIViewController {

    // MARK: - Camera
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var captureTimer: Timer?

    // MARK: - Storage
    private var tempFolderURL: URL!
    private var images: [URL] = []

    // MARK: - UI Elements
    private let instructionCard = UIView()
    private let instructionTitle = UILabel()
    private let instructionDetails = UILabel()
    private let continueButton = UIButton(type: .system)

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
        btn.setTitle("Finish Capture", for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        btn.backgroundColor = .systemBlue
        btn.tintColor = .white
        btn.layer.cornerRadius = 12
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
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
        lbl.text = "Keep capturing..."
        lbl.textAlignment = .center
        lbl.layer.cornerRadius = 12
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        lbl.clipsToBounds = true
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let guidanceLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 15, weight: .medium)
        lbl.textColor = .white
        lbl.text = "Walk slowly around the object"
        lbl.textAlignment = .center
        lbl.numberOfLines = 2
        lbl.layer.cornerRadius = 12
        lbl.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        lbl.clipsToBounds = true
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private var isFlashOn = false
    private var captureStartTime: Date?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupTempFolder()
        setupCamera()
        setupPreviewUI()
        setupInstructionCard()

        session.startRunning()
        showInstructionCard()
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
        stopButton.addTarget(self, action: #selector(stopCapture), for: .touchUpInside)
        
        // Guidance Label (ADD AFTER stopButton so constraint can reference it)
        view.addSubview(guidanceLabel)
        NSLayoutConstraint.activate([
            guidanceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            guidanceLabel.bottomAnchor.constraint(equalTo: stopButton.topAnchor, constant: -20),
            guidanceLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            guidanceLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
            guidanceLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
    }

    // MARK: - Instruction Card
    private func setupInstructionCard() {
        instructionCard.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        instructionCard.layer.cornerRadius = 20
        instructionCard.layer.masksToBounds = true
        instructionCard.translatesAutoresizingMaskIntoConstraints = false

        // Blur
        let blur = UIBlurEffect(style: .systemUltraThinMaterialLight)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.frame = instructionCard.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        instructionCard.addSubview(blurView)

        // Title
        instructionTitle.text = "Before You Start Scanning"
        instructionTitle.font = .boldSystemFont(ofSize: 20)
        instructionTitle.textAlignment = .center
        instructionTitle.textColor = .white
        instructionTitle.translatesAutoresizingMaskIntoConstraints = false

        // Details
        instructionDetails.text =
        """
📸 30-50 photos recommended
💡 Use bright, even lighting
🔄 Walk slowly around the object
📐 Cover all angles (top, sides, bottom)
🚫 Avoid shiny/reflective surfaces
"""
        instructionDetails.numberOfLines = 0
        instructionDetails.textAlignment = .left
        instructionDetails.textColor = .white
        instructionDetails.font = .systemFont(ofSize: 15)
        instructionDetails.translatesAutoresizingMaskIntoConstraints = false

        // Continue Button
        continueButton.setTitle("Continue", for: .normal)
        continueButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        continueButton.backgroundColor = .systemBlue
        continueButton.tintColor = .white
        continueButton.layer.cornerRadius = 12
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        continueButton.addTarget(self, action: #selector(hideInstructionCard), for: .touchUpInside)

        view.addSubview(instructionCard)
        instructionCard.addSubview(instructionTitle)
        instructionCard.addSubview(instructionDetails)
        instructionCard.addSubview(continueButton)

        NSLayoutConstraint.activate([
            instructionCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionCard.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            instructionCard.widthAnchor.constraint(equalToConstant: 300),
            instructionCard.heightAnchor.constraint(equalToConstant: 240),

            instructionTitle.topAnchor.constraint(equalTo: instructionCard.topAnchor, constant: 20),
            instructionTitle.centerXAnchor.constraint(equalTo: instructionCard.centerXAnchor),

            instructionDetails.topAnchor.constraint(equalTo: instructionTitle.bottomAnchor, constant: 10),
            instructionDetails.leadingAnchor.constraint(equalTo: instructionCard.leadingAnchor, constant: 20),
            instructionDetails.trailingAnchor.constraint(equalTo: instructionCard.trailingAnchor, constant: -20),

            continueButton.bottomAnchor.constraint(equalTo: instructionCard.bottomAnchor, constant: -20),
            continueButton.centerXAnchor.constraint(equalTo: instructionCard.centerXAnchor),
            continueButton.widthAnchor.constraint(equalToConstant: 120),
            continueButton.heightAnchor.constraint(equalToConstant: 45)
        ])

        instructionCard.alpha = 0
    }

    private func showInstructionCard() {
        UIView.animate(withDuration: 0.4) {
            self.instructionCard.alpha = 1
        }
    }

    @objc private func hideInstructionCard() {
        UIView.animate(withDuration: 0.3) {
            self.instructionCard.alpha = 0
        }

        captureStartTime = Date()
        startAutoCapture()
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
        captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.takePhoto()
        }
    }

    private func takePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Quality Feedback
    private func updateQualityIndicator() {
        let count = images.count
        
        if count < 30 {
            qualityIndicator.text = "⚠️ Keep capturing (\(count)/30)"
            qualityIndicator.textColor = .systemYellow
            qualityIndicator.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.2)
            stopButton.isEnabled = false
            stopButton.alpha = 0.5
            guidanceLabel.text = "Walk slowly around the object"
        } else if count < 40 {
            qualityIndicator.text = "✓ Minimum reached (\(count))"
            qualityIndicator.textColor = .systemGreen
            qualityIndicator.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
            stopButton.isEnabled = true
            stopButton.alpha = 1.0
            guidanceLabel.text = "Good! Continue for better quality"
        } else if count < 60 {
            qualityIndicator.text = "✓✓ Good coverage (\(count))"
            qualityIndicator.textColor = .systemGreen
            qualityIndicator.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
            guidanceLabel.text = "Excellent! Cover all angles"
        } else if count < 80 {
            qualityIndicator.text = "✓✓✓ Excellent! (\(count))"
            qualityIndicator.textColor = .systemTeal
            qualityIndicator.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.3)
            guidanceLabel.text = "Perfect coverage! Tap Finish"
        } else {
            qualityIndicator.text = "🏆 Maximum coverage (\(count))"
            qualityIndicator.textColor = .systemPurple
            qualityIndicator.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.3)
            guidanceLabel.text = "Outstanding! Ready to process"
        }
    }

    // MARK: - Stop Capture
    @objc private func stopCapture() {
        captureTimer?.invalidate()
        session.stopRunning()
        
        // Calculate capture duration
        if let startTime = captureStartTime {
            let duration = Date().timeIntervalSince(startTime)
            print("📸 Capture completed:")
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

        guard let data = photo.fileDataRepresentation() else { return }

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
