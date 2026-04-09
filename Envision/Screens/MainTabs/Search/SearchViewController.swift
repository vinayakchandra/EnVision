//
//  SearchViewController.swift
//  Envision
//

import UIKit
import QuickLook

final class SearchViewController: UIViewController, UISearchResultsUpdating {

    struct SearchModelItem {
        let url: URL
        let type: ModelType
        let title: String
        let createdAt: Date
    }

    private let searchController = UISearchController(searchResultsController: nil)
    private var collectionView: UICollectionView!
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.text = "No models found"
        label.isHidden = true
        return label
    }()

    private var allItems: [SearchModelItem] = []
    private var filteredItems: [SearchModelItem] = []
    private var previewURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Search"
        view.backgroundColor = .systemBackground

        setupSearch()
        setupCollectionView()
        setupEmptyState()
        loadAllModels()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAllModels()
    }

    private func setupSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search rooms and furniture"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 16, right: 16)
        layout.itemSize = CGSize(width: view.bounds.width - 32, height: 96)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(SearchModelCardCell.self, forCellWithReuseIdentifier: SearchModelCardCell.reuseID)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyState() {
        view.addSubview(emptyStateLabel)
        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func loadAllModels() {
        let roomModels = SaveManager.shared.getSavedModels(type: .room).map { makeItem(url: $0, type: .room) }
        let furnitureModels = SaveManager.shared.getSavedModels(type: .furniture).map { makeItem(url: $0, type: .furniture) }

        allItems = (roomModels + furnitureModels).sorted { $0.createdAt > $1.createdAt }
        applyFilter()
    }

    private func makeItem(url: URL, type: ModelType) -> SearchModelItem {
        let fileName = url.deletingPathExtension().lastPathComponent
        let createdAt = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
        return SearchModelItem(url: url, type: type, title: fileName, createdAt: createdAt)
    }

    private func applyFilter() {
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredItems = allItems
        } else {
            filteredItems = allItems.filter { item in
                item.title.localizedCaseInsensitiveContains(query)
                || item.type.displayName.localizedCaseInsensitiveContains(query)
            }
        }
        emptyStateLabel.isHidden = !filteredItems.isEmpty
        collectionView.reloadData()
    }

    func updateSearchResults(for searchController: UISearchController) {
        applyFilter()
    }
}

extension SearchViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        filteredItems.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: SearchModelCardCell.reuseID,
            for: indexPath
        ) as! SearchModelCardCell
        let item = filteredItems[indexPath.item]
        cell.configure(with: item)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: collectionView.bounds.width - 32, height: 96)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        HapticsManager.shared.selection()
        let item = filteredItems[indexPath.item]

        switch item.type {
        case .room:
            let vc = RoomViewerViewController(roomURL: item.url)
            navigationController?.pushViewController(vc, animated: true)
        case .furniture:
            previewURL = item.url
            let preview = QLPreviewController()
            preview.dataSource = self
            present(preview, animated: true)
        }
    }
}

extension SearchViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewURL! as NSURL
    }
}

private final class SearchModelCardCell: UICollectionViewCell {
    static let reuseID = "SearchModelCardCell"

    private var representedURL: URL?

    private let cardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        return view
    }()

    private let thumbnailView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.backgroundColor = .tertiarySystemFill
        imageView.image = UIImage(systemName: "cube.fill")
        imageView.tintColor = .secondaryLabel
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()

    private let chevronView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "chevron.right"))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .tertiaryLabel
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(cardView)
        cardView.addSubview(thumbnailView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(chevronView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            thumbnailView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            thumbnailView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 72),
            thumbnailView.heightAnchor.constraint(equalToConstant: 72),

            chevronView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            chevronView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 10),

            titleLabel.topAnchor.constraint(equalTo: thumbnailView.topAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor, constant: -10),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: SearchViewController.SearchModelItem) {
        representedURL = item.url
        titleLabel.text = item.title

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        subtitleLabel.text = "\(item.type.displayName) • \(formatter.string(from: item.createdAt))"

        let fallbackIcon = item.type == .room ? "house.fill" : "cube.fill"
        thumbnailView.image = UIImage(systemName: fallbackIcon)
        thumbnailView.tintColor = .secondaryLabel

        SaveManager.shared.getThumbnail(for: item.url) { [weak self] image in
            guard let self, self.representedURL == item.url else { return }
            if let image {
                self.thumbnailView.image = image
                self.thumbnailView.tintColor = nil
            }
        }
    }
}
