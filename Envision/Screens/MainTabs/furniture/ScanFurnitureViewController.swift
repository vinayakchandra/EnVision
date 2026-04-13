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
    private let tipContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        return view
    }()
    private var tipContainerBottomConstraint: NSLayoutConstraint?
    private var displayedTipID: String?
    private var scanBarButtonItem: UIBarButtonItem?
    private var importBarButtonItem: UIBarButtonItem?

    private let searchController = UISearchController(searchResultsController: nil)

    // MARK: - Data
    private var furnitureFiles: [URL] = []
    private var filteredFiles: [URL] = []

    private var isSearching: Bool {
        let text = searchController.searchBar.text ?? ""
        return searchController.isActive && !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var previewURL: URL?
    private let thumbnailCache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024
        return cache
    }()
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
        setupTipContainer()

        loadFurnitureFiles(from: furnitureFolderURL())
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTourDidStart),
            name: .tourDidStart,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFurnitureTourShouldStart),
            name: .furnitureTourShouldStart,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .tourDidStart, object: nil)
        NotificationCenter.default.removeObserver(self, name: .furnitureTourShouldStart, object: nil)
    }

    @objc private func handleTourDidStart() {
        showContextualTips()
    }

    @objc private func handleFurnitureTourShouldStart() {
        showContextualTips()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure large title is restored when coming back from other screens
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        // Reload when returning from capture
        loadFurnitureFiles(from: furnitureFolderURL())
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

        scanBarButtonItem = scanBtn
        importBarButtonItem = importBtn
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
            //
            // UIAction(title: "Room Geometry Playground",
            //          image: UIImage(systemName: "arkit")) { [weak self] _ in
            //     self?.showARViewController()
            // },
            // UIAction(title: "Room with replaced Furniture",
            //          image: UIImage(systemName: "arkit")) { [weak self] _ in
            //     self?.showRoomWithFurniture()
            // }
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
        HapticsManager.shared.selection()
        TipCoordinator.shared.dismissTip(from: tipContainerView)
        collectionView.allowsMultipleSelection = true

        let doneBtn = UIBarButtonItem(title: "Done", style: .prominent, target: self, action: #selector(disableMultipleSelection))
        let deleteBtn = UIBarButtonItem(image: UIImage(systemName: "trash"), style: .plain, target: self, action: #selector(deleteSelectedModels))
        deleteBtn.tintColor = .systemRed

        navigationItem.leftBarButtonItem = doneBtn
        navigationItem.rightBarButtonItems = [deleteBtn]
    }

    @objc private func disableMultipleSelection() {
        HapticsManager.shared.selection()
        collectionView.allowsMultipleSelection = false

        // Deselect all
        if let selected = collectionView.indexPathsForSelectedItems {
            for indexPath in selected {
                collectionView.deselectItem(at: indexPath, animated: true)
            }
        }

        setupNavigationBar()
        showContextualTips()
    }

    @objc private func deleteSelectedModels() {
        guard let selected = collectionView.indexPathsForSelectedItems, !selected.isEmpty else {
            HapticsManager.shared.warning()
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
        HapticsManager.shared.success()
        showToast(message: "✓ Deleted \(sortedPaths.count) model(s)")
        updateEmptyState()
    }

    private func confirmDeleteAll() {
        guard !furnitureFiles.isEmpty else {
            HapticsManager.shared.warning()
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
        HapticsManager.shared.success()
        showToast(message: "✓ All models deleted")
        updateEmptyState()
    }

    // MARK: - Search
    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search models"
        searchController.searchBar.autocapitalizationType = .none
        // Search handled by the dedicated Search tab — not added to nav bar
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
        return UICollectionViewCompositionalLayout { [weak self] sectionIndex, layoutEnvironment in
            if sectionIndex == 0 {
                return self?.makeChipsSection()
            } else {
                return self?.makeFurnitureSection(layoutEnvironment: layoutEnvironment)
            }
        }
    }

    private func makeChipsSection() -> NSCollectionLayoutSection {
        let chipHeight: CGFloat = 30
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .estimated(150),
            heightDimension: .absolute(chipHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .estimated(150),
            heightDimension: .absolute(chipHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        return section
    }

    private func makeFurnitureSection(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let columns = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
        let sectionHorizontalInset: CGFloat = 16
        let itemSpacing: CGFloat = 12
        let availableWidth = layoutEnvironment.container.effectiveContentSize.width - (sectionHorizontalInset * 2) - (itemSpacing * CGFloat(columns - 1))
        let itemWidth = floor(max(120, availableWidth / CGFloat(columns)))
        let itemHeight = floor(itemWidth * 1.02) // square-ish card with a little room for metadata

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(itemWidth),
            heightDimension: .absolute(itemHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(itemHeight)
        )

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            repeatingSubitem: item,
            count: columns
        )
        group.interItemSpacing = .fixed(itemSpacing)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = itemSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: sectionHorizontalInset, bottom: 8, trailing: sectionHorizontalInset)
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

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: columns
            )
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
                                        loadingOverlay.widthAnchor.constraint(equalToConstant: UIDevice.current.userInterfaceIdiom == .pad ? 260 : 220),
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
                self.showContextualTips()

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
            scale: traitCollection.displayScale,
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

        let activeTipSequence = activeFurnitureTipSequence()

        if collectionView.allowsMultipleSelection {
            TipCoordinator.shared.dismissTip(from: tipContainerView)
            updateCollectionInsetsForTip(height: 0)
            displayedTipID = nil
            return
        }

        guard let tip = firstUnseen(from: activeTipSequence) else {
            TipCoordinator.shared.dismissTip(from: tipContainerView)
            updateCollectionInsetsForTip(height: 0)
            displayedTipID = nil
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

    private func activeFurnitureTipSequence() -> [TipDefinition] {
        if furnitureFiles.isEmpty {
            return [
                AppTips.furnitureIntro,
                AppTips.furnitureAutomaticCapture,
                AppTips.furnitureFromPhotos,
                AppTips.furnitureImportUSDZ
            ]
        }
        return [
            AppTips.furnitureQuality,
            AppTips.furniturePhotoCount,
            AppTips.furnitureLongPress,
            AppTips.furnitureCategories
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

        let config = TipBubbleView.Configuration(
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
            configuration: config,
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
        case AppTips.furnitureIntro.id, AppTips.furnitureAutomaticCapture.id:
            return placement(pointingTo: viewForRightBarButton(at: 0), edge: .top)
        case AppTips.furnitureImportUSDZ.id:
            return placement(pointingTo: viewForRightBarButton(at: 1), edge: .top)
        case AppTips.furnitureFromPhotos.id:
            return placement(pointingTo: viewForRightBarButton(at: 0), edge: .top)
        case AppTips.furnitureCategories.id:
            return placement(pointingTo: firstChipCell(), edge: .bottom)
        case AppTips.furnitureQuality.id, AppTips.furniturePhotoCount.id, AppTips.furnitureLongPress.id:
            return placement(pointingTo: firstFurnitureCell(), edge: .bottom)
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

    private func firstChipCell() -> UIView? {
        collectionView.cellForItem(at: IndexPath(item: 0, section: 0))
    }

    private func firstFurnitureCell() -> UIView? {
        let firstVisibleFurniture = collectionView.indexPathsForVisibleItems
            .filter { $0.section == 1 }
            .sorted()
            .first
        guard let firstVisibleFurniture else { return nil }
        return collectionView.cellForItem(at: firstVisibleFurniture)
    }

    private func reestablishZeroHeightConstraint() {
        guard tipContainerBottomConstraint == nil else { return }
        tipContainerBottomConstraint = tipContainerView.bottomAnchor.constraint(equalTo: tipContainerView.topAnchor)
        tipContainerBottomConstraint?.priority = .required
        tipContainerBottomConstraint?.isActive = true
    }

    private func updateCollectionInsetsForTip(height: CGFloat) {
        var inset = collectionView.contentInset
        guard abs(inset.top - height) > 0.5 else { return }
        inset.top = max(0, height)
        collectionView.contentInset = inset
        collectionView.scrollIndicatorInsets = inset
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
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard indexPath.section == 1 else { return true }

        // In normal mode, open Quick Look directly without entering selected state.
        if !collectionView.allowsMultipleSelection {
            showQuickLook(url: modelURL(at: indexPath))
            return false
        }

        // In multi-select mode, keep standard selection behavior.
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Section 0: Chip selection
        if indexPath.section == 0 {
            chipTapped(at: indexPath.item)
            return
        }

        // Section 1: Only select in multi-select mode.
        guard collectionView.allowsMultipleSelection else { return }
    }

    @objc private func chipButtonTapped(_ sender: UIButton) {
        guard let cell = sender.superview?.superview as? FurnitureChipCell,
              let indexPath = collectionView.indexPath(for: cell) else { return }
        chipTapped(at: indexPath.item)
    }
    private func chipTapped(at index: Int) {
        HapticsManager.shared.selection()
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
        HapticsManager.shared.impactLight()
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
            HapticsManager.shared.success()
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
            HapticsManager.shared.success()
            showToast(message: "✓ Renamed to \(newName)")
        } catch {
            HapticsManager.shared.error()
            print("❌ Rename failed: \(error)")
        }
    }

    private func shareModel(url: URL) {
        HapticsManager.shared.impactLight()
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
                    HapticsManager.shared.success()
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

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, icon: String, color: UIColor, isSelected: Bool) {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.buttonSize = .mini
        configuration.image = UIImage(
            systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        )
        configuration.imagePlacement = .leading
        configuration.imagePadding = 4
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)
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
