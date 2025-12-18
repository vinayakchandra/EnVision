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
    private var refreshControl: UIRefreshControl! // refresh

    // MARK: - Filter State
    private var selectedCategory: FurnitureCategory? = nil

    private struct ChipData {
        let title: String
        let icon: String
        let category: FurnitureCategory?
        let color: UIColor
    }

    private var allChipsData: [ChipData] {
        var chips: [ChipData] = [
            ChipData(title: "All (\(furnitureFiles.count))", icon: "square.grid.2x2", category: nil, color: .systemIndigo)
        ]
        for cat in FurnitureCategory.allCases {
            chips.append(ChipData(title: cat.rawValue, icon: cat.icon, category: cat, color: cat.color))
        }
        return chips
    }

    private var displayFiles: [URL] {
        var files = isSearching ? filteredFiles : furnitureFiles
        if let category = selectedCategory {
            files = files.filter { getCategoryForURL($0) == category }
        }
        return files
    }

    private func getCategoryForURL(_ url: URL) -> FurnitureCategory {
        // Check UserDefaults for saved category
        let key = "furniture_category_\(url.lastPathComponent)"
        if let savedCategory = UserDefaults.standard.string(forKey: key),
           let category = FurnitureCategory(rawValue: savedCategory) {
            return category
        }
        return inferCategory(from: url.deletingPathExtension().lastPathComponent)
    }

    private func inferCategory(from name: String) -> FurnitureCategory {
        let lowercased = name.lowercased()
        if lowercased.contains("chair") || lowercased.contains("sofa") || lowercased.contains("couch") || lowercased.contains("seat") {
            return .seating
        } else if lowercased.contains("table") || lowercased.contains("desk") {
            return .tables
        } else if lowercased.contains("cabinet") || lowercased.contains("shelf") || lowercased.contains("drawer") {
            return .storage
        } else if lowercased.contains("bed") || lowercased.contains("mattress") {
            return .beds
        } else if lowercased.contains("lamp") || lowercased.contains("light") {
            return .lighting
        } else if lowercased.contains("vase") || lowercased.contains("art") || lowercased.contains("decor") || lowercased.contains("plant") {
            return .decor
        } else if lowercased.contains("fridge") || lowercased.contains("oven") || lowercased.contains("stove") {
            return .kitchen
        } else if lowercased.contains("outdoor") || lowercased.contains("patio") || lowercased.contains("garden") {
            return .outdoor
        } else if lowercased.contains("office") || lowercased.contains("computer") {
            return .office
        } else if lowercased.contains("tv") || lowercased.contains("speaker") {
            return .electronics
        }
        return .other
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "My Furniture"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        setupNavigationBar()
        setupSearchController()
        setupCollectionView()
        setupRefreshControl()
        setupLoadingOverlay()
        setupEmptyState()

        loadFurnitureFiles(from: furnitureFolderURL())
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure large title is restored when coming back from other screens
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        // Reload when returning from capture
        loadFurnitureFiles(from: furnitureFolderURL())
    }

    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    @objc private func handleRefresh() {
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
        let sortedPaths = indexPaths.sorted {
            $0.item > $1.item
        }

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
            SaveManager.shared.deleteModel(at: url) { _ in
            }
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
        let layout = createCompositionalLayout()
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .systemBackground
        collectionView.register(FurnitureCell.self, forCellWithReuseIdentifier: FurnitureCell.reuseIdentifier)
        collectionView.register(FurnitureChipCell.self, forCellWithReuseIdentifier: FurnitureChipCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self

        view.addSubview(collectionView)
    }

    private func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            if sectionIndex == 0 {
                return self?.makeChipsSection()
            } else {
                return self?.makeFurnitureSection()
            }
        }
    }

    private func makeChipsSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .estimated(100),
            heightDimension: .absolute(32)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .estimated(100),
            heightDimension: .absolute(32)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        return section
    }

    private func makeFurnitureSection() -> NSCollectionLayoutSection {
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
        if refreshControl == nil || !refreshControl.isRefreshing {
            showLoading(message: "Scanning models…")
        }
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

                // IMPORTANT: Use reloadSections or reloadData without clearing cache
                // The cache is now used in cellForItemAt, so it won't be empty
                self.collectionView.reloadData()

                self.hideLoading()
                self.updateEmptyState()

                // End refreshing animation
                if self.refreshControl.isRefreshing {
                    self.refreshControl.endRefreshing()
                }
            }
        }
    }

//  method to clear cache only when explicitly needed (e.g., Delete All):
    private func clearThumbnailCache() {
        thumbnailCache.removeAllObjects()
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
        return displayFiles[indexPath.item]
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
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return allChipsData.count
        }
        return displayFiles.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FurnitureChipCell.reuseIdentifier, for: indexPath) as? FurnitureChipCell else {
                return UICollectionViewCell()
            }
            let chip = allChipsData[indexPath.item]
            let isSelected = (chip.category == selectedCategory)
            cell.configure(title: chip.title, icon: chip.icon, color: chip.color, isSelected: isSelected)
            cell.button.addTarget(self, action: #selector(chipButtonTapped(_:)), for: .touchUpInside)
            return cell
        }

        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FurnitureCell.reuseIdentifier, for: indexPath) as? FurnitureCell else {
            return UICollectionViewCell()
        }

        let url = modelURL(at: indexPath)
        let name = url.deletingPathExtension().lastPathComponent
        let sizeText = fileSizeString(for: url)
        let dateText = fileDateString(for: url)

        // Check cache first and use cached thumbnail immediately
        if let cachedImage = thumbnailCache.object(forKey: url as NSURL) {
            cell.configure(name: name, sizeText: sizeText, dateText: dateText, thumbnail: cachedImage)
        } else {
            cell.configure(name: name, sizeText: sizeText, dateText: dateText, thumbnail: nil)
        }

        // Always try to generate/refresh thumbnail asynchronously
        generateThumbnail(for: url) { image in
            // Only update if this cell is still visible and represents the same URL
            if let visibleCell = collectionView.cellForItem(at: indexPath) as? FurnitureCell,
               self.modelURL(at: indexPath) == url {
                visibleCell.configure(name: name, sizeText: sizeText, dateText: dateText, thumbnail: image)
            }
        }

        return cell
    }

}

