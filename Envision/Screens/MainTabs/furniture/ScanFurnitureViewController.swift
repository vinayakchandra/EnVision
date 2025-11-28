//
//  ScanFurnitureViewController.swift
//  Envision
//
//  Furniture library with thumbnail grid (similar to My Rooms)
//

import UIKit
import QuickLook
import QuickLookThumbnailing
import UniformTypeIdentifiers
import ARKit

final class ScanFurnitureViewController: UIViewController {

    // MARK: - UI
    private var collectionView: UICollectionView!
    private var loadingOverlay: UIVisualEffectView!
    private var activityIndicator: UIActivityIndicatorView!
    private var loadingLabel: UILabel!
    private var emptyStateView: UIView!

    private let searchController = UISearchController(searchResultsController: nil)

    // MARK: - Data
    private var furnitureFiles: [URL] = []
    private var filteredFiles: [URL] = []
    
    private var isSearching: Bool {
        let text = searchController.searchBar.text ?? ""
        return searchController.isActive && !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var previewURL: URL?
    private let thumbnailCache: NSCache<NSURL, UIImage> = .init()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "My Furnitures"
        navigationController?.navigationBar.prefersLargeTitles = true

        setupNavigationBar()
        setupSearchController()
        setupCollectionView()
        setupLoadingOverlay()
        setupEmptyState()

        loadFurnitureFiles(from: furnitureFolderURL())
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reload when returning from capture
        loadFurnitureFiles(from: furnitureFolderURL())
    }

    // MARK: - Navigation Bar
    private func setupNavigationBar() {
        // Right buttons: Scan + Import
        let scanMenu = UIMenu(children: [
            UIAction(title: "Automatic Object Capture",
                     image: UIImage(systemName: "camera.metering.center.weighted")) { _ in
                self.automaticCaptureTapped()
            },
            UIAction(title: "Create From Photos",
                     image: UIImage(systemName: "photo.on.rectangle.angled")) { _ in
                self.createFromPhotosTapped()
            }
        ])
        
        let scanBtn = UIBarButtonItem(
            image: UIImage(systemName: "camera.viewfinder"),
            menu: scanMenu
        )
        scanBtn.tintColor = .systemGreen
        
        let importBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(importUSDZTapped)
        )
        importBtn.tintColor = .systemBlue
        
        navigationItem.rightBarButtonItems = [scanBtn, importBtn]
        
        // Left button: Edit menu
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
            
