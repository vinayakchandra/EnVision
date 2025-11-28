//
//  ViewModelsViewController.swift
//  Envision
//
//  Created by admin55 on 15/11/25.
//  Upgraded: Import files, search (pull-to-show), swipe-delete, blurred loading overlay,
//  file size metadata, thumbnail caching.
//

import UIKit
import UniformTypeIdentifiers
import QuickLook
import QuickLookThumbnailing

final class ViewModelsViewController: UIViewController {

    // MARK: - UI
    private var collectionView: UICollectionView!
    private var loadingOverlay: UIVisualEffectView!
    private var activityIndicator: UIActivityIndicatorView!
    private var loadingLabel: UILabel!

    // Search controller (hidden until pulled down)
    private let searchController = UISearchController(searchResultsController: nil)

    // MARK: - Data
    private var usdzFiles: [URL] = []                 // master list
    private var filteredFiles: [URL] = []             // search results
    private var isSearching: Bool {
        let text = searchController.searchBar.text ?? ""
        return searchController.isActive && !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var previewURL: URL?
    private var thumbnailCache: NSCache<NSURL, UIImage> = .init()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "View Models"

        setupNavigationBar()
        setupCollectionView()
        setupLoadingOverlay()
        setupSearchController()

        // Load models on startup
        loadUSDZFiles(from: modelsFolderURL())
    }

    // MARK: - Navigation
    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Import Files",
            style: .plain,
            target: self,
            action: #selector(importFilesTapped)
        )

        // Put the search controller on the nav item, but hide until pulled down
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    // MARK: - Search
    func setupSearchController() {
            searchController.searchResultsUpdater = self
            searchController.obscuresBackgroundDuringPresentation = false
            searchController.searchBar.placeholder = "Search models"
            searchController.searchBar.autocapitalizationType = .none
            definesPresentationContext = true
    }


    // MARK: - Models folder
    private func modelsFolderURL() -> URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let models = docs.appendingPathComponent("3D Models", isDirectory: true)
        if !fm.fileExists(atPath: models.path) {
            try? fm.createDirectory(at: models, withIntermediateDirectories: true)
        }
        return models
    }

    // MARK: - Collection View
    private func setupCollectionView() {
        let layout = createGridLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.register(USDZCell.self, forCellWithReuseIdentifier: USDZCell.reuseIdentifier)
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
            item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

            let groupHeight: CGFloat = 180
            let columns = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(groupHeight)
            )

            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
            let section = NSCollectionLayoutSection(group: group)
            return section
        }
    }

    // MARK: - Loading overlay (blur + spinner + label)
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
        loadingLabel.font = UIFont.preferredFont(forTextStyle: .body)
        loadingLabel.textAlignment = .center
        loadingLabel.adjustsFontForContentSizeCategory = true

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

    private func showLoading(message: String? = "Loading…") {
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

    // MARK: - Import Files (.usdz)
    @objc private func importFilesTapped() {
        // Prefer the explicit .usdz UTType; fallback to .item if unknown
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

    // MARK: - Importing logic (copy selected files to app folder)
    private func importSelectedUSDZFiles(_ urls: [URL]) {
        showLoading(message: "Importing files…")
        DispatchQueue.global(qos: .userInitiated).async {
            let destDir = self.modelsFolderURL()
            let fm = FileManager.default

            for u in urls {
                // We only accept files with .usdz extension (defensive)
                guard u.pathExtension.lowercased() == "usdz" else { continue }

                var didStart = false
                if u.startAccessingSecurityScopedResource() {
                    didStart = true
                }

                let dest = destDir.appendingPathComponent(u.lastPathComponent)

                // Overwrite if exists
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }

                do {
                    // If picker provided URL is a file URL we can copy directly
                    try fm.copyItem(at: u, to: dest)
                } catch {
                    // If copy fails, try using coordinated read / write (best-effort)
                    do {
                        let coordinator = NSFileCoordinator()
                        var coordinationError: NSError? = nil
                        coordinator.coordinate(readingItemAt: u, options: [], error: &coordinationError) { (newURL) in
                            try? fm.copyItem(at: newURL, to: dest)
                        }
                    } catch {
                        print("Import copy failed for \(u.lastPathComponent): \(error)")
                    }
                }

                if didStart {
                    u.stopAccessingSecurityScopedResource()
                }
            }

            // Reload from destination folder
            DispatchQueue.main.async {
                self.loadUSDZFiles(from: destDir)
            }
        }
    }

    // MARK: - Loading USDZ File list from folder
    private func loadUSDZFiles(from folderURL: URL) {
        showLoading(message: "Scanning models…")
        DispatchQueue.global(qos: .userInitiated).async {
            var results: [URL] = []
            let fm = FileManager.default

            if let enumerator = fm.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension.lowercased() == "usdz" {
                        results.append(fileURL)
                    }
                }
            }

            // Sort by name
            results.sort { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }

            DispatchQueue.main.async {
                self.usdzFiles = results
                self.thumbnailCache.removeAllObjects()
                self.collectionView.reloadData()
                self.hideLoading()
            }
        }
    }

    // MARK: - Thumbnail generation (cached)
    private func generateThumbnail(for url: URL, size: CGSize = CGSize(width: 400, height: 400), completion: @escaping (UIImage?) -> Void) {

        if let cached = thumbnailCache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: UIScreen.main.scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
            DispatchQueue.main.async {
                if let image = representation?.uiImage {
                    self.thumbnailCache.setObject(image, forKey: url as NSURL)
                    completion(image)
                } else {
                    // fallback placeholder
                    completion(nil)
                }
            }
        }
    }

    // MARK: - Helpers
    private func fileSizeString(for url: URL) -> String {
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? NSNumber {
            let byteCount = size.int64Value
            let fmt = ByteCountFormatter()
            fmt.countStyle = .file
            return fmt.string(fromByteCount: byteCount)
        }
        return "--"
    }
}

