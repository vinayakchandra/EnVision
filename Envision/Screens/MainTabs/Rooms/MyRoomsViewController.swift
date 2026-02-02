//
//  MyRoomsViewController.swift
//  Envision
//

import UIKit
import RoomPlan
import QuickLook
import QuickLookThumbnailing
import UniformTypeIdentifiers
// TipKit temporarily removed from the project.

final class MyRoomsViewController: UIViewController {

    // MARK: - UI
    var collectionView: UICollectionView!
    private var loadingOverlay: UIVisualEffectView!
    private var activityIndicator: UIActivityIndicatorView!
    private var loadingLabel: UILabel!
    private let searchController = UISearchController(searchResultsController: nil)
    private var refreshControl: UIRefreshControl!
    var previewURL: URL!
    private var emptyStateView: UIView!

    // Tips temporarily removed

    // MARK: - Data
    var roomFiles: [URL] = []
    var selectedCategory: RoomCategory?
    var selectedRoomType: RoomType?
    let thumbnailCache = NSCache<NSURL, UIImage>()
    var isSelectionMode = false

    private var isSearching: Bool {
        guard let text = searchController.searchBar.text else { return false }
        return searchController.isActive && !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var displayFiles: [URL] {
        var filtered = roomFiles

        // Apply category filter
        if let category = selectedCategory {
            filtered = filtered.filter { loadMetadata(for: $0)?.category == category }
        }

        // Apply room type filter
        if let roomType = selectedRoomType {
            filtered = filtered.filter { loadMetadata(for: $0)?.roomType == roomType }
        }

        // Apply search filter
        if isSearching, let searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) {
            filtered = filtered.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(searchText) }
        }

        return filtered
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()

        title = "My Rooms"
        // Clean up orphaned metadata
        MetadataManager.shared.cleanupOrphanedMetadata()

        loadRoomFiles()
        
