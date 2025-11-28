//
//  RoomPreviewViewController.swift
//  Envision
//

import UIKit
import RoomPlan
import SceneKit
import QuickLookThumbnailing

final class RoomPreviewViewController: UIViewController {

    private let roomModel: RoomModel
    private var usdzURL: URL?
    private var isSaved = false

    // MARK: - UI

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()
    
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .fill
        return stack
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = UIColor.systemGray6
        iv.layer.cornerRadius = 16
        iv.clipsToBounds = true
        return iv
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let infoCard: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.05
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        return view
    }()
    
    private let infoStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        return stack
    }()
    
    private let roomNameField: UITextField = {
        let field = UITextField()
        field.placeholder = "Room Name (optional)"
        field.font = AppFonts.medium(16)
        field.borderStyle = .roundedRect
        field.backgroundColor = .systemGray6
        field.returnKeyType = .done
        return field
    }()

    private let saveButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("💾 Save to My Rooms", for: .normal)
        btn.setTitle("✓ Saved!", for: .disabled)
        btn.titleLabel?.font = AppFonts.semibold(17)
        btn.backgroundColor = AppColors.accent
        btn.tintColor = .white
        btn.layer.cornerRadius = 14
        btn.heightAnchor.constraint(equalToConstant: 54).isActive = true
        return btn
    }()
    
    private let exportButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Export", for: .normal)
        btn.titleLabel?.font = AppFonts.medium(16)
        btn.backgroundColor = .systemBlue
        btn.tintColor = .white
        btn.layer.cornerRadius = 14
        btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return btn
    }()

    private let view3DButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("View 3D Object", for: .normal)
        btn.titleLabel?.font = AppFonts.medium(16)
        btn.backgroundColor = UIColor(red: 139/255, green: 111/255, blue: 71/255, alpha: 1)
        btn.tintColor = .white
        btn.layer.cornerRadius = 14
        btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return btn
    }()

    private let viewARButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("View in AR", for: .normal)
        btn.titleLabel?.font = AppFonts.medium(16)
        btn.backgroundColor = .systemGreen
        btn.tintColor = .white
        btn.layer.cornerRadius = 14
        btn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return btn
    }()

    // MARK: - Init

    init(roomModel: RoomModel) {
        self.roomModel = roomModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Room Preview"
        view.backgroundColor = AppColors.background
        
        setupLayout()
        configureContent()
        exportRoomToUSDZ()
        
        roomNameField.delegate = self
    }

    // MARK: - Layout

    private func setupLayout() {
        // Setup scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        
        // Image container
        let imageContainer = UIView()
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        imageContainer.addSubview(imageView)
        imageContainer.addSubview(loadingIndicator)
        
        // Info card
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoCard.addSubview(infoStack)
        
        // Add to stack
        contentStack.addArrangedSubview(imageContainer)
        contentStack.addArrangedSubview(roomNameField)
        contentStack.addArrangedSubview(infoCard)
        contentStack.addArrangedSubview(saveButton)
        contentStack.addArrangedSubview(view3DButton)
        contentStack.addArrangedSubview(viewARButton)
        contentStack.addArrangedSubview(exportButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
            
            imageContainer.heightAnchor.constraint(equalTo: imageContainer.widthAnchor, multiplier: 0.65),
            
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            
            infoStack.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 16),
            infoStack.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -16),
            infoStack.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -16)
        ])
        
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        view3DButton.addTarget(self, action: #selector(openObject3D), for: .touchUpInside)
        viewARButton.addTarget(self, action: #selector(openInAR), for: .touchUpInside)
    }

    private func configureContent() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy"
        let dateString = formatter.string(from: roomModel.createdAt)
        
        addInfoRow(icon: "calendar", title: "Created", value: dateString)
        addInfoRow(icon: "ruler", title: "Dimensions", value: roomModel.sizeDescription)
        addInfoRow(icon: "cube.fill", title: "Model Type", value: "RoomPlan USDZ")
        
        // Set default name
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        roomNameField.text = "Room_\(dateFormatter.string(from: Date()))"
    }
    
    private func addInfoRow(icon: String, title: String, value: String) {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = AppColors.textSecondary
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = AppFonts.medium(14)
        titleLabel.textColor = AppColors.textSecondary
        titleLabel.widthAnchor.constraint(equalToConstant: 90).isActive = true
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AppFonts.regular(14)
        valueLabel.textColor = AppColors.textPrimary
        valueLabel.numberOfLines = 0
        
        row.addArrangedSubview(iconView)
        row.addArrangedSubview(titleLabel)
        row.addArrangedSubview(valueLabel)
        
        infoStack.addArrangedSubview(row)
    }

    // MARK: - USDZ Export

    private func exportRoomToUSDZ() {
        loadingIndicator.startAnimating()
        
        let room = roomModel.capturedRoom
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("room-\(UUID().uuidString).usdz")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try room.export(to: url, exportOptions: [.parametric])
                self.usdzURL = url
                
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.generateThumbnail(from: url)
                }
            } catch {
                print("❌ Error exporting room USDZ:", error)
                DispatchQueue.main.async {
                    self.loadingIndicator.stopAnimating()
                    self.imageView.image = UIImage(systemName: "exclamationmark.triangle")
                    self.showErrorAlert(message: "Failed to export room model")
                }
            }
        }
    }

    // MARK: - Thumbnail

    private func generateThumbnail(from url: URL) {
        let req = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 600, height: 600),
            scale: UIScreen.main.scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
            DispatchQueue.main.async {
                self.imageView.image = rep?.uiImage ?? UIImage(systemName: "cube.transparent")
            }
        }
    }

    // MARK: - Actions
    
    private func showCategorySelectionDialog(completion: @escaping (RoomCategory?) -> Void) {
        let alert = UIAlertController(
            title: "Select Room Category",
            message: "Choose the type of room to help organize your spaces",
            preferredStyle: .actionSheet
        )
        
        // Add action for each category with SF Symbol
        for category in RoomCategory.allCases {
            let action = UIAlertAction(title: "  \(category.displayName)", style: .default) { _ in
                completion(category)
            }
            
            // Set image with SF Symbol
            if let image = UIImage(systemName: category.sfSymbol)?.withTintColor(category.color, renderingMode: .alwaysOriginal) {
                action.setValue(image, forKey: "image")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(nil)
        })
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = saveButton
            popover.sourceRect = saveButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private var selectedCategory: RoomCategory?
    
    @objc private func saveTapped() {
        guard let url = usdzURL, !isSaved else { return }
        
        roomNameField.resignFirstResponder()
        
        // Show category selection dialog
        showCategorySelectionDialog(completion: { [weak self] category in
            guard let self = self, let category = category else { return }
            self.selectedCategory = category
            self.performSave(url: url, category: category)
        })
    }
    
    private func performSave(url: URL, category: RoomCategory) {
        // Show loading
        saveButton.isEnabled = false
        saveButton.setTitle("Saving...", for: .disabled)
        
        let customName = roomNameField.text?.isEmpty == false ? roomNameField.text : nil
        
        SaveManager.shared.saveModel(from: url, type: .room, customName: customName) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let savedURL):
                self.isSaved = true
                self.usdzURL = savedURL
                self.showSuccessAnimation()
                
            case .failure(let error):
                print("❌ Save error: \(error)")
                self.saveButton.isEnabled = true
                self.saveButton.setTitle("💾 Save to My Rooms", for: .normal)
                self.showErrorAlert(message: "Failed to save room. Please try again.")
            }
        }
    }
    
    private func showSuccessAnimation() {
        UIView.animate(withDuration: 0.3) {
            self.saveButton.backgroundColor = .systemGreen
            self.saveButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.saveButton.transform = .identity
            }
        }
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Show toast
        let toast = UILabel()
        toast.text = "✓ Saved to My Rooms"
        toast.font = AppFonts.semibold(14)
        toast.textColor = .white
        toast.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.95)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 20
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toast)
        toast.alpha = 0
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.heightAnchor.constraint(equalToConstant: 40),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ])
        
        UIView.animate(withDuration: 0.3) {
            toast.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5) {
                toast.alpha = 0
            } completion: { _ in
                toast.removeFromSuperview()
            }
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func openObject3D() {
        guard let url = usdzURL else { return }
        let vc = RoomViewerViewController(roomURL: url, mode: .object)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openInAR() {
        guard let url = usdzURL else { return }
        let vc = RoomViewerViewController(roomURL: url, mode: .ar)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func exportTapped() {
        guard let url = usdzURL else { return }
        
        let alert = UIAlertController(title: "Export Room", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Save to Files", style: .default) { _ in
            let picker = UIDocumentPickerViewController(forExporting: [url])
            self.present(picker, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Share", style: .default) { _ in
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
