//
//  RoomPreviewViewController.swift
//  Envision
//

import UIKit
import RoomPlan
import QuickLookThumbnailing

final class RoomPreviewViewController: UIViewController {

    private enum GenerationState {
        case generating
        case ready
        case failed
    }

    private let roomModel: RoomModel
    private var usdzURL: URL?
    private var isSaved = false
    private var selectedCategory: RoomCategory = .livingRoom
    private var generationState: GenerationState = .generating {
        didSet { updateActionAvailability() }
    }

    // MARK: - UI
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        return stack
    }()

    private let imageContainer = UIView()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .secondarySystemBackground
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 18
        return iv
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "Preparing 3D model..."
        label.numberOfLines = 0
        return label
    }()

    private let roomNameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Room name"
        field.font = .preferredFont(forTextStyle: .body)
        field.backgroundColor = .secondarySystemBackground
        field.borderStyle = .roundedRect
        field.returnKeyType = .done
        field.autocapitalizationType = .words
        field.clearButtonMode = .whileEditing
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        field.leftViewMode = .always
        return field
    }()

    private let categoryCard = UIView()
    private let categoryButton: UIButton = {
        let button = UIButton(type: .system)
        button.contentHorizontalAlignment = .left
        button.titleLabel?.font = .preferredFont(forTextStyle: .body)
        return button
    }()

    private let infoCard = UIView()
    private let infoStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    private lazy var saveButton: UIButton = makeActionButton(
        title: "Save to My Rooms",
        symbol: "tray.and.arrow.down.fill",
        backgroundColor: .systemGreen,
        textColor: .white
    )

    private lazy var view3DButton: UIButton = makeActionButton(
        title: "View 3D Object",
        symbol: "cube.fill",
        backgroundColor: .systemBlue,
        textColor: .white
    )

    private lazy var viewARButton: UIButton = makeActionButton(
        title: "View in AR",
        symbol: "arkit",
        backgroundColor: .systemTeal,
        textColor: .white
    )

    private lazy var exportButton: UIButton = makeActionButton(
        title: "Export",
        symbol: "square.and.arrow.up",
        backgroundColor: .tertiarySystemFill,
        textColor: .label
    )

    // MARK: - Init
    init(roomModel: RoomModel) {
        self.roomModel = roomModel
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Room Preview"
        view.backgroundColor = .systemGroupedBackground

        setupLayout()
        configureContent()
        bindActions()

        roomNameField.delegate = self
        updateCategoryButton()
        setGeneratingState()
        exportRoomToUSDZ()
    }

    // MARK: - Setup
    private func makeActionButton(title: String,
                                  symbol: String,
                                  backgroundColor: UIColor,
                                  textColor: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePlacement = .leading
        config.imagePadding = 8
        config.baseBackgroundColor = backgroundColor
        config.baseForegroundColor = textColor
        config.cornerStyle = .large
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
        button.configuration = config
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        return button
    }

    private func styleCard(_ view: UIView) {
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
    }

    private func setupLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        roomNameField.translatesAutoresizingMaskIntoConstraints = false
        categoryCard.translatesAutoresizingMaskIntoConstraints = false
        categoryButton.translatesAutoresizingMaskIntoConstraints = false
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        styleCard(categoryCard)
        styleCard(infoCard)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        imageContainer.addSubview(imageView)
        imageContainer.addSubview(loadingIndicator)
        imageContainer.addSubview(statusLabel)

        categoryCard.addSubview(categoryButton)
        infoCard.addSubview(infoStack)

        contentStack.addArrangedSubview(imageContainer)
        contentStack.addArrangedSubview(roomNameField)
        contentStack.addArrangedSubview(categoryCard)
        contentStack.addArrangedSubview(infoCard)
        contentStack.addArrangedSubview(saveButton)
        contentStack.addArrangedSubview(view3DButton)
        contentStack.addArrangedSubview(viewARButton)
        contentStack.addArrangedSubview(exportButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),

            imageContainer.heightAnchor.constraint(equalTo: imageContainer.widthAnchor, multiplier: 0.62),

            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -12),
            statusLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -10),

            categoryButton.topAnchor.constraint(equalTo: categoryCard.topAnchor, constant: 14),
            categoryButton.leadingAnchor.constraint(equalTo: categoryCard.leadingAnchor, constant: 14),
            categoryButton.trailingAnchor.constraint(equalTo: categoryCard.trailingAnchor, constant: -14),
            categoryButton.bottomAnchor.constraint(equalTo: categoryCard.bottomAnchor, constant: -14),

            infoStack.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 14),
            infoStack.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 14),
            infoStack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -14),
            infoStack.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -14)
        ])
    }

    private func bindActions() {
        categoryButton.addTarget(self, action: #selector(categoryButtonTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view3DButton.addTarget(self, action: #selector(openObject3D), for: .touchUpInside)
        viewARButton.addTarget(self, action: #selector(openInAR), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
    }

    private func configureContent() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"

        addInfoRow(icon: "calendar", title: "Created", value: formatter.string(from: roomModel.createdAt))
        addInfoRow(icon: "ruler", title: "Dimensions", value: roomModel.sizeDescription)
        addInfoRow(icon: "cube.fill", title: "Model", value: "RoomPlan (Parametric)")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        roomNameField.text = "Room_\(dateFormatter.string(from: Date()))"

        imageView.image = roomModel.thumbnail ?? UIImage(systemName: "cube.transparent")
    }

    private func addInfoRow(icon: String, title: String, value: String) {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 10

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .secondaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 18).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 18).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .subheadline)
        titleLabel.textColor = .secondaryLabel
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.widthAnchor.constraint(equalToConstant: 86).isActive = true

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .preferredFont(forTextStyle: .subheadline)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 0

        row.addArrangedSubview(iconView)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(valueLabel)
        infoStack.addArrangedSubview(row)
    }

    private func updateCategoryButton() {
        let image = UIImage(systemName: selectedCategory.sfSymbol)
        var config = UIButton.Configuration.plain()
        config.image = image
        config.imagePadding = 8
        config.title = "Category: \(selectedCategory.displayName)  >"
        config.baseForegroundColor = .label
        categoryButton.configuration = config
        categoryButton.tintColor = selectedCategory.color
    }

    private func setGeneratingState() {
        generationState = .generating
        statusLabel.text = "Preparing 3D model..."
        loadingIndicator.startAnimating()
    }

    private func setReadyState() {
        generationState = .ready
        statusLabel.text = "Model ready"
        loadingIndicator.stopAnimating()
    }

    private func setFailedState() {
        generationState = .failed
        statusLabel.text = "Failed to generate model"
        loadingIndicator.stopAnimating()
    }

    private func updateActionAvailability() {
        let modelReady = generationState == .ready

        saveButton.isEnabled = modelReady && !isSaved
        view3DButton.isEnabled = modelReady
        viewARButton.isEnabled = modelReady
        exportButton.isEnabled = modelReady

        if var config = saveButton.configuration {
            config.title = isSaved ? "Saved" : "Save to My Rooms"
            config.baseBackgroundColor = isSaved ? .systemGray3 : .systemGreen
            saveButton.configuration = config
        }
    }

    private func requireReadyModel() -> URL? {
        guard generationState == .ready, let url = usdzURL else {
            showErrorAlert(message: "Room model is still generating. Please wait a moment and try again.")
            return nil
        }
        return url
    }

    // MARK: - USDZ Generation
    private func exportRoomToUSDZ() {
        setGeneratingState()

        let room = roomModel.capturedRoom
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("room-\(UUID().uuidString).usdz")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                try room.export(to: url, exportOptions: [.parametric])
                DispatchQueue.main.async {
                    self.usdzURL = url
                    self.generateThumbnail(from: url)
                    self.setReadyState()
                }
            } catch {
                print("❌ Error exporting room USDZ: \(error)")
                DispatchQueue.main.async {
                    self.usdzURL = nil
                    self.imageView.image = UIImage(systemName: "exclamationmark.triangle")
                    self.setFailedState()
                    self.showErrorAlert(message: "Failed to generate room model. Please rescan the room.")
                }
            }
        }
    }

    private func generateThumbnail(from url: URL) {
        let req = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 600, height: 600),
            scale: traitCollection.displayScale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { [weak self] rep, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.imageView.image = rep?.uiImage ?? UIImage(systemName: "cube.transparent")
            }
        }
    }

    // MARK: - Actions
    @objc private func categoryButtonTapped() {
        let alert = UIAlertController(
            title: "Select Room Category",
            message: "Choose the type of room",
            preferredStyle: .actionSheet
        )

        RoomCategory.allCases.forEach { category in
            let action = UIAlertAction(title: category.displayName, style: .default) { [weak self] _ in
                self?.selectedCategory = category
                self?.updateCategoryButton()
            }
            if let image = UIImage(systemName: category.sfSymbol)?.withTintColor(category.color, renderingMode: .alwaysOriginal) {
                action.setValue(image, forKey: "image")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = categoryButton
            popover.sourceRect = categoryButton.bounds
        }

        present(alert, animated: true)
    }

    @objc private func saveTapped() {
        guard let url = requireReadyModel(), !isSaved else { return }

        roomNameField.resignFirstResponder()
        performSave(url: url, category: selectedCategory)
    }

    private func performSave(url: URL, category: RoomCategory) {
        saveButton.isEnabled = false
        if var config = saveButton.configuration {
            config.title = "Saving..."
            saveButton.configuration = config
        }

        let rawName = roomNameField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let customName = (rawName?.isEmpty == false) ? rawName : nil

        SaveManager.shared.saveModel(from: url, type: .room, customName: customName) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let savedURL):
                let metadata = RoomMetadata(
                    category: category,
                    roomType: .parametric,
                    createdAt: Date(),
                    dimensions: self.extractDimensions(),
                    tags: [],
                    notes: nil
                )

                MetadataManager.shared.updateMetadata(
                    for: savedURL.lastPathComponent,
                    metadata: metadata
                )

                if let thumbnail = self.imageView.image {
                    DispatchQueue.global(qos: .userInitiated).async {
                        RoomColorManager.saveThumbnail(thumbnail, for: savedURL)
                    }
                }

                self.isSaved = true
                self.usdzURL = savedURL
                self.updateActionAvailability()
                self.redirectToMyRooms(with: savedURL)

            case .failure(let error):
                print("❌ Save error: \(error)")
                self.isSaved = false
                self.updateActionAvailability()
                self.showErrorAlert(message: "Failed to save room. Please try again.")
            }
        }
    }

    private func extractDimensions() -> RoomMetadata.RoomDimensions? {
        return nil
    }

    private func showSuccessAnimation() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        let toast = UILabel()
        toast.text = "Saved to My Rooms"
        toast.font = .preferredFont(forTextStyle: .footnote)
        toast.textColor = .white
        toast.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.95)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toast)
        toast.alpha = 0

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            toast.heightAnchor.constraint(equalToConstant: 32),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 170)
        ])

        UIView.animate(withDuration: 0.25) {
            toast.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.25, delay: 1.2) {
                toast.alpha = 0
            } completion: { _ in
                toast.removeFromSuperview()
            }
        }
    }

    private func redirectToMyRooms(with savedURL: URL) {
        guard let tabBar = tabBarController else { return }

        tabBar.selectedIndex = 0

        guard
            let homeNav = tabBar.viewControllers?.first as? UINavigationController
        else {
            return
        }

        homeNav.popToRootViewController(animated: true)

        if let myRoomsVC = homeNav.viewControllers.first as? MyRoomsViewController {
            myRoomsVC.loadRoomFiles()
        }

        NotificationCenter.default.post(
            name: Notification.Name("RoomThumbnailDidUpdate"),
            object: nil,
            userInfo: ["roomURL": savedURL]
        )
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func openObject3D() {
        guard let url = requireReadyModel() else { return }
        let vc = RoomViewerViewController(roomURL: url)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openInAR() {
        guard let url = requireReadyModel() else { return }
        let vc = RoomViewerViewController(roomURL: url)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func exportTapped() {
        guard let url = requireReadyModel() else { return }

        let alert = UIAlertController(title: "Export Room", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Save to Files", style: .default) { [weak self] _ in
            guard let self else { return }
            let picker = UIDocumentPickerViewController(forExporting: [url])
            self.present(picker, animated: true)
        })

        alert.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] _ in
            guard let self else { return }
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.exportButton
                popover.sourceRect = self.exportButton.bounds
            }
            self.present(activityVC, animated: true)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton.bounds
        }

        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension RoomPreviewViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
