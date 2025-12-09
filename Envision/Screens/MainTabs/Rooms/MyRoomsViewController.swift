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
    private var collectionView: UICollectionView!
    private var loadingOverlay: UIVisualEffectView!
    private var activityIndicator: UIActivityIndicatorView!
    private var loadingLabel: UILabel!
    private let searchController = UISearchController(searchResultsController: nil)
    private var refreshControl: UIRefreshControl!
    private var previewURL: URL!

    // MARK: - Data
    private var roomFiles: [URL] = []
    private var selectedCategory: RoomCategory?
    private var selectedRoomType: RoomType?
    private let thumbnailCache = NSCache<NSURL, UIImage>()

    private var isSearching: Bool {
        guard let text = searchController.searchBar.text else { return false }
        return searchController.isActive && !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var displayFiles: [URL] {
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

        // Clean up orphaned metadata
        MetadataManager.shared.cleanupOrphanedMetadata()

        loadRoomFiles()
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
            UIAction(title: "Select Multiple", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                self?.enableMultipleSelection()
            },
            UIAction(title: "Delete All", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.confirmDeleteAll()
            },
            UIAction(title: "Visualize furniture", image: UIImage(systemName: "arkit")) { [weak self] _ in
                self?.showARViewController()
            }
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

    @objc private func chipTapped(_ sender: UIButton) {
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
        updateTitle()
    }

    private func enableMultipleSelection() {
        collectionView.allowsMultipleSelection = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(disableMultipleSelection))
        navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(deleteSelectedRooms))]
        showToast(message: "Tap rooms to select, then tap delete")
    }

    @objc private func disableMultipleSelection() {
        collectionView.allowsMultipleSelection = false
        collectionView.indexPathsForSelectedItems?.forEach { collectionView.deselectItem(at: $0, animated: true) }
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

    @objc private func showARViewController() {
        navigationController?.pushViewController(RoomFurniture(), animated: true)
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

    private func loadRoomFiles() {
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
            }
        }
    }

// Update your importRoomFiles method or add a new method:

    private func importRoomFiles(_ urls: [URL]) {
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
    private func loadMetadata(for url: URL) -> RoomMetadata? {
        let filename = url.lastPathComponent
        return MetadataManager.shared.getMetadata(for: filename)
    }

    private func updateTitle() {
        if let category = selectedCategory {
            title = "\(category.displayName) (\(displayFiles.count))"
        } else if let roomType = selectedRoomType {
            title = "\(roomType.displayName) (\(displayFiles.count))"
        } else {
            title = "My Rooms"
        }
    }

    // MARK: - Thumbnails
    private func generateThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = thumbnailCache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

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

    private func fileSizeString(for url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return "--" }

        let fmt = ByteCountFormatter()
        fmt.countStyle = .file
        return fmt.string(fromByteCount: size.int64Value)
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

    private func showToast(message: String) {
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

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showConfirmation(title: String, message: String, onConfirm: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in onConfirm() })
        present(alert, animated: true)
    }

    private var allChipsData: [(title: String, icon: String, category: RoomCategory?, roomType: RoomType?)] {
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
}