            UIAction(title: "Room Geometry Playground",
                     image: UIImage(systemName: "arkit")) { [weak self] _ in
                self?.showARViewController()
            },
            UIAction(title: "Room with replaced Furniture",
                     image: UIImage(systemName: "arkit")) { [weak self] _ in
                self?.showRoomWithFurniture()
            }
        ])
    }
    
    @objc private func showARViewController() {
        let arVC = VisualizeRoomViewController()
        navigationController?.pushViewController(arVC, animated: true)
    }    
    @objc private func showRoomWithFurniture() {
        let arVC = RoomARWithFurnitureViewController()
        navigationController?.pushViewController(arVC, animated: true)
    }
    
    // MARK: - Menu Actions
    @objc private func enableMultipleSelection() {
        collectionView.allowsMultipleSelection = true
        
        let doneBtn = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(disableMultipleSelection))
        let deleteBtn = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(deleteSelectedModels))
        deleteBtn.tintColor = .systemRed
        
        navigationItem.leftBarButtonItem = doneBtn
        navigationItem.rightBarButtonItems = [deleteBtn]
    }
    
    @objc private func disableMultipleSelection() {
        collectionView.allowsMultipleSelection = false
        
        // Deselect all
        if let selected = collectionView.indexPathsForSelectedItems {
            for indexPath in selected {
                collectionView.deselectItem(at: indexPath, animated: true)
            }
        }
        
        setupNavigationBar()
    }
    
    @objc private func deleteSelectedModels() {
        guard let selected = collectionView.indexPathsForSelectedItems, !selected.isEmpty else {
            showToast(message: "No models selected")
            return
        }
        
        let alert = UIAlertController(
            title: "Delete \(selected.count) Model(s)?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDeleteSelected(selected)
        })
        
        present(alert, animated: true)
    }
    
    private func performDeleteSelected(_ indexPaths: [IndexPath]) {
        let sortedPaths = indexPaths.sorted { $0.item > $1.item }
        
        for indexPath in sortedPaths {
            let url = modelURL(at: indexPath)
            
            // Use SaveManager to properly delete with metadata and thumbnail
            SaveManager.shared.deleteModel(at: url) { success in
                if success {
                    self.thumbnailCache.removeObject(forKey: url as NSURL)
                }
            }
            
            if isSearching {
                if let masterIndex = furnitureFiles.firstIndex(of: url) {
                    furnitureFiles.remove(at: masterIndex)
                }
                filteredFiles.remove(at: indexPath.item)
            } else {
                furnitureFiles.remove(at: indexPath.item)
            }
        }
        
        collectionView.deleteItems(at: sortedPaths)
        disableMultipleSelection()
        showToast(message: "✓ Deleted \(sortedPaths.count) model(s)")
        updateEmptyState()
    }
    
    private func confirmDeleteAll() {
        guard !furnitureFiles.isEmpty else {
            showToast(message: "No models to delete")
            return
        }
        
        let alert = UIAlertController(
            title: "Delete All Models?",
            message: "This will permanently delete all \(furnitureFiles.count) furniture models.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete All", style: .destructive) { [weak self] _ in
            self?.performDeleteAll()
        })
        
        present(alert, animated: true)
    }
    
    private func performDeleteAll() {
        for url in furnitureFiles {
            SaveManager.shared.deleteModel(at: url) { _ in }
        }
        
        furnitureFiles.removeAll()
        filteredFiles.removeAll()
        thumbnailCache.removeAllObjects()
        collectionView.reloadData()
        showToast(message: "✓ All models deleted")
        updateEmptyState()
    }

    // MARK: - Search
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search models"
        searchController.searchBar.autocapitalizationType = .none
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true
    }

    // MARK: - Furniture Folder
    private func furnitureFolderURL() -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("furniture", isDirectory: true)
        if !fm.fileExists(atPath: folder.path) {
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    // MARK: - Collection View
    private func setupCollectionView() {
        let layout = createGridLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.register(FurnitureCell.self, forCellWithReuseIdentifier: FurnitureCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self

        view.addSubview(collectionView)
    }

    private func createGridLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

            let groupHeight: CGFloat = 200
            let columns = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(groupHeight)
            )

            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
            return section
        }
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
        activityIndicator.hidesWhenStopped = true

        loadingLabel = UILabel()
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.text = "Loading…"
        loadingLabel.font = .preferredFont(forTextStyle: .body)
        loadingLabel.textAlignment = .center

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

            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 12),
            loadingLabel.leadingAnchor.constraint(equalTo: loadingOverlay.contentView.leadingAnchor, constant: 12),
            loadingLabel.trailingAnchor.constraint(equalTo: loadingOverlay.contentView.trailingAnchor, constant: -12)
        ])
    }

    private func showLoading(message: String = "Loading…") {
        DispatchQueue.main.async {
            self.loadingLabel.text = message
            self.loadingOverlay.isHidden = false
            self.activityIndicator.startAnimating()
            self.view.isUserInteractionEnabled = false
        }
    }

    private func hideLoading() {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            self.loadingOverlay.isHidden = true
            self.view.isUserInteractionEnabled = true
        }
    }

    // MARK: - Empty State
    private func setupEmptyState() {
        emptyStateView = UIView()
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: "cube")
        iconView.tintColor = .systemGray3
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "No 3D Models Yet"
        titleLabel.font = .boldSystemFont(ofSize: 22)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let messageLabel = UILabel()
        messageLabel.text = "Tap the camera icon to scan furniture\nor import USDZ files"
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
        emptyStateView.isHidden = !furnitureFiles.isEmpty
    }

    // MARK: - Load Files
    private func loadFurnitureFiles(from folderURL: URL) {
        showLoading(message: "Scanning models…")
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [URL] = []
            let fm = FileManager.default

            if let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension.lowercased() == "usdz" {
                        results.append(fileURL)
                    }
                }
            }

            // Sort by date (newest first)
            results.sort { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }

            DispatchQueue.main.async {
                self.furnitureFiles = results
                self.collectionView.reloadData()
                self.hideLoading()
                self.updateEmptyState()
            }
        }
    }

    // MARK: - Thumbnails
    private func generateThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
        if let cached = thumbnailCache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 400, height: 400),
            scale: UIScreen.main.scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
            DispatchQueue.main.async {
                if let image = representation?.uiImage {
                    self.thumbnailCache.setObject(image, forKey: url as NSURL)
                    completion(image)
                } else {
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Actions
    
    private func automaticCaptureTapped() {
        let vc = ObjectScanViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    private func createFromPhotosTapped() {
        let vc = CreateModelViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func importUSDZTapped() {
        var contentTypes: [UTType] = []
        if let usdzType = UTType(filenameExtension: "usdz") {
            contentTypes = [usdzType]
        } else {
            contentTypes = [.item]
        }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = true
        present(picker, animated: true)
    }

    // MARK: - Helpers
    
    private func modelURL(at indexPath: IndexPath) -> URL {
        return isSearching ? filteredFiles[indexPath.item] : furnitureFiles[indexPath.item]
    }
    
    private func fileSizeString(for url: URL) -> String {
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? NSNumber {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size.int64Value)
        }
        return "--"
    }
    
    private func fileDateString(for url: URL) -> String {
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
    
    private func showToast(message: String) {
        let toast = UIView()
        toast.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.95)
        toast.layer.cornerRadius = 12
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        toast.addSubview(label)
        view.addSubview(toast)
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.heightAnchor.constraint(equalToConstant: 50),
            
            label.topAnchor.constraint(equalTo: toast.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: toast.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: toast.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: toast.trailingAnchor, constant: -20)
        ])
        
        toast.alpha = 0
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
}

// MARK: - UICollectionViewDataSource
extension ScanFurnitureViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isSearching ? filteredFiles.count : furnitureFiles.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FurnitureCell.reuseIdentifier, for: indexPath) as? FurnitureCell else {
            return UICollectionViewCell()
        }

        let url = modelURL(at: indexPath)
        let name = url.deletingPathExtension().lastPathComponent
        let sizeText = fileSizeString(for: url)
        let dateText = fileDateString(for: url)
        cell.configure(name: name, sizeText: sizeText, dateText: dateText, thumbnail: nil)

        // Generate thumbnail asynchronously
        generateThumbnail(for: url) { image in
            if let visibleCell = collectionView.cellForItem(at: indexPath) as? FurnitureCell {
                visibleCell.configure(name: name, sizeText: sizeText, dateText: dateText, thumbnail: image)
            }
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension ScanFurnitureViewController: UICollectionViewDelegate {
    func collectionView1(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.allowsMultipleSelection {
            // In selection mode, just update UI
            return
        }
        
        // Single tap - show QuickLook preview with AR option
        previewURL = modelURL(at: indexPath)
        let preview = QLPreviewController()
        preview.dataSource = self
        present(preview, animated: true)
    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let url = modelURL(at: indexPath)
        let arVC = MultiModelARViewController()
//        arVC.loadModel(named: url)
        arVC.loadModel(named: url.lastPathComponent)

        navigationController?.pushViewController(arVC, animated: true)
    }

    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let url = modelURL(at: indexPath)
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let rename = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { _ in
                self.renameModel(at: indexPath, url: url)
            }
            
            let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                self.shareModel(url: url)
            }
            
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.deleteModel(at: indexPath, url: url)
            }
            
            return UIMenu(children: [rename, share, delete])
        }
    }
    
    private func renameModel(at indexPath: IndexPath, url: URL) {
        let alert = UIAlertController(title: "Rename Model", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = url.deletingPathExtension().lastPathComponent
            textField.placeholder = "Model name"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Rename", style: .default) { [weak self] _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            self?.performRename(at: indexPath, url: url, newName: newName)
        })
        
        present(alert, animated: true)
    }
    
    private func performRename(at indexPath: IndexPath, url: URL, newName: String) {
        let fm = FileManager.default
        let newURL = url.deletingLastPathComponent().appendingPathComponent("\(newName).usdz")
        
        do {
            try fm.moveItem(at: url, to: newURL)
            
            if isSearching {
                if let masterIndex = furnitureFiles.firstIndex(of: url) {
                    furnitureFiles[masterIndex] = newURL
                }
                filteredFiles[indexPath.item] = newURL
            } else {
                furnitureFiles[indexPath.item] = newURL
            }
            
            collectionView.reloadItems(at: [indexPath])
            showToast(message: "✓ Renamed to \(newName)")
        } catch {
            print("❌ Rename failed: \(error)")
        }
    }
    
    private func shareModel(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        present(activityVC, animated: true)
    }
    
    private func deleteModel(at indexPath: IndexPath, url: URL) {
        let alert = UIAlertController(
            title: "Delete Model?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            SaveManager.shared.deleteModel(at: url) { success in
                if success {
                    self.thumbnailCache.removeObject(forKey: url as NSURL)
                    
                    if self.isSearching {
                        if let masterIndex = self.furnitureFiles.firstIndex(of: url) {
                            self.furnitureFiles.remove(at: masterIndex)
                        }
                        self.filteredFiles.remove(at: indexPath.item)
                    } else {
                        self.furnitureFiles.remove(at: indexPath.item)
                    }
                    
                    self.collectionView.deleteItems(at: [indexPath])
                    self.showToast(message: "✓ Model deleted")
                    self.updateEmptyState()
                }
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UISearchResultsUpdating
extension ScanFurnitureViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if query.isEmpty {
            filteredFiles = []
        } else {
            filteredFiles = furnitureFiles.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(query) }
        }
        collectionView.reloadData()
    }
}

// MARK: - QLPreviewControllerDataSource
extension ScanFurnitureViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewURL! as QLPreviewItem
    }
}

// MARK: - UIDocumentPickerDelegate
extension ScanFurnitureViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let usdzURLs = urls.filter { $0.pathExtension.lowercased() == "usdz" }
        guard !usdzURLs.isEmpty else { return }
        
        showLoading(message: "Importing files…")
        
        DispatchQueue.global(qos: .userInitiated).async {
            let destDir = self.furnitureFolderURL()
            let fm = FileManager.default
            var imported = 0
            
            for url in usdzURLs {
                var didStart = false
                if url.startAccessingSecurityScopedResource() {
                    didStart = true
                }
                
                let dest = destDir.appendingPathComponent(url.lastPathComponent)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }
                
                do {
                    try fm.copyItem(at: url, to: dest)
                    imported += 1
                } catch {
                    print("❌ Import failed: \(error)")
                }
                
                if didStart {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            DispatchQueue.main.async {
                self.loadFurnitureFiles(from: destDir)
                self.showToast(message: "✓ Imported \(imported) model(s)")
            }
        }
    }
}
