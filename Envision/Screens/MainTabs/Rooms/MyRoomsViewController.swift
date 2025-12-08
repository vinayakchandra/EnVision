//
//  MyRoomsViewController.swift
//  Envision
//

import UIKit
import RoomPlan
import QuickLook
import QuickLookThumbnailing
import UniformTypeIdentifiers
import QuickLook

final class MyRoomsViewController: UIViewController {

    // MARK: - UI
    private var collectionView: UICollectionView!
    private var loadingOverlay: UIVisualEffectView!
    private var activityIndicator: UIActivityIndicatorView!
    private var loadingLabel: UILabel!

    private let searchController = UISearchController(searchResultsController: nil)
    private var previewURL: URL!


    // MARK: - Data
    private var roomFiles: [URL] = []
    private var filteredFiles: [URL] = []

    private var isSearching: Bool {
        let t = searchController.searchBar.text ?? ""
        return searchController.isActive && !t.trimmingCharacters(in: .whitespaces).isEmpty
    }
    private var selectedCategory: RoomCategory? = nil
    private let thumbnailCache: NSCache<NSURL, UIImage> = .init()
    private var refreshControl: UIRefreshControl! // refresh

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "My Rooms"
        navigationController?.navigationBar.prefersLargeTitles = true
        setupNavigationBar()
        setupSearch()
        setupCollectionView()
        setupRefreshControl()
        setupLoadingOverlay()

