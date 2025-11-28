//
//  FurniturePickerViewController.swift
//  Envision
//

import UIKit
import UniformTypeIdentifiers
import QuickLookThumbnailing

final class FurniturePickerViewController: UIViewController {

    // MARK: - Public callback

    var onModelSelected: ((URL) -> Void)?

    // MARK: - UI

    private var collectionView: UICollectionView!
    private var loadingOverlay: UIVisualEffectView!
    private var activityIndicator: UIActivityIndicatorView!
    private var loadingLabel: UILabel!

    // MARK: - Data

    private var modelFiles: [URL] = []
    private let thumbnailCache: NSCache<NSURL, UIImage> = .init()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Select Furniture"
        view.backgroundColor = .systemGroupedBackground

        setupCollectionView()
        setupLoadingOverlay()
        loadModels(from: modelsFolderURL())

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(closeTapped)
        )
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
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

    // MARK: - CollectionView

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

            let groupHeight: CGFloat = 160
            let columns = UIDevice.current.userInterfaceIdiom == .pad ? 4 : 2
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(groupHeight)
            )

            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitem: item,
                count: columns
            )
            return NSCollectionLayoutSection(group: group)
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.register(USDZCell.self, forCellWithReuseIdentifier: USDZCell.reuseIdentifier)
        collectionView.dataSource = self
        collectionView.delegate = self

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Loading overlay

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
        loadingLabel.text = "Loading…"

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

    private func showLoading(_ text: String) {
        loadingLabel.text = text
        loadingOverlay.isHidden = false
        activityIndicator.startAnimating()
    }

    private func hideLoading() {
        loadingOverlay.isHidden = true
        activityIndicator.stopAnimating()
    }

    // MARK: - Load models

    private func loadModels(from folder: URL) {
        showLoading("Loading furniture…")

        DispatchQueue.global(qos: .userInitiated).async {
            var results: [URL] = []
            let fm = FileManager.default

            if let enumerator = fm.enumerator(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let fileURL as URL in enumerator {
                    if fileURL.pathExtension.lowercased() == "usdz" {
                        results.append(fileURL)
                    }
                }
            }

            results.sort { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }

            DispatchQueue.main.async {
                self.modelFiles = results
                self.thumbnailCache.removeAllObjects()
                self.collectionView.reloadData()
                self.hideLoading()
            }
        }
    }

    // MARK: - Thumbnails

    private func generateThumbnail(for url: URL,
                                   completion: @escaping (UIImage?) -> Void) {

        if let cached = thumbnailCache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 300, height: 300),
            scale: UIScreen.main.scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { rep, _ in
            DispatchQueue.main.async {
                let img = rep?.uiImage
                if let img = img {
                    self.thumbnailCache.setObject(img, forKey: url as NSURL)
                }
                completion(img)
            }
        }
    }

    // MARK: - Helpers

    private func fileSizeString(for url: URL) -> String {
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? NSNumber {
            let fmt = ByteCountFormatter()
            fmt.countStyle = .file
            return fmt.string(fromByteCount: size.int64Value)
        }
        return "--"
    }
}

// MARK: - CollectionView

extension FurniturePickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return modelFiles.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: USDZCell.reuseIdentifier,
            for: indexPath
        ) as? USDZCell else {
            return UICollectionViewCell()
        }

        let url = modelFiles[indexPath.item]
        let name = url.deletingPathExtension().lastPathComponent
        let size = fileSizeString(for: url)

        cell.configure(name: name, sizeText: size, thumbnail: nil)

        generateThumbnail(for: url) { image in
            if let visible = collectionView.cellForItem(at: indexPath) as? USDZCell {
                visible.configure(name: name, sizeText: size, thumbnail: image)
            }
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let url = modelFiles[indexPath.item]
        onModelSelected?(url)
        dismiss(animated: true)
    }
}
