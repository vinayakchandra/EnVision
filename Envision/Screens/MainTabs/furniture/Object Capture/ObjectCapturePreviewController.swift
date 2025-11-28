//
//  ObjectCapturePreviewController.swift
//  Envision
//

import UIKit
import RealityKit
import QuickLook

final class ObjectCapturePreviewController: UIViewController {

    // MARK: - Properties
    private let imagesFolder: URL
    private var photoCount: Int = 0
    private var isProcessing = false
    private var imageURLs: [URL] = []
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let contentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let headerLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Captured Photos"
        lbl.font = .boldSystemFont(ofSize: 24)
        lbl.textColor = .label
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let photoCountLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 16, weight: .medium)
        lbl.textColor = .secondaryLabel
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(ImagePreviewCell.self, forCellWithReuseIdentifier: "ImageCell")
        return cv
    }()

    private let statusLabel: UILabel = {
        let lbl = UILabel()
        lbl.textAlignment = .center
        lbl.font = .systemFont(ofSize: 16, weight: .medium)
        lbl.text = "Ready to generate 3D model"
        lbl.textColor = .secondaryLabel
        lbl.numberOfLines = 0
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .bar)
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.isHidden = true
        pv.progressTintColor = AppColors.accent
        return pv
    }()
    
    private let progressLabel: UILabel = {
        let lbl = UILabel()
        lbl.textAlignment = .center
        lbl.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        lbl.textColor = .secondaryLabel
        lbl.isHidden = true
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let generateButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Generate 3D Model", for: .normal)
        btn.titleLabel?.font = .boldSystemFont(ofSize: 18)
        btn.backgroundColor = AppColors.accent
        btn.tintColor = .white
        btn.layer.cornerRadius = 14
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        btn.layer.shadowRadius = 8
        btn.layer.shadowOpacity = 0.2
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let retakeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Retake Photos", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.backgroundColor = .systemGray5
        btn.setTitleColor(.label, for: .normal)
        btn.layer.cornerRadius = 14
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ind = UIActivityIndicatorView(style: .large)
        ind.hidesWhenStopped = true
        ind.translatesAutoresizingMaskIntoConstraints = false
        return ind
    }()
    
    private let exportButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Save Photos to Files", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.backgroundColor = .systemBlue
        btn.tintColor = .white
        btn.layer.cornerRadius = 14
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()


    // MARK: - Init
    init(imagesFolder: URL) {
        self.imagesFolder = imagesFolder
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Preview Capture"
        
        loadImages()
        setupUI()
        
        generateButton.addTarget(self, action: #selector(startProcessing), for: .touchUpInside)
        retakeButton.addTarget(self, action: #selector(retakePhotos), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportPhotos), for: .touchUpInside)

        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    // MARK: - Load Images
    private func loadImages() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: imagesFolder,
                includingPropertiesForKeys: nil
            )
            imageURLs = contents.filter { $0.pathExtension.lowercased() == "jpg" || $0.pathExtension.lowercased() == "jpeg" }
            photoCount = imageURLs.count
            photoCountLabel.text = "\(photoCount) photos captured"
            
            // Quality check
            if photoCount < 20 {
                statusLabel.text = "⚠️ Low photo count. For best results, capture 30-50 photos"
                statusLabel.textColor = .systemOrange
            } else if photoCount > 100 {
                statusLabel.text = "✓ Excellent coverage! Ready for high-quality model"
                statusLabel.textColor = .systemGreen
            } else {
                statusLabel.text = "✓ Good photo count. Ready to generate"
                statusLabel.textColor = .systemGreen
            }
        } catch {
            print("❌ Error loading images: \(error)")
        }
    }

    // MARK: - UI Layout
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        [headerLabel, photoCountLabel, collectionView, statusLabel,
         progressView, progressLabel, generateButton, retakeButton, activityIndicator, exportButton].forEach {
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            headerLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            photoCountLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            photoCountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            collectionView.topAnchor.constraint(equalTo: photoCountLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            collectionView.heightAnchor.constraint(equalToConstant: 100),
            
            statusLabel.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 30),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            progressView.heightAnchor.constraint(equalToConstant: 8),
            
            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            progressLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            generateButton.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 30),
            generateButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            generateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            generateButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            generateButton.heightAnchor.constraint(equalToConstant: 56),
            
            exportButton.topAnchor.constraint(equalTo: generateButton.bottomAnchor, constant: 12),
            exportButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            exportButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            exportButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            exportButton.heightAnchor.constraint(equalToConstant: 50),

            retakeButton.topAnchor.constraint(equalTo: generateButton.bottomAnchor, constant: 12),
            retakeButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            retakeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            retakeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            retakeButton.heightAnchor.constraint(equalToConstant: 50),

            activityIndicator.topAnchor.constraint(equalTo: retakeButton.bottomAnchor, constant: 20),
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30)
        ])
    }
    
    // MARK: - Actions
    @objc private func retakePhotos() {
        navigationController?.popViewController(animated: true)
    }
    @objc private func exportPhotos() {
        guard !imageURLs.isEmpty else { return }

        // Create a temporary directory for export
        let exportFolder = FileManager.default.temporaryDirectory.appendingPathComponent("CapturedImages")

        try? FileManager.default.removeItem(at: exportFolder) // clear if exists
        try? FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)

        // Copy images into the temp folder
        for url in imageURLs {
            let destURL = exportFolder.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: destURL)
        }

        // Open Files picker to save folder
        let picker = UIDocumentPickerViewController(forExporting: [exportFolder])
        picker.directoryURL = exportFolder
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        present(picker, animated: true)
    }

    // MARK: - Photogrammetry Processing
    @objc private func startProcessing() {
        guard !isProcessing else { return }
        isProcessing = true
        
        generateButton.isEnabled = false
        retakeButton.isEnabled = false
        activityIndicator.startAnimating()
        statusLabel.text = "🔄 Preparing photogrammetry session..."
        statusLabel.textColor = .label
        
        progressView.isHidden = false
        progressLabel.isHidden = false
        progressView.progress = 0
        progressLabel.text = "0%"
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Generate filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let timestamp = dateFormatter.string(from: Date())
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Furniture_\(timestamp).usdz")

        // Optimized configuration
        var config = PhotogrammetrySession.Configuration()
        config.sampleOrdering = .sequential
        config.featureSensitivity = .normal

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            print("🔍 Starting photogrammetry with \(self.photoCount) images")
            print("📁 Input folder: \(self.imagesFolder.path)")
            print("💾 Output: \(outputURL.path)")
            
            guard let session = try? PhotogrammetrySession(
                input: self.imagesFolder,
                configuration: config
            ) else {
                DispatchQueue.main.async {
                    self.handleError(message: "Failed to create photogrammetry session")
                }
                return
            }

            let request = PhotogrammetrySession.Request.modelFile(url: outputURL)
            var startTime = Date()

            Task {
                do {
                    for try await output in session.outputs {
                        switch output {
                        
                       

                        case .processingComplete:
                            print("✅ Processing complete!")
                            
                        case .inputComplete:
                            print("📥 Input complete")
                            
                        case .requestProgress(let request, let fraction):
                            let percentage = Int(fraction * 100)
                            
                            DispatchQueue.main.async {
                                self.progressView.setProgress(Float(fraction), animated: true)
                                self.progressLabel.text = "\(percentage)%"
                                
                                if percentage < 30 {
                                    self.statusLabel.text = "🔍 Analyzing images..."
                                } else if percentage < 70 {
                                    self.statusLabel.text = "🏗️ Building 3D mesh..."
                                } else if percentage < 95 {
                                    self.statusLabel.text = "🎨 Applying textures..."
                                } else {
                                    self.statusLabel.text = "✨ Finalizing model..."
                                }
                                
                                print("📊 Progress: \(percentage)%")
                            }

                        case .requestComplete(let request, let result):
                            let elapsed = Date().timeIntervalSince(startTime)
                            print("✅ Request complete in \(String(format: "%.1f", elapsed))s")
                            
                            DispatchQueue.main.async {
                                self.progressView.progress = 1.0
                                self.progressLabel.text = "100%"
                                self.statusLabel.text = "✓ 3D Model Generated!"
                                self.statusLabel.textColor = .systemGreen
                                self.saveModel(outputURL)
                            }
                            
                        case .requestError(let request, let error):
                            print("❌ Request error: \(error)")
                            DispatchQueue.main.async {
                                self.handleError(message: "Processing failed: \(error.localizedDescription)")
                            }
                            
                        case .processingCancelled:
                            print("⚠️ Processing cancelled")
                            DispatchQueue.main.async {
                                self.handleError(message: "Processing was cancelled")
                            }
                            
                        case .invalidSample(let id, let reason):
                            print("⚠️ Invalid sample \(id): \(reason)")
                            
                        case .skippedSample(let id):
                            print("⏭️ Skipped sample: \(id)")
                            
                        case .automaticDownsampling:
                            print("📉 Automatic downsampling applied")
                        default:
                            print("⚠️ Unknown output: \(output)")
                        }
                    }
                } catch {
                    print("❌ Task error: \(error)")
                    DispatchQueue.main.async {
                        self.handleError(message: "An error occurred: \(error.localizedDescription)")
                    }
                }
            }

            do {
                try session.process(requests: [request])
            } catch {
                print("❌ Process error: \(error)")
                DispatchQueue.main.async {
                    self.handleError(message: "Failed to start processing: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleError(message: String) {
        isProcessing = false
        activityIndicator.stopAnimating()
        statusLabel.text = "❌ \(message)"
        statusLabel.textColor = .systemRed
        generateButton.isEnabled = true
        retakeButton.isEnabled = true
        progressView.isHidden = true
        progressLabel.isHidden = true
        
        // Error haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    private func saveModel(_ url: URL) {
        SaveManager.shared.saveModel(from: url, type: .furniture, customName: nil) { [weak self] result in
            guard let self = self else { return }
            
            self.activityIndicator.stopAnimating()
            self.isProcessing = false
            
            switch result {
            case .success(let savedURL):
                self.statusLabel.text = "✓ Model Saved Successfully!"
                self.statusLabel.textColor = .systemGreen
                
                // Success haptic
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                
                // Animate success
                UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
                    self.generateButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                    self.generateButton.backgroundColor = .systemGreen
                } completion: { _ in
                    UIView.animate(withDuration: 0.3) {
                        self.generateButton.transform = .identity
                    }
                }
                
                // Update button
                self.generateButton.setTitle("View in My Models", for: .normal)
                self.generateButton.isEnabled = true
                
                print("✅ Model saved to: \(savedURL.path)")
                
                // Auto-navigate after 1.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.navigationController?.popToRootViewController(animated: true)
                }
                
            case .failure(let error):
                self.handleError(message: "Failed to save: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Collection View
extension ObjectCapturePreviewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return imageURLs.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImagePreviewCell
        cell.configure(with: imageURLs[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Quick Look preview
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.currentPreviewItemIndex = indexPath.item
        present(previewController, animated: true)
    }
}

// MARK: - Quick Look
extension ObjectCapturePreviewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return imageURLs.count
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return imageURLs[index] as QLPreviewItem
    }
}

// MARK: - Image Preview Cell
class ImagePreviewCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 4
        contentView.layer.shadowOpacity = 0.1
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(with url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = UIImage(contentsOfFile: url.path) {
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            }
        }
    }
}