// MARK: - UICollectionViewDelegate
extension ScanFurnitureViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Section 0: Chip selection
        if indexPath.section == 0 {
            chipTapped(at: indexPath.item)
            return
        }

        // Section 1: Furniture selection
        let url = modelURL(at: indexPath)
        self.showQuickLook(url: url)
    }

    @objc private func chipButtonTapped(_ sender: UIButton) {
        guard let cell = sender.superview?.superview as? FurnitureChipCell,
              let indexPath = collectionView.indexPath(for: cell) else { return }
        chipTapped(at: indexPath.item)
    }
    private func chipTapped(at index: Int) {
        let chip = allChipsData[index]

        // Add press animation
        if let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? FurnitureChipCell {
            UIView.animate(withDuration: 0.1, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    cell.transform = .identity
                }
            }
        }

        selectedCategory = chip.category

        // Animate filter change
        UIView.transition(with: collectionView, duration: 0.25, options: .transitionCrossDissolve) {
            self.collectionView.reloadData()
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        // No context menu for chips
        guard indexPath.section == 1 else { return nil }

        let url = modelURL(at: indexPath)

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let quickLook = UIAction(title: "Quick Look", image: UIImage(systemName: "eye")) { _ in
                self?.showQuickLook(url: url)
            }

            let edit = UIAction(title: "Edit Model", image: UIImage(systemName: "pencil")) { _ in
                self?.renameModel(at: indexPath, url: url)
            }

            let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                self?.shareModel(url: url)
            }

            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self?.deleteModel(at: indexPath, url: url)
            }

            return UIMenu(children: [quickLook, edit, share, delete])
        }
    }

    private func showQuickLook(url: URL) {
        previewURL = url
        let preview = QLPreviewController()
        preview.dataSource = self
        present(preview, animated: true)
    }

    private func renameModel(at indexPath: IndexPath, url: URL) {
        let currentName = url.deletingPathExtension().lastPathComponent
        let currentCategory = getCategoryForURL(url)

        let alert = UIAlertController(title: "Edit Model", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = currentName
            textField.placeholder = "Model name"
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Change Category", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let newName = alert.textFields?.first?.text ?? currentName
            self.showCategoryPicker(for: url, currentCategory: currentCategory, newName: newName, indexPath: indexPath)
        })

        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else {
                return
            }
            self?.performRename(at: indexPath, url: url, newName: newName)
        })

        present(alert, animated: true)
    }

    private func showCategoryPicker(for url: URL, currentCategory: FurnitureCategory, newName: String, indexPath: IndexPath) {
        let alert = UIAlertController(title: "Select Category", message: "Current: \(currentCategory.rawValue)", preferredStyle: .actionSheet)

        for category in FurnitureCategory.allCases {
            let checkmark = category == currentCategory ? " ✓" : ""
            alert.addAction(UIAlertAction(title: "\(category.rawValue)\(checkmark)", style: .default) { [weak self] _ in
                self?.saveCategoryForModel(url: url, category: category, newName: newName, indexPath: indexPath)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func saveCategoryForModel(url: URL, category: FurnitureCategory, newName: String, indexPath: IndexPath) {
        // Save category to UserDefaults using file name as key
        let key = "furniture_category_\(url.lastPathComponent)"
        UserDefaults.standard.set(category.rawValue, forKey: key)

        // Rename if name changed
        let currentName = url.deletingPathExtension().lastPathComponent
        if newName != currentName && !newName.isEmpty {
            performRename(at: indexPath, url: url, newName: newName)
        } else {
            collectionView.reloadItems(at: [indexPath])
            showToast(message: "✓ Category updated to \(category.rawValue)")
        }
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
            guard let self = self else {
                return
            }

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
            filteredFiles = furnitureFiles.filter {
                $0.lastPathComponent.localizedCaseInsensitiveContains(query)
            }
        }
        collectionView.reloadData()
    }
}

// MARK: - QLPreviewControllerDataSource
extension ScanFurnitureViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return previewURL! as QLPreviewItem
    }
}

// MARK: - UIDocumentPickerDelegate
extension ScanFurnitureViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let usdzURLs = urls.filter {
            $0.pathExtension.lowercased() == "usdz"
        }
        guard !usdzURLs.isEmpty else {
            return
        }

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

// MARK: - FurnitureChipCell
// MARK: - FurnitureChipCell
final class FurnitureChipCell: UICollectionViewCell {
    static let reuseIdentifier = "FurnitureChipCell"

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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, icon: String, color: UIColor, isSelected: Bool) {
        button.backgroundColor = isSelected ? color : color.withAlphaComponent(0.1)
        button.tintColor = isSelected ? .white : color

        let attachment = NSTextAttachment()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        attachment.image = UIImage(systemName: icon, withConfiguration: config)?.withTintColor(button.tintColor, renderingMode: .alwaysOriginal)

        let attributedString = NSMutableAttributedString(attachment: attachment)
        attributedString.append(NSAttributedString(string: "  \(title)", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: button.tintColor as Any
        ]))

        button.setAttributedTitle(attributedString, for: .normal)
    }
}
