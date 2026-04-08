//
//  ObjectCapturePreviewController.swift
//  Envision
//

import UIKit
import RealityKit
import QuickLook

final class ObjectCapturePreviewController: UIViewController {

    private enum PreviewState {
        case ready
        case processing
        case completed
        case failed
    }

    // MARK: - Properties
    private let imagesFolder: URL
    private var photoCount = 0
    private var imageURLs: [URL] = []
    private var state: PreviewState = .ready { didSet { applyState() } }
    private var selectedDetailLevel: PhotogrammetrySession.Request.Detail = .reduced
    private var didFinalizeCurrentRun = false
    private var lastSavedURL: URL?

    private let processor = BackgroundModelProcessor.shared

    // MARK: - UI
    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Captured Photos"
        label.font = .preferredFont(forTextStyle: .title2).bold()
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let photoCountLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 94, height: 94)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10

        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.translatesAutoresizingMaskIntoConstraints = false
        view.register(ImagePreviewCell.self, forCellWithReuseIdentifier: "ImageCell")
        return view
    }()

    private let statusCard: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let qualityLabel: UILabel = {
        let label = UILabel()
        label.text = "Model Quality"
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let qualityValueLabel: UILabel = {
        let label = UILabel()
        label.text = "Standard"
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.textAlignment = .center
        label.backgroundColor = .tertiarySystemFill
        label.layer.cornerRadius = 10
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let qualityDescLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let progressView: UIProgressView = {
        let view = UIProgressView(progressViewStyle: .bar)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        view.progressTintColor = .systemBlue
        view.trackTintColor = .systemGray5
        return view
    }()

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    private let backgroundInfoLabel: UILabel = {
        let label = UILabel()
        label.text = "Processing continues even if you leave this screen"
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .systemBlue
        label.textAlignment = .center
        label.numberOfLines = 0
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var generateButton: UIButton = makeButton(
        title: "Generate 3D Model",
        symbol: "cube.transparent.fill",
        backgroundColor: .systemGreen,
        foregroundColor: .white
    )

    private lazy var exportButton: UIButton = makeButton(
        title: "Save Photos to Files",
        symbol: "square.and.arrow.down",
        backgroundColor: .systemBlue,
        foregroundColor: .white
    )

    private lazy var retakeButton: UIButton = makeButton(
        title: "Retake Photos",
        symbol: "camera.rotate",
        backgroundColor: .tertiarySystemFill,
        foregroundColor: .label
    )

    private lazy var cancelButton: UIButton = makeButton(
        title: "Cancel Processing",
        symbol: "xmark.circle",
        backgroundColor: .systemRed.withAlphaComponent(0.14),
        foregroundColor: .systemRed
    )

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Init
    init(imagesFolder: URL) {
        self.imagesFolder = imagesFolder
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Preview Capture"
        view.backgroundColor = .systemGroupedBackground

        setupUI()
        bindActions()
        loadImages()
        configureQualityDescription()
        setupBackgroundProcessingCallbacks()

        collectionView.delegate = self
        collectionView.dataSource = self

        checkExistingProcessing()
    }

    private func makeButton(title: String,
                            symbol: String,
                            backgroundColor: UIColor,
                            foregroundColor: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.baseBackgroundColor = backgroundColor
        config.baseForegroundColor = foregroundColor
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return button
    }

    private func bindActions() {
        generateButton.addTarget(self, action: #selector(startProcessing), for: .touchUpInside)
        retakeButton.addTarget(self, action: #selector(retakePhotos), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportPhotos), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelProcessingTapped), for: .touchUpInside)
    }

    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        [
            titleLabel,
            photoCountLabel,
            collectionView,
            statusCard,
            qualityLabel,
            qualityValueLabel,
            qualityDescLabel,
            progressView,
            progressLabel,
            backgroundInfoLabel,
            generateButton,
            exportButton,
            retakeButton,
            cancelButton,
            activityIndicator
        ].forEach { contentView.addSubview($0) }

        statusCard.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            photoCountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            photoCountLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            photoCountLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            collectionView.topAnchor.constraint(equalTo: photoCountLabel.bottomAnchor, constant: 14),
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            collectionView.heightAnchor.constraint(equalToConstant: 94),

            statusCard.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 16),
            statusCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            statusCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            statusLabel.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -12),

            qualityLabel.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 16),
            qualityLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            qualityLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            qualityValueLabel.topAnchor.constraint(equalTo: qualityLabel.bottomAnchor, constant: 8),
            qualityValueLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            qualityValueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            qualityValueLabel.heightAnchor.constraint(equalToConstant: 42),

            qualityDescLabel.topAnchor.constraint(equalTo: qualityValueLabel.bottomAnchor, constant: 8),
            qualityDescLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            qualityDescLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            progressView.topAnchor.constraint(equalTo: qualityDescLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 30),
            progressView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -30),

            progressLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8),
            progressLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            backgroundInfoLabel.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 10),
            backgroundInfoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            backgroundInfoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),

            generateButton.topAnchor.constraint(equalTo: backgroundInfoLabel.bottomAnchor, constant: 20),
            generateButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 26),
            generateButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -26),

            exportButton.topAnchor.constraint(equalTo: generateButton.bottomAnchor, constant: 12),
            exportButton.leadingAnchor.constraint(equalTo: generateButton.leadingAnchor),
            exportButton.trailingAnchor.constraint(equalTo: generateButton.trailingAnchor),

            retakeButton.topAnchor.constraint(equalTo: exportButton.bottomAnchor, constant: 12),
            retakeButton.leadingAnchor.constraint(equalTo: generateButton.leadingAnchor),
            retakeButton.trailingAnchor.constraint(equalTo: generateButton.trailingAnchor),

            cancelButton.topAnchor.constraint(equalTo: retakeButton.bottomAnchor, constant: 12),
            cancelButton.leadingAnchor.constraint(equalTo: generateButton.leadingAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: generateButton.trailingAnchor),

            activityIndicator.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 12),
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityIndicator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28)
        ])
    }

    // MARK: - Data
    private func loadImages() {
        do {
            let all = try FileManager.default.contentsOfDirectory(
                at: imagesFolder,
                includingPropertiesForKeys: nil
            )
            imageURLs = all
                .filter { ["jpg", "jpeg", "heic", "png"].contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            photoCount = imageURLs.count
            photoCountLabel.text = "\(photoCount) photos captured"

            if photoCount < 20 {
                statusLabel.text = "Low photo count. Capture 30-50 photos for better model quality."
                statusLabel.textColor = .systemOrange
            } else if photoCount >= 60 {
                statusLabel.text = "Excellent coverage. Ready to generate a detailed model."
                statusLabel.textColor = .systemGreen
            } else {
                statusLabel.text = "Good photo count. Ready to generate."
                statusLabel.textColor = .systemGreen
            }
        } catch {
            statusLabel.text = "Unable to load captured photos."
            statusLabel.textColor = .systemRed
        }
    }

    // MARK: - Quality
    private func configureQualityDescription() {
        selectedDetailLevel = .reduced
        qualityDescLabel.text = "Object Capture currently uses Standard detail (.reduced) for stable, fast processing."
    }

    // MARK: - Background Processing Hooks
    private func setupBackgroundProcessingCallbacks() {
        processor.onProgressUpdate = { [weak self] progress, status in
            guard let self else { return }
            self.progressView.setProgress(progress, animated: true)
            self.progressLabel.text = "\(Int(progress * 100))%"
            self.statusLabel.text = status
            self.statusLabel.textColor = .label
        }

        processor.onCompletion = { [weak self] savedURL in
            self?.finalizeSuccess(savedURL)
        }

        processor.onError = { [weak self] message in
            self?.finalizeFailure(message)
        }
    }

    private func checkExistingProcessing() {
        let current = processor.getCurrentState()
        if current.isProcessing {
            state = .processing
            progressView.isHidden = false
            progressLabel.isHidden = false
            progressView.progress = current.progress
            progressLabel.text = "\(Int(current.progress * 100))%"
            statusLabel.text = current.status
            statusLabel.textColor = .label
        }
    }

    // MARK: - Actions
    @objc private func retakePhotos() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func exportPhotos() {
        guard !imageURLs.isEmpty else {
            showErrorAlert("No photos found to export.")
            return
        }

        let exportFolder = FileManager.default.temporaryDirectory.appendingPathComponent("CapturedImages")
        try? FileManager.default.removeItem(at: exportFolder)

        do {
            try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
            for url in imageURLs {
                try FileManager.default.copyItem(at: url, to: exportFolder.appendingPathComponent(url.lastPathComponent))
            }
        } catch {
            showErrorAlert("Failed to prepare photos for export.")
            return
        }

        let picker = UIDocumentPickerViewController(forExporting: [exportFolder])
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    @objc private func cancelProcessingTapped() {
        processor.cancelProcessing()
        finalizeFailure("Processing cancelled")
    }

    @objc private func startProcessing() {
        if state == .completed, lastSavedURL != nil {
            goToMyModels()
            return
        }

        guard state != .processing else { return }
        guard photoCount >= 10 else {
            showErrorAlert("Capture more photos before generating a model.")
            return
        }

        didFinalizeCurrentRun = false
        state = .processing
        progressView.progress = 0
        progressLabel.text = "0%"
        statusLabel.text = "Preparing photogrammetry session..."
        statusLabel.textColor = .label

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        processor.startProcessing(imagesFolder: imagesFolder, detailLevel: selectedDetailLevel) { [weak self] result in
            // Processor also broadcasts via onCompletion/onError.
            // This callback is kept as a fallback and guarded to avoid double finalization.
            guard let self else { return }
            switch result {
            case .success(let savedURL):
                self.finalizeSuccess(savedURL)
            case .failure(let error):
                self.finalizeFailure(error.localizedDescription)
            }
        }
    }

    private func finalizeSuccess(_ savedURL: URL) {
        guard !didFinalizeCurrentRun else { return }
        didFinalizeCurrentRun = true

        lastSavedURL = savedURL
        state = .completed

        progressView.progress = 1
        progressLabel.text = "100%"
        statusLabel.text = "Model generated and saved successfully."
        statusLabel.textColor = .systemGreen

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if var config = generateButton.configuration {
            config.title = "View in My Models"
            config.baseBackgroundColor = .systemGreen
            generateButton.configuration = config
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.goToMyModels()
        }
    }

    private func finalizeFailure(_ message: String) {
        guard !didFinalizeCurrentRun else { return }
        didFinalizeCurrentRun = true

        state = .failed
        statusLabel.text = message
        statusLabel.textColor = .systemRed
        progressView.isHidden = true
        progressLabel.isHidden = true

        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func goToMyModels() {
        guard let tabBar = tabBarController else {
            navigationController?.popToRootViewController(animated: true)
            return
        }

        tabBar.selectedIndex = 1

        guard let furnitureNav = tabBar.viewControllers?[1] as? UINavigationController else { return }
        furnitureNav.popToRootViewController(animated: true)
    }

    private func applyState() {
        switch state {
        case .ready:
            generateButton.isEnabled = true
            exportButton.isEnabled = true
            retakeButton.isEnabled = true
            cancelButton.isHidden = true
            activityIndicator.stopAnimating()
            progressView.isHidden = true
            progressLabel.isHidden = true
            UIView.animate(withDuration: 0.2) { self.backgroundInfoLabel.alpha = 0 }

        case .processing:
            generateButton.isEnabled = false
            exportButton.isEnabled = false
            retakeButton.isEnabled = false
            cancelButton.isHidden = false
            activityIndicator.startAnimating()
            progressView.isHidden = false
            progressLabel.isHidden = false
            UIView.animate(withDuration: 0.2) { self.backgroundInfoLabel.alpha = 1 }

        case .completed:
            generateButton.isEnabled = true
            exportButton.isEnabled = true
            retakeButton.isEnabled = true
            cancelButton.isHidden = true
            activityIndicator.stopAnimating()
            progressView.isHidden = false
            progressLabel.isHidden = false
            UIView.animate(withDuration: 0.2) { self.backgroundInfoLabel.alpha = 0 }

        case .failed:
            generateButton.isEnabled = true
            exportButton.isEnabled = true
            retakeButton.isEnabled = true
            cancelButton.isHidden = true
            activityIndicator.stopAnimating()
            UIView.animate(withDuration: 0.2) { self.backgroundInfoLabel.alpha = 0 }
        }
    }

    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Collection View
extension ObjectCapturePreviewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        imageURLs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath) as! ImagePreviewCell
        cell.configure(with: imageURLs[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let preview = QLPreviewController()
        preview.dataSource = self
        preview.currentPreviewItemIndex = indexPath.item
        present(preview, animated: true)
    }
}

// MARK: - Quick Look
extension ObjectCapturePreviewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        imageURLs.count
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        imageURLs[index] as QLPreviewItem
    }
}

// MARK: - Image Preview Cell
final class ImagePreviewCell: UICollectionViewCell {
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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

        contentView.layer.cornerRadius = 10
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.systemGray5.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = UIImage(contentsOfFile: url.path)
            DispatchQueue.main.async {
                self.imageView.image = image
            }
        }
    }
}

private extension UIFont {
    func bold() -> UIFont {
        let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) ?? fontDescriptor
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}