// MARK: - UIDocumentPickerDelegate
extension ViewModelsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // Filter only .usdz
        let usdzURLs = urls.filter { $0.pathExtension.lowercased() == "usdz" }
        guard !usdzURLs.isEmpty else { return }
        importSelectedUSDZFiles(usdzURLs)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // no-op
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension ViewModelsViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    private func modelURL(at indexPath: IndexPath) -> URL {
        return isSearching ? filteredFiles[indexPath.item] : usdzFiles[indexPath.item]
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return isSearching ? filteredFiles.count : usdzFiles.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: USDZCell.reuseIdentifier,
                                                            for: indexPath) as? USDZCell else {
            return UICollectionViewCell()
        }

        let url = modelURL(at: indexPath)
        let name = url.lastPathComponent
        let sizeText = fileSizeString(for: url)
        cell.configure(name: name, sizeText: sizeText, thumbnail: nil)

        // Generate thumbnail asynchronously
        generateThumbnail(for: url) { image in
            // Ensure the cell is still visible for that indexPath (avoid mismatched cells)
            if let visibleCell = collectionView.cellForItem(at: indexPath) as? USDZCell {
                visibleCell.configure(name: name, sizeText: sizeText, thumbnail: image)
            }
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        previewURL = modelURL(at: indexPath)
        let preview = QLPreviewController()
        preview.dataSource = self
        present(preview, animated: true)
    }

    // Swipe-to-delete (trailing action)
    func collectionView(_ collectionView: UICollectionView,
                        trailingSwipeActionsConfigurationForItemAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] action, view, completion in
            guard let self = self else {
                completion(false)
                return
            }

            let url = self.modelURL(at: indexPath)
            let fm = FileManager.default
            do {
                try fm.removeItem(at: url)
            } catch {
                print("Delete failed: \(error)")
                completion(false)
                return
            }

            // Update data sources
            if self.isSearching {
                // Remove from master and filtered
                if let masterIndex = self.usdzFiles.firstIndex(of: url) {
                    self.usdzFiles.remove(at: masterIndex)
                }
                self.filteredFiles.remove(at: indexPath.item)
            } else {
                self.usdzFiles.remove(at: indexPath.item)
            }
            self.thumbnailCache.removeObject(forKey: url as NSURL)
            collectionView.deleteItems(at: [indexPath])
            completion(true)
        }

        delete.backgroundColor = .systemRed
        let config = UISwipeActionsConfiguration(actions: [delete])
        config.performsFirstActionWithFullSwipe = true
        return config
    }
}

// MARK: - QLPreviewControllerDataSource
extension ViewModelsViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewURL! as QLPreviewItem
    }
}

// MARK: - UISearchResultsUpdating
extension ViewModelsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let q = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if q.isEmpty {
            filteredFiles = []
        } else {
            filteredFiles = usdzFiles.filter { $0.lastPathComponent.localizedCaseInsensitiveContains(q) }
        }
        collectionView.reloadData()
    }
}