// MARK: - UIDocumentPickerDelegate
extension MyRoomsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        importRoomFiles(urls)
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension MyRoomsViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        section == 0 ? allChipsData.count : displayFiles.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChipCell.reuseID, for: indexPath) as! ChipCell
            let chip = allChipsData[indexPath.item]

            // Determine if chip is selected
            let isSelected: Bool
            if chip.category == nil && chip.roomType == nil {
                // "All" chip
                isSelected = selectedCategory == nil && selectedRoomType == nil
            } else if let category = chip.category {
                isSelected = category == selectedCategory
            } else if let roomType = chip.roomType {
                isSelected = roomType == selectedRoomType
            } else {
                isSelected = false
            }

            cell.configure(title: chip.title, icon: chip.icon, category: chip.category, roomType: chip.roomType, isSelected: isSelected)
            cell.button.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            return cell
        } else {
            // Room cell - UPDATED VERSION WITH BADGES
            let url = displayFiles[indexPath.item]
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoomCell.reuseID, for: indexPath) as! RoomCell
            let metadata = loadMetadata(for: url)

            // Configure with metadata for badge display
            cell.configure(
                fileName: url.lastPathComponent,
                size: fileSizeString(for: url),
                thumbnail: nil,
                category: metadata?.category,
                roomType: metadata?.roomType
            )

            generateThumbnail(for: url) { [weak self] image in
                guard let self = self,
                      let cell = self.collectionView.cellForItem(at: indexPath) as? RoomCell else { return }
                let metadata = self.loadMetadata(for: url)

                // Update with thumbnail and metadata
                cell.configure(
                    fileName: url.lastPathComponent,
                    size: self.fileSizeString(for: url),
                    thumbnail: image,
                    category: metadata?.category,
                    roomType: metadata?.roomType
                )
            }

            return cell
        }
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section == 1, !collectionView.allowsMultipleSelection else { return }

        let url = displayFiles[indexPath.item]
        navigationController?.pushViewController(RoomViewerViewController(roomURL: url), animated: true)
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPath.section == 1 else { return nil }

        let url = displayFiles[indexPath.item]
        let currentMetadata = loadMetadata(for: url)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "Quick Look", image: UIImage(systemName: "eye")) { _ in
                    self?.quickLook(url: url)
                },
                UIAction(title: "Edit Category", image: UIImage(systemName: "tag")) { _ in
                    self?.showEditCategoryDialog(for: url, currentMetadata: currentMetadata)
                },
                UIAction(title: "Edit Room Type", image: UIImage(systemName: "cube")) { _ in
                    self?.showEditRoomTypeDialog(for: url, currentMetadata: currentMetadata)
                },
                UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                    self?.showRenameDialog(for: url)
                },
                UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    self?.shareRoom(url: url)
                },
                UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                    self?.confirmDelete(url: url)
                }
            ])
        }
    }