        loadRoomFiles(from: roomsFolderURL())
    }

    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    @objc private func handleRefresh() {
        loadRoomFiles(from: roomsFolderURL())
    }

    private func setupNavigationBar() {
        let filterBtn = UIBarButtonItem(
            image: UIImage(systemName: selectedCategory == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(filterTapped)
        )
        filterBtn.tintColor = selectedCategory == nil ? .systemIndigo : selectedCategory?.color

        let importBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(importTapped)
        )
        importBtn.tintColor = .systemBlue

        let scanBtn = UIBarButtonItem(
            image: UIImage(systemName: "camera.viewfinder"),
            style: .plain,
            target: self,
            action: #selector(scanTapped)
        )
        scanBtn.tintColor = .systemGreen


        navigationItem.rightBarButtonItems = [
            scanBtn,
            importBtn,
            filterBtn
        ]

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            menu: makeMenu()
        )
    }

    private func makeMenu() -> UIMenu {
        return UIMenu(children: [
            UIAction(title: "Select Multiple",
                     image: UIImage(systemName: "checkmark.circle")) { _ in
                self.enableMultipleSelection()
            },

            UIAction(title: "Delete All",
                     image: UIImage(systemName: "trash"),
                     attributes: .destructive) { _ in
                self.confirmDeleteAll()
            },
            UIAction(title: "Visualize furniture",
                     image: UIImage(systemName: "arkit")) { [weak self] _ in
                self?.showARViewController()
            },
        ])
    }
    // MARK: - Filter Button Handler
    @objc private func filterTapped() {
        showCategoryFilterMenu()
    }
    private func showCategoryFilterMenu() {
        let alert = UIAlertController(
            title: "Filter by Category",
            message: "Show rooms by category",
            preferredStyle: .actionSheet
        )

        // Add "All Rooms" option
        let allAction = UIAlertAction(
            title: selectedCategory == nil ? "✓ All Rooms" : "All Rooms",
            style: .default
        ) { [weak self] _ in
            self?.selectedCategory = nil
            self?.setupNavigationBar()
            self?.collectionView.reloadData()
            self?.updateTitle()
        }
        alert.addAction(allAction)

        // Add separator
        //        alert.addAction(UIAlertAction(title: "", style: .default, handler: nil))

        // Add category options with SF Symbols
        for category in RoomCategory.allCases {
            let isSelected = selectedCategory == category
            let title = isSelected ? "✓ \(category.displayName)" : "   \(category.displayName)"

            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.selectedCategory = category
                self?.setupNavigationBar()
                self?.collectionView.reloadData()
                self?.updateTitle()
            }

            // Set image with SF Symbol and color
            if let image = UIImage(systemName: category.sfSymbol)?.withTintColor(category.color, renderingMode: .alwaysOriginal) {
                action.setValue(image, forKey: "image")
            }

            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
        }

        present(alert, animated: true)
    }
    private func updateTitle() {
        if let category = selectedCategory {
            let count = displayFiles().count
            title = "\(category.displayName) (\(count))"
        } else {
            title = "My Rooms"
        }
    }
    // MARK: - Menu Actions

    @objc private func enableMultipleSelection() {
        collectionView.allowsMultipleSelection = true

        // Update navigation bar to show selection mode
        let doneBtn = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(disableMultipleSelection))
        let deleteBtn = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(deleteSelectedRooms))
        deleteBtn.tintColor = .systemRed

        navigationItem.leftBarButtonItem = doneBtn
        navigationItem.rightBarButtonItems = [deleteBtn]

        // Show toast
        showToast(message: "Tap rooms to select, then tap delete")
    }

    @objc private func disableMultipleSelection() {
        collectionView.allowsMultipleSelection = false

        // Deselect all
        if let selected = collectionView.indexPathsForSelectedItems {
            for indexPath in selected {
                collectionView.deselectItem(at: indexPath, animated: true)
            }
        }

        // Restore original navigation bar
        setupNavigationBar()
    }

    @objc private func deleteSelectedRooms() {
        guard let selectedIndexPaths = collectionView.indexPathsForSelectedItems, !selectedIndexPaths.isEmpty else {
            showToast(message: "No rooms selected")
            return
        }

        let alert = UIAlertController(
            title: "Delete \(selectedIndexPaths.count) Room(s)?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeleteSelectedRooms(at: selectedIndexPaths)
        })

        present(alert, animated: true)
    }

    private func performDeleteSelectedRooms(at indexPaths: [IndexPath]) {
        let filesToDelete = indexPaths.map { displayFiles()[$0.row] }

        var deletedCount = 0
        for url in filesToDelete {
            SaveManager.shared.deleteModel(at: url) { success in
                if success {
                    deletedCount += 1
                }
            }
        }

        // Reload after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadRoomFiles(from: self.roomsFolderURL())
            self.disableMultipleSelection()
            self.showToast(message: "Deleted \(deletedCount) room(s)")
        }
    }

    @objc private func showARViewController() {
        let arVC = RoomFurniture()
        navigationController?.pushViewController(arVC, animated: true)
    }
    private func confirmDeleteAll() {
        guard !roomFiles.isEmpty else {
            showToast(message: "No rooms to delete")
            return
        }

        let alert = UIAlertController(
            title: "Delete All Rooms?",
            message: "This will delete all \(roomFiles.count) rooms. This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { [weak self] _ in
            self?.performDeleteAll()
        })

        present(alert, animated: true)
    }

    private func performDeleteAll() {
        var deletedCount = 0

        for url in roomFiles {
            SaveManager.shared.deleteModel(at: url) { success in
                if success {
                    deletedCount += 1
                }
            }
        }

        // Reload after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadRoomFiles(from: self.roomsFolderURL())
            self.showToast(message: "Deleted all rooms")
        }
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
                                        toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
                                        toast.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
                                        toast.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
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

    private func displayFiles() -> [URL] {
        return isSearching ? filteredFiles : roomFiles
    }

    // MARK: - Search
    private func setupSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search room models"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        searchController.searchBar.autocapitalizationType = .none

        definesPresentationContext = true
    }

    // MARK: - Rooms folder
    private func roomsFolderURL() -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("roomPlan", isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    // MARK: - Import Button Handler
    @objc private func importTapped() {
        let allowed: [UTType] = [.usdz, .item]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowed, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Scan Button Handler
    @objc private func scanTapped() {
        if RoomCaptureSession.isSupported {
            let scanner = RoomPlanScannerViewController()
            navigationController?.pushViewController(scanner, animated: true)
        } else {
            showRoomPlanNotSupportedAlert()
        }
    }

    private func showRoomPlanNotSupportedAlert() {
        let alert = UIAlertController(
            title: "Not Supported",
            message: "This device does not support RoomPlan scanning.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Collection View
    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .fractionalHeight(1.0)
                )
            )
            item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

            let columns = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 1
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(200)
                ),
                subitem: item,
                count: columns
            )

            return NSCollectionLayoutSection(group: group)
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false

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

    // MARK: - Loading Overlay
    private func setupLoadingOverlay() {
        let blur = UIBlurEffect(style: .systemMaterial)
        loadingOverlay = UIVisualEffectView(effect: blur)
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
                                        loadingLabel.trailingAnchor.constraint(equalTo: loadingOverlay.contentView.trailingAnchor, constant: -12),
                                    ])
    }

    private func showLoading(_ msg: String) {
        loadingLabel.text = msg
        loadingOverlay.isHidden = false
        activityIndicator.startAnimating()
    }

    private func hideLoading() {
        loadingOverlay.isHidden = true
        activityIndicator.stopAnimating()
    }

    // MARK: - Import Logic
    private func importRoomFiles(_ urls: [URL]) {
        showLoading("Importing…")

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let destDir = self.roomsFolderURL()

            for url in urls {
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                }

                let dest = destDir.appendingPathComponent(url.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }

                try? fm.copyItem(at: url, to: dest)
            }

            DispatchQueue.main.async {
                self.loadRoomFiles(from: destDir)
            }
        }
    }

    // MARK: - Load Files
    private func loadRoomFiles(from folder: URL) {
        // Only show loading overlay if not triggered by pull-to-refresh
        if refreshControl == nil || !refreshControl.isRefreshing {
            showLoading("Loading rooms…")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var list: [URL] = []

            if let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    if ["usdz"].contains(ext) {
                        list.append(fileURL)
                    }
                }
            }

            list.sort { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }

            DispatchQueue.main.async {
                self.roomFiles = list
                self.thumbnailCache.removeAllObjects()
                self.collectionView.reloadData()
                self.hideLoading()

                // End refreshing animation
                if self.refreshControl.isRefreshing {
                    self.refreshControl.endRefreshing()
                }
            }
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

        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
            DispatchQueue.main.async {
                let img = rep?.uiImage
                if let img = img {
                    self.thumbnailCache.setObject(img, forKey: url as NSURL)
                }
                completion(img)
            }
        }
    }

    private func fileSizeString(for url: URL) -> String {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? NSNumber {
            let fmt = ByteCountFormatter()
            fmt.countStyle = .file
            return fmt.string(fromByteCount: size.int64Value)
        }
        return "--"
    }

    private func currentFile(at index: IndexPath) -> URL {
        return isSearching ? filteredFiles[index.item] : roomFiles[index.item]
    }
}

