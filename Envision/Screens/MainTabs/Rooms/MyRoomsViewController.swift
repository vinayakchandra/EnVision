//
//  MyRoomsViewController.swift
//  Envision
//

import UIKit
import RoomPlan
import QuickLook
import QuickLookThumbnailing
import UniformTypeIdentifiers

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
    private var tipContainerBottomConstraint: NSLayoutConstraint?
    private var displayedTipID: String?
    private var scanBarButtonItem: UIBarButtonItem?
    private var importBarButtonItem: UIBarButtonItem?
    private var actionsBarButtonItem: UIBarButtonItem?

    // MARK: - Data
    var roomFiles: [URL] = []
    var selectedCategory: RoomCategory?
    var selectedRoomType: RoomType?
    lazy var thumbnailCache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        // Limit cache to 50 thumbnails to prevent excessive memory usage
        cache.countLimit = 50
        // Set total cost limit to ~50MB (assuming avg 1MB per thumbnail)
        cache.totalCostLimit = 50 * 1024 * 1024
        return cache
    }()
    private var inFlightThumbnailRequests: [URL: [(UIImage?) -> Void]] = [:]
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTourDidStart),
            name: .tourDidStart,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: Notification.Name("RoomThumbnailDidUpdate"), object: nil)
        NotificationCenter.default.removeObserver(self, name: .tourDidStart, object: nil)
    }

    @objc private func handleTourDidStart() {
        showContextualTips()
    }
    
    @objc private func handleThumbnailUpdate(_ notification: Notification) {
        guard let roomURL = notification.userInfo?["roomURL"] as? URL else { return }
        
        // Clear cached thumbnail so it reloads
        thumbnailCache.removeObject(forKey: roomURL as NSURL)
        
        // Find the index of this room in displayFiles
        guard let index = displayFiles.firstIndex(of: roomURL) else {
            // Room not currently displayed (filtered out or doesn't exist)
            return
        }
        
        // Only reload if the cell is visible (performance optimization)
        let indexPath = IndexPath(item: index, section: 1)
        if collectionView.indexPathsForVisibleItems.contains(indexPath) {
            DispatchQueue.main.async {
                self.collectionView.reloadItems(at: [indexPath])
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Thumbnails are updated via notifications, no need to reload everything
        // Only reload if we're coming back from background or files changed
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showContextualTips()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TipCoordinator.shared.dismissTip(from: tipContainerView)
        updateCollectionInsetsForTip(height: 0)
        displayedTipID = nil
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
        setupTipContainer()
    }

    private func setupNavigationBar() {
        let scanButton = UIBarButtonItem(image: UIImage(systemName: "camera.viewfinder"), style: .plain, target: self, action: #selector(scanTapped))
        scanButton.tintColor = .systemGreen

        let importButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importTapped))
        importButton.tintColor = .systemBlue

        scanBarButtonItem = scanButton
        importBarButtonItem = importButton
        navigationItem.rightBarButtonItems = [
            scanButton,
            importButton
        ]

        let actionsButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: makeMenu())
        actionsBarButtonItem = actionsButton
        navigationItem.leftBarButtonItem = actionsButton
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
        // Search handled by the dedicated Search tab — not added to nav bar
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
        let chipHeight: CGFloat = 30
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .estimated(150),
            heightDimension: .absolute(chipHeight)
        ))

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .estimated(150), heightDimension: .absolute(chipHeight)),
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

        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let columns = isPad ? 2 : 1
        let cellHeight: CGFloat = isPad ? 280 : 200
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(cellHeight)),
            repeatingSubitem: item,
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
            loadingOverlay.widthAnchor.constraint(equalToConstant: UIDevice.current.userInterfaceIdiom == .pad ? 260 : 220),
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
        HapticsManager.shared.selection()
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
        HapticsManager.shared.selection()
        isSelectionMode = true
        TipCoordinator.shared.dismissTip(from: tipContainerView)
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
        HapticsManager.shared.selection()
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
        showContextualTips()
    }

    @objc private func deleteSelectedRooms() {
        guard let selected = collectionView.indexPathsForSelectedItems, !selected.isEmpty else {
            HapticsManager.shared.warning()
            showToast(message: "No rooms selected")
            return
        }

        showConfirmation(title: "Delete \(selected.count) Room(s)?", message: "This action cannot be undone.") { [weak self] in
            self?.performBatchDelete(selected.map { self?.displayFiles[$0.item] }.compactMap { $0 })
        }
    }

    private func confirmDeleteAll() {
        guard !roomFiles.isEmpty else {
            HapticsManager.shared.warning()
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
                    // Delete metadata
                    MetadataManager.shared.deleteMetadata(for: filename)
                    
                    // Delete thumbnail and saved colors to prevent orphaned files
                    RoomColorManager.deleteThumbnail(for: url)
                    RoomColorManager.shared.clearColors(for: url)
                    
                    count += 1
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadRoomFiles()
            self?.disableMultipleSelection()
            HapticsManager.shared.success()
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
                self.showContextualTips()
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
                let didStart = url.startAccessingSecurityScopedResource()
                defer {
                    if didStart {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

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
        // Check memory cache first (on main thread - fast)
        if let cached = thumbnailCache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        if inFlightThumbnailRequests[url] != nil {
            inFlightThumbnailRequests[url]?.append(completion)
            return
        }
        inFlightThumbnailRequests[url] = [completion]
        
        // Check for saved colored thumbnail on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let savedThumbnail = self.loadSavedThumbnail(for: url) {
                // Cache and return on main thread
                DispatchQueue.main.async {
                    self.thumbnailCache.setObject(savedThumbnail, forKey: url as NSURL)
                    self.finishThumbnailRequest(for: url, image: savedThumbnail)
                }
                return
            }
            
            // Fall back to QuickLook generator
            let req = QLThumbnailGenerator.Request(
                fileAt: url,
                size: CGSize(width: 400, height: 400),
                scale: self.traitCollection.displayScale,
                representationTypes: .all
            )

            QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { [weak self] rep, _ in
                guard let self = self else { return }
                let image = rep?.uiImage

                if let image {
                    // Persist generated thumbnails so cold launches don't regenerate them repeatedly.
                    DispatchQueue.global(qos: .utility).async {
                        self.saveGeneratedThumbnail(image, for: url)
                    }
                }

                DispatchQueue.main.async {
                    if let image {
                        self.thumbnailCache.setObject(image, forKey: url as NSURL)
                    }
                    self.finishThumbnailRequest(for: url, image: image)
                }
            }
        }
    }

    private func finishThumbnailRequest(for url: URL, image: UIImage?) {
        let callbacks = inFlightThumbnailRequests[url] ?? []
        inFlightThumbnailRequests[url] = nil
        callbacks.forEach { $0(image) }
    }
    
    private func loadSavedThumbnail(for roomURL: URL) -> UIImage? {
        // This method is called on background queue now
        let roomName = roomURL.deletingPathExtension().lastPathComponent
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let thumbnailURL = documentsURL.appendingPathComponent("RoomThumbnails/\(roomName)_thumb.jpg")
        
        guard FileManager.default.fileExists(atPath: thumbnailURL.path) else {
            return nil
        }
        
        // Try to load and validate the image
        guard let imageData = try? Data(contentsOf: thumbnailURL),
              let image = UIImage(data: imageData) else {
            // Corrupted thumbnail - delete it so it can be regenerated
            try? FileManager.default.removeItem(at: thumbnailURL)
            print("⚠️ Removed corrupted thumbnail: \(roomName)")
            return nil
        }
        
        return image
    }

    private func saveGeneratedThumbnail(_ image: UIImage, for roomURL: URL) {
        let roomName = roomURL.deletingPathExtension().lastPathComponent
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documentsURL.appendingPathComponent("RoomThumbnails")
        let thumbnailURL = directory.appendingPathComponent("\(roomName)_thumb.jpg")

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = image.jpegData(compressionQuality: 0.82) {
            try? data.write(to: thumbnailURL, options: .atomic)
        }
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
        HapticsManager.shared.error()
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showConfirmation(title: String, message: String, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            HapticsManager.shared.warning()
            onConfirm()
        })
        present(alert, animated: true)
    }

    // MARK: - Tips
    private func setupTipContainer() {
        view.addSubview(tipContainerView)
        NSLayoutConstraint.activate([
            tipContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            tipContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            tipContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])

        tipContainerBottomConstraint?.isActive = false
        tipContainerBottomConstraint = tipContainerView.bottomAnchor.constraint(equalTo: tipContainerView.topAnchor)
        tipContainerBottomConstraint?.priority = .required
        tipContainerBottomConstraint?.isActive = true
    }

    private func showContextualTips() {
        guard isViewLoaded, view.window != nil else { return }
        guard TourManager.shared.hasSeen(tipID: AppTips.welcome.id) else { return }
        guard !TourManager.shared.tourSkipped, !TourManager.shared.hasCompletedTour else { return }

        if isSelectionMode {
            TipCoordinator.shared.dismissTip(from: tipContainerView)
            updateCollectionInsetsForTip(height: 0)
            displayedTipID = nil
            return
        }

        let activeTipSequence = activeRoomTipSequence()
        guard let tip = firstUnseen(from: activeTipSequence) else {
            TipCoordinator.shared.dismissTip(from: tipContainerView)
            updateCollectionInsetsForTip(height: 0)
            displayedTipID = nil
            if !TourManager.shared.roomToFurnitureHandoffShown {
                TourManager.shared.roomToFurnitureHandoffShown = true
                NotificationCenter.default.post(name: .roomTourDidComplete, object: nil)
            }
            return
        }

        if displayedTipID == tip.id, tipContainerView.subviews.contains(where: { $0 is TipBubbleView }) {
            return
        }

        TipCoordinator.shared.dismissTip(from: tipContainerView)
        updateCollectionInsetsForTip(height: 0)
        displayedTipID = nil

        showTip(tip, in: activeTipSequence) {}
    }

    private func activeRoomTipSequence() -> [TipDefinition] {
        if roomFiles.isEmpty {
            return [AppTips.roomsIntro, AppTips.roomScanSlowly]
        }
        if roomFiles.count == 1 {
            return [AppTips.roomImport, AppTips.roomActions, AppTips.roomLongPress]
        }
        return [
            AppTips.roomLongPress,
            AppTips.roomCategories,
            AppTips.roomSearch,
            AppTips.roomDetail,
            AppTips.roomARPreview,
        ]
    }

    private func firstUnseen(from tips: [TipDefinition]) -> TipDefinition? {
        tips.first { !TourManager.shared.hasSeen(tipID: $0.id) }
    }

    private func showTip(_ tip: TipDefinition, in sequence: [TipDefinition], action: @escaping () -> Void) {
        tipContainerBottomConstraint?.isActive = false
        tipContainerBottomConstraint = nil

        let stepIndex = (sequence.firstIndex(where: { $0.id == tip.id }) ?? 0) + 1
        let stepCount = max(1, sequence.count)
        let isLastStep = stepIndex == stepCount
        let placement = placementForTip(tip)

        let configuration = TipBubbleView.Configuration(
            title: tip.title,
            message: tip.message,
            primaryActionTitle: isLastStep ? "Done" : "Next",
            dismissActionTitle: "Skip",
            progressText: "\(stepIndex)/\(stepCount)",
            arrowEdge: placement.edge,
            arrowOffset: placement.offset
        )

        TipCoordinator.shared.showTip(
            id: tip.id,
            configuration: configuration,
            in: self,
            containerView: tipContainerView,
            onPrimaryAction: action,
            onDismiss: { [weak self] in
                self?.displayedTipID = nil
                self?.updateCollectionInsetsForTip(height: 0)
                self?.reestablishZeroHeightConstraint()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    self?.showContextualTips()
                }
            },
            onPresented: { [weak self] height in
                self?.displayedTipID = tip.id
                self?.updateCollectionInsetsForTip(height: height + 10)
            }
        )
    }

    private struct TipPlacement {
        let edge: TipBubbleView.ArrowEdge
        let offset: CGFloat
    }

    private func placementForTip(_ tip: TipDefinition) -> TipPlacement {
        switch tip.id {
        case AppTips.roomsIntro.id, AppTips.roomScanSlowly.id:
            return placement(pointingTo: viewForRightBarButton(at: 0), edge: .top)
        case AppTips.roomImport.id:
            return placement(pointingTo: viewForRightBarButton(at: 1), edge: .top)
        case AppTips.roomActions.id:
            return placement(pointingTo: viewForLeftBarButton(), edge: .top)
        case AppTips.roomCategories.id:
            return placement(pointingTo: firstChipCell(), edge: .bottom)
        case AppTips.roomSearch.id:
            return placement(pointingTo: navigationItem.searchController?.searchBar, edge: .top)
        case AppTips.roomLongPress.id, AppTips.roomDetail.id, AppTips.roomARPreview.id:
            return placement(pointingTo: firstRoomCell(), edge: .bottom)
        default:
            return TipPlacement(edge: .bottom, offset: 0)
        }
    }

    private func placement(pointingTo targetView: UIView?, edge: TipBubbleView.ArrowEdge) -> TipPlacement {
        guard let targetView else { return TipPlacement(edge: edge, offset: 0) }
        tipContainerView.layoutIfNeeded()
        let targetCenterInContainer = tipContainerView.convert(
            CGPoint(x: targetView.bounds.midX, y: targetView.bounds.midY),
            from: targetView
        )
        let offset = targetCenterInContainer.x - (tipContainerView.bounds.width / 2)
        return TipPlacement(edge: edge, offset: offset)
    }

    private func viewForRightBarButton(at index: Int) -> UIView? {
        switch index {
        case 0:
            return scanBarButtonItem?.value(forKey: "view") as? UIView
        case 1:
            return importBarButtonItem?.value(forKey: "view") as? UIView
        default:
            return nil
        }
    }

    private func viewForLeftBarButton() -> UIView? {
        actionsBarButtonItem?.value(forKey: "view") as? UIView
    }

    private func firstChipCell() -> UIView? {
        collectionView.cellForItem(at: IndexPath(item: 0, section: 0))
    }

    private func firstRoomCell() -> UIView? {
        let firstVisibleRoom = collectionView.indexPathsForVisibleItems
            .filter { $0.section == 1 }
            .sorted()
            .first
        guard let firstVisibleRoom else { return nil }
        return collectionView.cellForItem(at: firstVisibleRoom)
    }

    private func reestablishZeroHeightConstraint() {
        guard tipContainerBottomConstraint == nil else { return }
        tipContainerBottomConstraint = tipContainerView.bottomAnchor.constraint(equalTo: tipContainerView.topAnchor)
        tipContainerBottomConstraint?.priority = .required
        tipContainerBottomConstraint?.isActive = true
    }

    private func updateCollectionInsetsForTip(height: CGFloat) {
        var inset = collectionView.contentInset
        if abs(inset.top - height) <= 0.5 { return }
        inset.top = max(0, height)
        collectionView.contentInset = inset
        collectionView.scrollIndicatorInsets = inset
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

    // MARK: - Tips Container
    private let tipContainerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = true
        v.isHidden = false
        return v
    }()

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
        button.configuration = .plain()
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
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

        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.buttonSize = .mini
        configuration.image = UIImage(
            systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        )
        configuration.imagePlacement = .leading
        configuration.imagePadding = 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.baseForegroundColor = isSelected ? .white : color
        configuration.background.backgroundColor = isSelected ? color : color.withAlphaComponent(0.1)
        configuration.background.cornerRadius = 15
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            return out
        }
        button.configuration = configuration
    }
}