// MARK: - Edit Category/Type Methods

    private func showEditCategoryDialog(for url: URL, currentMetadata: RoomMetadata?) {
        let alert = UIAlertController(
            title: "Change Category",
            message: "Select a new category for this room",
            preferredStyle: .actionSheet
        )

        for category in RoomCategory.allCases {
            let action = UIAlertAction(
                title: "  \(category.displayName)",
                style: .default
            ) { [weak self] _ in
                self?.updateRoomCategory(url: url, newCategory: category, currentMetadata: currentMetadata)
            }

            // Add icon with color
            if let image = UIImage(systemName: category.sfSymbol)?
                .withTintColor(category.color, renderingMode: .alwaysOriginal) {
                action.setValue(image, forKey: "image")
            }

            // Mark current category
            if category == currentMetadata?.category {
                action.setValue(true, forKey: "checked")
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showEditRoomTypeDialog(for url: URL, currentMetadata: RoomMetadata?) {
        let alert = UIAlertController(
            title: "Change Room Type",
            message: "Select the type of 3D model",
            preferredStyle: .actionSheet
        )

        for roomType in RoomType.allCases {
            let action = UIAlertAction(
                title: "  \(roomType.displayName) - \(roomType.description)",
                style: .default
            ) { [weak self] _ in
                self?.updateRoomType(url: url, newRoomType: roomType, currentMetadata: currentMetadata)
            }

            // Add icon with color
            if let image = UIImage(systemName: roomType.sfSymbol)?
                .withTintColor(roomType.color, renderingMode: .alwaysOriginal) {
                action.setValue(image, forKey: "image")
            }

            // Mark current type
            if roomType == currentMetadata?.roomType {
                action.setValue(true, forKey: "checked")
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func updateRoomCategory(url: URL, newCategory: RoomCategory, currentMetadata: RoomMetadata?) {
        let filename = url.lastPathComponent

        // If no metadata exists, create new one with defaults
        guard var metadata = currentMetadata else {
            let newMetadata = RoomMetadata(
                category: newCategory,
                roomType: .parametric, // Default
                createdAt: Date(),
                dimensions: nil,
                tags: [],
                notes: nil
            )
            MetadataManager.shared.updateMetadata(for: filename, metadata: newMetadata)

            // Reload to update chips and UI
            collectionView.reloadData()
            showToast(message: "Category updated to \(newCategory.displayName)")
            return
        }

        // Update existing metadata
        metadata.category = newCategory
        MetadataManager.shared.updateMetadata(for: filename, metadata: metadata)

        // Reload to update chips and UI
        collectionView.reloadData()
        showToast(message: "Category updated to \(newCategory.displayName)")
    }

    private func updateRoomType(url: URL, newRoomType: RoomType, currentMetadata: RoomMetadata?) {
        let filename = url.lastPathComponent

        // If no metadata exists, create new one with defaults
        guard var metadata = currentMetadata else {
            let newMetadata = RoomMetadata(
                category: .livingRoom, // Default
                roomType: newRoomType,
                createdAt: Date(),
                dimensions: nil,
                tags: [],
                notes: nil
            )
            MetadataManager.shared.updateMetadata(for: filename, metadata: newMetadata)

            // Reload to update chips and UI
            collectionView.reloadData()
            showToast(message: "Room type updated to \(newRoomType.displayName)")
            return
        }

        // Update existing metadata
        metadata.roomType = newRoomType
        MetadataManager.shared.updateMetadata(for: filename, metadata: metadata)

        // Reload to update chips and UI
        collectionView.reloadData()
        showToast(message: "Room type updated to \(newRoomType.displayName)")
    }


    private func showRenameDialog(for url: URL) {
        let alert = UIAlertController(title: "Rename Room", message: "Enter a new name for this room", preferredStyle: .alert)
        alert.addTextField { $0.text = url.deletingPathExtension().lastPathComponent; $0.autocapitalizationType = .words }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self, weak alert] _ in
            guard let newName = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !newName.isEmpty else { return }
            self?.performRename(url: url, newName: newName)
        })
        present(alert, animated: true)
    }

    private func performRename(url: URL, newName: String) {
        let fm = FileManager.default
        let dir = url.deletingLastPathComponent()
        let newURL = dir.appendingPathComponent("\(newName).usdz")
        let oldFilename = url.lastPathComponent
        let newFilename = newURL.lastPathComponent

        do {
            try fm.moveItem(at: url, to: newURL)

            // Update metadata with new filename
            MetadataManager.shared.renameMetadata(from: oldFilename, to: newFilename)

            loadRoomFiles()
            showToast(message: "Renamed to \(newName)")
        } catch {
            showAlert(title: "Rename Failed", message: error.localizedDescription)
        }
    }

    private func shareRoom(url: URL) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = vc.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(vc, animated: true)
    }

    private func confirmDelete(url: URL) {
        showConfirmation(title: "Delete Room?", message: "This action cannot be undone.") { [weak self] in
            let filename = url.lastPathComponent

            SaveManager.shared.deleteModel(at: url) { [weak self] success in
                if success {
                    // Delete metadata
                    MetadataManager.shared.deleteMetadata(for: filename)

                    self?.loadRoomFiles()
                    self?.showToast(message: "Room deleted")
                } else {
                    self?.showAlert(title: "Delete Failed", message: "Could not delete the room model.")
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        trailingSwipeActionsConfigurationForItemAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1 else { return nil }

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else { completion(false); return }
            let url = self.displayFiles[indexPath.item]
            try? FileManager.default.removeItem(at: url)
            self.roomFiles.removeAll { $0 == url }
            self.thumbnailCache.removeObject(forKey: url as NSURL)
            collectionView.deleteItems(at: [indexPath])
            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [delete])
    }
}

// MARK: - UISearchResultsUpdating
extension MyRoomsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        collectionView.reloadData()
    }
}

// MARK: - QLPreviewControllerDataSource
extension MyRoomsViewController: QLPreviewControllerDataSource {
    func quickLook(url: URL) {
        previewURL = url
        let preview = QLPreviewController()
        preview.dataSource = self
        present(preview, animated: true)
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewURL as NSURL
    }
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

        let attachment = NSTextAttachment()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        attachment.image = UIImage(systemName: icon, withConfiguration: config)?.withTintColor(button.tintColor, renderingMode: .alwaysOriginal)

        let attributedString = NSMutableAttributedString(attachment: attachment)
        attributedString.append(NSAttributedString(string: "  \(title)", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: button.tintColor
        ]))

        button.setAttributedTitle(attributedString, for: .normal)
    }
}