// MARK: - Document Picker
extension MyRoomsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        importRoomFiles(urls)
    }
}

// MARK: - CollectionView
extension MyRoomsViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isSearching ? filteredFiles.count : roomFiles.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let url = currentFile(at: indexPath)
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RoomCell.reuseID, for: indexPath) as! RoomCell

        cell.configure(
            fileName: url.lastPathComponent,
            size: fileSizeString(for: url),
            thumbnail: nil
        )

        generateThumbnail(for: url) { image in
            if let cell = collectionView.cellForItem(at: indexPath) as? RoomCell {
                cell.configure(
                    fileName: url.lastPathComponent,
                    size: self.fileSizeString(for: url),
                    thumbnail: image
                )
            }
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // If in multiple selection mode, just toggle selection
        if collectionView.allowsMultipleSelection {
            return
        }

        // Otherwise, open the room viewer
        let url = currentFile(at: indexPath)
        let vc = RoomViewerViewController(roomURL: url)
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Context Menu
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {

        let url = currentFile(at: indexPath)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in

            let quickLookAction = UIAction(
                title: "Quick Look",
                image: UIImage(systemName: "eye")
            ) { [weak self] _ in
                self?.quickLook(url: url)
            }

            let renameAction = UIAction(
                title: "Rename",
                image: UIImage(systemName: "pencil")
            ) { [weak self] _ in
                self?.showRenameDialog(for: url, at: indexPath)
            }

            let shareAction = UIAction(
                title: "Share",
                image: UIImage(systemName: "square.and.arrow.up")
            ) { [weak self] _ in
                self?.shareRoom(url: url)
            }

            let deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.confirmDelete(url: url, at: indexPath)
            }

            return UIMenu(
                title: "",
                children: [quickLookAction, renameAction, shareAction, deleteAction]
            )
        }
    }

    func collectionView1(_ collectionView: UICollectionView,
                         contextMenuConfigurationForItemAt indexPath: IndexPath,
                         point: CGPoint) -> UIContextMenuConfiguration? {

        let url = currentFile(at: indexPath)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let renameAction = UIAction(
                title: "Rename",
                image: UIImage(systemName: "pencil")
            ) { [weak self] _ in
                self?.showRenameDialog(for: url, at: indexPath)
            }

            let shareAction = UIAction(
                title: "Share",
                image: UIImage(systemName: "square.and.arrow.up")
            ) { [weak self] _ in
                self?.shareRoom(url: url)
            }

            let deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.confirmDelete(url: url, at: indexPath)
            }

            return UIMenu(title: "", children: [renameAction, shareAction, deleteAction])
        }
    }

    // MARK: - Context Menu Actions

    private func showRenameDialog(for url: URL, at indexPath: IndexPath) {
        let currentName = url.deletingPathExtension().lastPathComponent

        let alert = UIAlertController(
            title: "Rename Room",
            message: "Enter a new name for this room",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.text = currentName
            textField.placeholder = "Room name"
            textField.autocapitalizationType = .words
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self, weak alert] _ in
            guard let newName = alert?.textFields?.first?.text,
                  !newName.trimmingCharacters(in: .whitespaces).isEmpty else {
                return
            }

            self?.performRename(url: url, newName: newName, at: indexPath)
        })

        present(alert, animated: true)
    }

    private func performRename(url: URL, newName: String, at indexPath: IndexPath) {
        let fileManager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let newURL = directory.appendingPathComponent("\(newName).usdz")

        do {
            // Rename the main file
            try fileManager.moveItem(at: url, to: newURL)

            // Rename associated files (thumbnail and metadata)
            let oldBaseName = url.deletingPathExtension().lastPathComponent
            let thumbOldURL = directory.appendingPathComponent("\(oldBaseName)_thumb.jpg")
            let thumbNewURL = directory.appendingPathComponent("\(newName)_thumb.jpg")
            let metaOldURL = directory.appendingPathComponent("\(oldBaseName)_meta.json")
            let metaNewURL = directory.appendingPathComponent("\(newName)_meta.json")

            if fileManager.fileExists(atPath: thumbOldURL.path) {
                try? fileManager.moveItem(at: thumbOldURL, to: thumbNewURL)
            }

            if fileManager.fileExists(atPath: metaOldURL.path) {
                try? fileManager.moveItem(at: metaOldURL, to: metaNewURL)
            }

            // Reload the file list
            loadRoomFiles(from: roomsFolderURL())
            showToast(message: "Renamed to \(newName)")

        } catch {
            let alert = UIAlertController(
                title: "Rename Failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }

    private func shareRoom(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(activityVC, animated: true)
    }

    private func confirmDelete(url: URL, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Delete Room?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDelete(url: url, at: indexPath)
        })

        present(alert, animated: true)
    }

    private func performDelete(url: URL, at indexPath: IndexPath) {
        SaveManager.shared.deleteModel(at: url) { [weak self] success in
            guard let self = self else { return }

            if success {
                self.loadRoomFiles(from: self.roomsFolderURL())
                self.showToast(message: "Room deleted")
            } else {
                let alert = UIAlertController(
                    title: "Delete Failed",
                    message: "Could not delete the room model.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    // Swipe-to-delete
    func collectionView(_ collectionView: UICollectionView,
                        trailingSwipeActionsConfigurationForItemAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {

        let delete = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
            let url = self.currentFile(at: indexPath)
            try? FileManager.default.removeItem(at: url)

            if self.isSearching {
                self.filteredFiles.remove(at: indexPath.item)
                self.roomFiles.removeAll { $0 == url }
            } else {
                self.roomFiles.remove(at: indexPath.item)
            }

            self.thumbnailCache.removeObject(forKey: url as NSURL)
            collectionView.deleteItems(at: [indexPath])
            completion(true)
        }

        return UISwipeActionsConfiguration(actions: [delete])
    }
}

// MARK: - Search
extension MyRoomsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let q = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if q.isEmpty {
            filteredFiles = []
        } else {
            filteredFiles = roomFiles.filter {
                $0.lastPathComponent.localizedCaseInsensitiveContains(q)
            }
        }
        collectionView.reloadData()
    }
}

// quick look
extension MyRoomsViewController: QLPreviewControllerDataSource {

    func quickLook(url: URL) {
        previewURL = url
        let previewController = QLPreviewController()
        previewController.dataSource = self
        present(previewController, animated: true)
    }

    // MARK: - QLPreview Data Source
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return 1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewURL as NSURL
    }
}