        // Listen for thumbnail updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThumbnailUpdate(_:)),
            name: Notification.Name("RoomThumbnailDidUpdate"),
            object: nil
        )

        // Tips temporarily removed
    }
    
    @objc private func handleThumbnailUpdate(_ notification: Notification) {
        guard let roomURL = notification.userInfo?["roomURL"] as? URL else { return }
        
        // Clear cached thumbnail so it reloads
        thumbnailCache.removeObject(forKey: roomURL as NSURL)
        
        // Reload the collection view
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload to pick up any thumbnail updates
        collectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Tips temporarily removed
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Tips temporarily removed
    }

    private func setupUI() {
        title = "My Rooms"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupSearch()
        setupCollectionView()
        setupRefreshControl()
        setupLoadingOverlay()
        setupEmptyState()

        // Tips temporarily removed
    }

    private func setupNavigationBar() {
        let scanButton = UIBarButtonItem(image: UIImage(systemName: "camera.viewfinder"), style: .plain, target: self, action: #selector(scanTapped))
        scanButton.tintColor = .systemGreen

        let importButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importTapped))
        importButton.tintColor = .systemBlue

        navigationItem.rightBarButtonItems = [
            scanButton,
            importButton
        ]

        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: makeMenu())
    }

    private func makeMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "Select Rooms", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                self?.enableMultipleSelection()
            },
            UIAction(title: "Delete All", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.confirmDeleteAll()
            },
        ])
    }

    private func setupSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search room models"
        searchController.searchBar.autocapitalizationType = .none
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true
    }

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { section, _ in
            section == 0 ? self.makeChipsSection() : self.makeRoomsSection()
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(ChipCell.self, forCellWithReuseIdentifier: ChipCell.reuseID)
        collectionView.register(RoomCell.self, forCellWithReuseIdentifier: RoomCell.reuseID)
        collectionView.delegate = self
        collectionView.dataSource = self

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func makeChipsSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .estimated(100),
            heightDimension: .absolute(32)
        ))

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .estimated(100), heightDimension: .absolute(32)),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        return section
    }

    private func makeRoomsSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        ))
        item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

        let columns = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 1
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(200)),
            subitem: item,
            count: columns
        )

        return NSCollectionLayoutSection(group: group)
    }

    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    private func setupLoadingOverlay() {
        loadingOverlay = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.layer.cornerRadius = 12
        loadingOverlay.clipsToBounds = true
        loadingOverlay.isHidden = true

        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        loadingLabel = UILabel()
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.textAlignment = .center
        loadingLabel.font = .systemFont(ofSize: 16)

        loadingOverlay.contentView.addSubview(activityIndicator)
        loadingOverlay.contentView.addSubview(loadingLabel)
        view.addSubview(loadingOverlay)

        NSLayoutConstraint.activate([
            loadingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingOverlay.widthAnchor.constraint(equalToConstant: 220),
            loadingOverlay.heightAnchor.constraint(equalToConstant: 120),
            activityIndicator.topAnchor.constraint(equalTo: loadingOverlay.contentView.topAnchor, constant: 18),
            activityIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.contentView.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 10),
            loadingLabel.leadingAnchor.constraint(equalTo: loadingOverlay.contentView.leadingAnchor, constant: 12),
            loadingLabel.trailingAnchor.constraint(equalTo: loadingOverlay.contentView.trailingAnchor, constant: -12)
        ])
    }

    // MARK: - Actions
    @objc private func handleRefresh() {
        loadRoomFiles()
    }

    @objc private func importTapped() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.usdz, .item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func scanTapped() {
        guard RoomCaptureSession.isSupported else {
            showAlert(title: "Not Supported", message: "This device does not support RoomPlan scanning.")
            return
        }
        navigationController?.pushViewController(RoomPlanScannerViewController(), animated: true)
    }

    @objc func chipTapped(_ sender: UIButton) {
        guard let cell = sender.superview?.superview as? ChipCell,
              let indexPath = collectionView.indexPath(for: cell) else { return }

        let chips = allChipsData
        let chipData = chips[indexPath.item]

        // Determine if it's a category or room type chip
        if let category = chipData.category {
            selectedCategory = category
        } else if let roomType = chipData.roomType {
            selectedRoomType = roomType
        } else {
            // "All" chip - clear both filters
            selectedCategory = nil
            selectedRoomType = nil
        }

        collectionView.reloadData()
    }

    private func enableMultipleSelection() {
        isSelectionMode = true
        collectionView.allowsMultipleSelection = true

        // Show circles on visible cells
        collectionView.visibleCells
        .compactMap { $0 as? RoomCell }
        .forEach { $0.setSelectionMode(true, animated: true) }

        let deleteButton = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(deleteSelectedRooms)
        )
        deleteButton.tintColor = .systemRed

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .prominent, target: self, action: #selector(disableMultipleSelection))
        navigationItem.rightBarButtonItems = [deleteButton]
        // navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(deleteSelectedRooms))]

        showToast(message: "Tap rooms to select, then tap delete")
    }

    @objc private func disableMultipleSelection() {
        isSelectionMode = false
        collectionView.allowsMultipleSelection = false

        // Hide circles
        collectionView.visibleCells
        .compactMap { $0 as? RoomCell }
        .forEach { $0.setSelectionMode(false, animated: true) }

        // Clear selection
        collectionView.indexPathsForSelectedItems?
            .forEach { collectionView.deselectItem(at: $0, animated: false) }

        setupNavigationBar()
    }

    @objc private func deleteSelectedRooms() {
        guard let selected = collectionView.indexPathsForSelectedItems, !selected.isEmpty else {
            showToast(message: "No rooms selected")
            return
        }

        showConfirmation(title: "Delete \(selected.count) Room(s)?", message: "This action cannot be undone.") { [weak self] in
            self?.performBatchDelete(selected.map { self?.displayFiles[$0.item] }.compactMap { $0 })
        }
    }

    private func confirmDeleteAll() {
        guard !roomFiles.isEmpty else {
            showToast(message: "No rooms to delete")
            return
        }

        showConfirmation(title: "Delete All Rooms?", message: "This will delete all \(roomFiles.count) rooms. This action cannot be undone.") { [weak self] in
            self?.performBatchDelete(self?.roomFiles ?? [])
        }
    }

    private func performBatchDelete(_ urls: [URL]) {
        var count = 0
        urls.forEach { url in
            let filename = url.lastPathComponent
            SaveManager.shared.deleteModel(at: url) { success in
                if success {
                    MetadataManager.shared.deleteMetadata(for: filename)
                    count += 1
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadRoomFiles()
            self?.disableMultipleSelection()
            self?.showToast(message: "Deleted \(count) room(s)")
        }
    }

    // MARK: - Data Management
    private var roomsFolderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("roomPlan", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func loadRoomFiles() {
        if !refreshControl.isRefreshing {
            showLoading("Loading rooms…")
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let files = (try? FileManager.default.contentsOfDirectory(at: self.roomsFolderURL, includingPropertiesForKeys: nil))?
            .filter { $0.pathExtension.lowercased() == "usdz" }
            .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() } ?? []

            DispatchQueue.main.async {
                self.roomFiles = files
                self.thumbnailCache.removeAllObjects()
                self.collectionView.reloadData()
                self.hideLoading()
                self.refreshControl.endRefreshing()
                self.updateEmptyState()
            }
        }
    }

// Update your importRoomFiles method or add a new method:

    func importRoomFiles(_ urls: [URL]) {
        // Show picker for category and room type
        showImportOptionsAlert(for: urls)
    }

    private func showImportOptionsAlert(for urls: [URL]) {
        let alert = UIAlertController(
            title: "Import Rooms",
            message: "Select category and type for imported rooms",
            preferredStyle: .alert
        )

        // Add action sheet for category
        let categoryAction = UIAlertAction(title: "Select Category", style: .default) { [weak self] _ in
            self?.showCategoryPicker(for: urls)
        }

        alert.addAction(categoryAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func showCategoryPicker(for urls: [URL]) {
        let alert = UIAlertController(title: "Select Category", message: nil, preferredStyle: .actionSheet)

        // Add category options
        for category in RoomCategory.allCases {
            alert.addAction(UIAlertAction(title: category.displayName, style: .default) { [weak self] _ in
                self?.showRoomTypePicker(for: urls, category: category)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showRoomTypePicker(for urls: [URL], category: RoomCategory) {
        let alert = UIAlertController(title: "Select Room Type", message: nil, preferredStyle: .actionSheet)

        // Add room type options
        for roomType in RoomType.allCases {
            alert.addAction(UIAlertAction(title: "\(roomType.displayName) - \(roomType.description)", style: .default) { [weak self] _ in
                self?.performImport(urls: urls, category: category, roomType: roomType)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func performImport(urls: [URL], category: RoomCategory, roomType: RoomType) {
        showLoading("Importing…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let fm = FileManager.default
            let destDir = self.roomsFolderURL

            for url in urls {
                url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }

                let dest = destDir.appendingPathComponent(url.lastPathComponent)

                // Remove existing file if present
                try? fm.removeItem(at: dest)

                // Copy the file
                try? fm.copyItem(at: url, to: dest)

                // Create metadata
                let metadata = RoomMetadata(
                    category: category,
                    roomType: roomType,
                    createdAt: Date(),
                    dimensions: nil,
                    tags: [],
                    notes: nil
                )

                MetadataManager.shared.updateMetadata(
                    for: dest.lastPathComponent,
                    metadata: metadata
                )
            }

            DispatchQueue.main.async {
                self.loadRoomFiles()
            }
        }
    }

// REPLACE THIS METHOD:
    func loadMetadata(for url: URL) -> RoomMetadata? {
        let filename = url.lastPathComponent
        return MetadataManager.shared.getMetadata(for: filename)
    }

    // MARK: - Thumbnails
    func generateThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
        // Check memory cache first
        if let cached = thumbnailCache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        
        // Check for saved colored thumbnail
        if let savedThumbnail = loadSavedThumbnail(for: url) {
            thumbnailCache.setObject(savedThumbnail, forKey: url as NSURL)
            completion(savedThumbnail)
            return
        }

        // Fall back to QuickLook generator
        let req = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 400, height: 400),
            scale: UIScreen.main.scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { [weak self] rep, _ in
            DispatchQueue.main.async {
                if let img = rep?.uiImage {
                    self?.thumbnailCache.setObject(img, forKey: url as NSURL)
                    completion(img)
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    private func loadSavedThumbnail(for roomURL: URL) -> UIImage? {
        let roomName = roomURL.deletingPathExtension().lastPathComponent
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let thumbnailURL = documentsURL.appendingPathComponent("RoomThumbnails/\(roomName)_thumb.jpg")
        
        guard FileManager.default.fileExists(atPath: thumbnailURL.path),
              let imageData = try? Data(contentsOf: thumbnailURL),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        return image
    }

    func fileSizeString(for url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return "--" }

        let fmt = ByteCountFormatter()
        fmt.countStyle = .file
        return fmt.string(fromByteCount: size.int64Value)
    }

    func fileDateString(for url: URL) -> String {
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let date = attrs[.creationDate] as? Date {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return "--"
    }

    // MARK: - UI Helpers
    private func showLoading(_ msg: String) {
        loadingLabel.text = msg
        loadingOverlay.isHidden = false
        activityIndicator.startAnimating()
    }

    private func hideLoading() {
        loadingOverlay.isHidden = true
        activityIndicator.stopAnimating()
    }

    // MARK: - Empty State
    private func setupEmptyState() {
        emptyStateView = UIView()
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true

        let iconView = UIImageView()
        iconView.image = UIImage(systemName: "house")
        iconView.tintColor = .systemGray3
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "No Rooms Yet"
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let messageLabel = UILabel()
        messageLabel.text = "Tap the camera icon to scan a room\nor import USDZ files"
        messageLabel.font = .systemFont(ofSize: 16)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        emptyStateView.addSubview(iconView)
        emptyStateView.addSubview(titleLabel)
        emptyStateView.addSubview(messageLabel)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            iconView.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])
    }

    private func updateEmptyState() {
        emptyStateView.isHidden = !roomFiles.isEmpty
    }

    func showToast(message: String) {
        let toast = UILabel()
        toast.text = message
        toast.font = AppFonts.medium(14)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.8)
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
            UIView.animate(withDuration: 0.3, delay: 2.0) {
                toast.alpha = 0
            } completion: { _ in
                toast.removeFromSuperview()
            }
        }
    }

    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showConfirmation(title: String, message: String, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in onConfirm() })
        present(alert, animated: true)
    }

    var allChipsData: [(title: String, icon: String, category: RoomCategory?, roomType: RoomType?)] {
        var chips: [(String, String, RoomCategory?, RoomType?)] = []

        // "All" chip with total count
        let totalCount = roomFiles.count
        chips.append(("All (\(totalCount))", "square.grid.2x2", nil, nil))

        // Add room type chips with counts
        for roomType in RoomType.allCases {
            let count = roomFiles.filter { loadMetadata(for: $0)?.roomType == roomType }.count
            chips.append(("\(roomType.displayName) (\(count))", roomType.sfSymbol, nil, roomType))
        }

        // Add category chips with counts
        for category in RoomCategory.allCases {
            let count = roomFiles.filter { loadMetadata(for: $0)?.category == category }.count
            chips.append(("\(category.displayName) (\(count))", category.sfSymbol, category, nil))
        }

        return chips
    }

    // MARK: - Tips container (kept but unused; can be removed later safely)
    private let tipContainerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = true
        v.isHidden = true
        return v
    }()

    private var tipContainerBottomConstraint: NSLayoutConstraint?
}

// MARK: - Models
// struct RoomMetadata: Codable {
//     let category: RoomCategory
//     let roomType: RoomType
//     let createdAt: Date
//     let dimensions: RoomDimensions?
//
//     struct RoomDimensions: Codable {
//         let width: Double
//         let height: Double
//         let length: Double
//     }
// }

// MARK: - ChipCell
final class ChipCell: UICollectionViewCell {
    static let reuseID = "ChipCell"
    let button = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 16
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: contentView.topAnchor),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, icon: String, category: RoomCategory?, roomType: RoomType?, isSelected: Bool) {
        let color: UIColor
        if let category = category {
            color = category.color
        } else if let roomType = roomType {
            color = roomType.color
        } else {
            color = .systemIndigo
        }

        button.backgroundColor = isSelected ? color : color.withAlphaComponent(0.1)
        button.tintColor = isSelected ? .white : color
        let resolvedTint: UIColor = button.tintColor ?? color

        let attachment = NSTextAttachment()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        attachment.image = UIImage(systemName: icon, withConfiguration: config)?.withTintColor(resolvedTint, renderingMode: .alwaysOriginal)

        let attributedString = NSMutableAttributedString(attachment: attachment)
        attributedString.append(NSAttributedString(string: "  \(title)", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: resolvedTint
        ]))

        button.setAttributedTitle(attributedString, for: .normal)
    }
}

// MARK: - TipKit Integration (temporarily removed)
// @available(iOS 17.0, *)
// extension MyRoomsViewController {
//
//     private func setupTips() {
//         // Create presenter for the screen-level tip container.
//         if tipPresenter == nil {
//             tipPresenter = TipPresenter(owner: self, containerView: tipContainerView)
//         }
//     }
//
//     private func updateTipParameters() {
//         MyRoomsIntroTip.hasRooms = !roomFiles.isEmpty
//         RoomActionsMenuTip.roomCount = roomFiles.count
//         RoomCategoriesTip.roomCount = roomFiles.count
//         RoomImportTip.hasScannedRoom = !roomFiles.isEmpty
//     }
//
//     private func showContextualTip() {
//         // Avoid showing tips while selecting or presenting another VC.
//         if isSelectionMode { dismissTip(); return }
//         if presentedViewController != nil { return }
//
//         updateTipParameters()
//
//         // Ensure any old SwiftUI-hosted tips are removed if they still exist (prevents ghost text).
//         tipContainerView.subviews.forEach { $0.removeFromSuperview() }
//
//         // Determine which tip to show (screen decides; TipPresenter just renders).
//         var title: String?
//         var message: String?
//         var image: String?
//         var actions: [TipPresenter.Action] = []
//
//         if roomFiles.isEmpty {
//             title = "📐 Scan Your First Room"
//             message = "Tap the green camera button to start scanning any room using your iPhone's LiDAR sensor. We'll create a precise 3D model!"
//             image = "camera.viewfinder"
//             actions = [
//                 .init(id: "scan", title: "Scan Now"),
//                 .init(id: "later", title: "Maybe Later")
//             ]
//         } else if roomFiles.count == 1 {
//             title = "📥 Already Have 3D Models?"
//             message = "Tap the blue import button to bring in existing USDZ room models from your Files app."
//             image = "square.and.arrow.down"
//             actions = [
//                 .init(id: "import", title: "Import"),
//                 .init(id: "later", title: "Later")
//             ]
//         } else if roomFiles.count >= 2 {
//             title = "🏷️ Organize Your Spaces"
//             message = "Use category chips to filter rooms by type. Long-press any room to edit its category and add custom tags."
//             image = "tag.fill"
//             actions = [
//                 .init(id: "got-it", title: "Got it")
//             ]
//         }
//
//         guard let title else { return }
//
//         tipContainerView.isHidden = false
//         setupTips()
//
//         let height = tipPresenter?.present(
//             title: title,
//             message: message,
//             systemImageName: image,
//             actions: actions
//         ) { [weak self] actionId in
//             self?.handleTipActionId(actionId)
//         } ?? 0
//
//         // Expand container to fit tip height, then update insets.
//         tipContainerBottomConstraint?.isActive = false
//         tipContainerBottomConstraint = tipContainerView.heightAnchor.constraint(equalToConstant: max(0, height))
//         tipContainerBottomConstraint?.priority = .required
//         tipContainerBottomConstraint?.isActive = true
//
//         updateCollectionInsetsForTip(containerHeight: height)
//     }
//
//     private func updateCollectionInsetsForTip(containerHeight: CGFloat) {
//         guard let collectionView else { return }
//         let topInset = max(0, containerHeight) + 12
//         var inset = collectionView.contentInset
//         if abs(inset.top - topInset) > 1 {
//             inset.top = topInset
//             collectionView.contentInset = inset
//             collectionView.scrollIndicatorInsets = inset
//         }
//     }
//
//     private func dismissTip() {
//         tipPresenter?.dismiss()
//         tipContainerView.subviews.forEach { $0.removeFromSuperview() }
//         tipContainerView.isHidden = true
//
//         // Collapse container.
//         tipContainerBottomConstraint?.isActive = false
//         tipContainerBottomConstraint = tipContainerView.bottomAnchor.constraint(equalTo: tipContainerView.topAnchor)
//         tipContainerBottomConstraint?.isActive = true
//
//         // Reset insets.
//         if let collectionView {
//             var inset = collectionView.contentInset
//             if inset.top != 0 {
//                 inset.top = 0
//                 collectionView.contentInset = inset
//                 collectionView.scrollIndicatorInsets = inset
//             }
//         }
//     }
//
//     private func handleTipActionId(_ id: String) {
//         switch id {
//         case "scan":
//             dismissTip()
//             scanTapped()
//         case "import":
//             dismissTip()
//             importTapped()
//         case "later", "got-it":
//             dismissTip()
//         default:
//             dismissTip()
//         }
//     }
// }
