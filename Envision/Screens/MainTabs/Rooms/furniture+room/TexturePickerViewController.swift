//
//  TexturePickerViewController.swift
//  Envision
//
//  Bottom-sheet picker showing texture sections for room entities.
//

import UIKit
import PhotosUI

// MARK: - Surface

enum TextureSurface: CaseIterable {
    case floor
    case wall
    case door
    case window
    case table
    case chair
    case storage

    var title: String {
        switch self {
        case .floor: return "Floor"
        case .wall: return "Wall"
        case .door: return "Door"
        case .window: return "Window"
        case .table: return "Table"
        case .chair: return "Chair"
        case .storage: return "Storage"
        }
    }

    var surfaceKind: RoomColorManager.TextureSurfaceKind {
        switch self {
        case .floor: return .floor
        case .wall: return .wall
        case .door: return .door
        case .window: return .window
        case .table: return .table
        case .chair: return .chair
        case .storage: return .storage
        }
    }
}

// MARK: - Option

struct TextureOption {
    /// Texture key name. Empty string means "no texture / None".
    let name: String
    let displayName: String
}

// MARK: - Delegate

protocol TexturePickerDelegate: AnyObject {
    /// Called when the user picks a texture for a specific surface.
    /// `option.name` is empty when the user selects "None".
    func texturePicker(_ picker: TexturePickerViewController,
                       didSelect option: TextureOption,
                       for surface: TextureSurface)
}

// MARK: - Controller

final class TexturePickerViewController: UIViewController {

    // MARK: - Public

    weak var delegate: TexturePickerDelegate?

    /// Set before presenting so active selections are highlighted.
    var currentTextureNames: [TextureSurface: String] = [:]

    // MARK: - Catalogue

    private let orderedSurfaces: [TextureSurface] = [.floor, .wall, .door, .window, .table, .chair, .storage]
    private var optionsBySurface: [TextureSurface: [TextureOption]] = [:]
    private var collectionViewsBySurface: [TextureSurface: UICollectionView] = [:]

    // Surface that triggered the photo picker — set before presenting PHPickerViewController
    private var pendingPickSurface: TextureSurface?

    // MARK: - Views

    private let handleBar: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.systemFill
        v.layer.cornerRadius = 3
        return v
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text = "Textures"
        lbl.font = .systemFont(ofSize: 17, weight: .semibold)
        lbl.textColor = .white
        return lbl
    }()

    private let scrollView: UIScrollView = {
        let v = UIScrollView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.showsVerticalScrollIndicator = true
        v.alwaysBounceVertical = true
        return v
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 4
        return stack
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.12, alpha: 1)
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        reloadTextureOptions()
        buildSections()

        view.addSubview(handleBar)
        view.addSubview(titleLabel)
        view.addSubview(scrollView)

        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            handleBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 36),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    // MARK: - Helpers

    private func buildSections() {
        orderedSurfaces.forEach { surface in
            if currentTextureNames[surface] == nil {
                currentTextureNames[surface] = ""
            }

            let header = makeSectionHeader(surface.title)
            let collectionView = makeCollectionView(tag: tag(for: surface))
            collectionViewsBySurface[surface] = collectionView

            contentStack.addArrangedSubview(header)
            contentStack.addArrangedSubview(collectionView)
            collectionView.heightAnchor.constraint(equalToConstant: 118).isActive = true
        }
    }

    private func reloadTextureOptions() {
        let manager = RoomColorManager.shared
        manager.ensureBundledTexturesAvailable()

        for surface in orderedSurfaces {
            let items = manager.availableTextureItems(for: surface.surfaceKind)
            let options = [TextureOption(name: "", displayName: "None")] + items.map {
                TextureOption(name: $0.name, displayName: $0.displayName)
            }
            optionsBySurface[surface] = options
        }
    }

    private func makeCollectionView(tag: Int) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 88, height: 110)
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.tag = tag
        cv.dataSource = self
        cv.delegate = self
        cv.register(TextureCell.self, forCellWithReuseIdentifier: TextureCell.reuseID)
        cv.register(AddTextureCell.self, forCellWithReuseIdentifier: AddTextureCell.reuseID)
        return cv
    }

    private func makeSectionHeader(_ title: String) -> UIView {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text = title.uppercased()
        lbl.font = .systemFont(ofSize: 11, weight: .semibold)
        lbl.textColor = UIColor(white: 0.55, alpha: 1)

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            lbl.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            lbl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            lbl.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    private func tag(for surface: TextureSurface) -> Int {
        orderedSurfaces.firstIndex(of: surface) ?? 0
    }

    private func surface(for tag: Int) -> TextureSurface? {
        guard tag >= 0, tag < orderedSurfaces.count else { return nil }
        return orderedSurfaces[tag]
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension TexturePickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let surface = surface(for: collectionView.tag) else { return 0 }
        // +1 for the "Add from Photos" cell at the end
        return (optionsBySurface[surface]?.count ?? 0) + 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let surface = surface(for: collectionView.tag) else {
            return collectionView.dequeueReusableCell(withReuseIdentifier: TextureCell.reuseID, for: indexPath)
        }
        let options = optionsBySurface[surface] ?? []

        // Last slot is always the "+" add button
        if indexPath.item == options.count {
            return collectionView.dequeueReusableCell(withReuseIdentifier: AddTextureCell.reuseID, for: indexPath)
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TextureCell.reuseID,
            for: indexPath
        ) as! TextureCell

        let option = options[indexPath.item]
        let selectedName = currentTextureNames[surface] ?? ""
        cell.configure(with: option, selected: option.name == selectedName)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let surface = surface(for: collectionView.tag) else { return }
        let options = optionsBySurface[surface] ?? []

        // "+" cell tapped — open photo picker
        if indexPath.item == options.count {
            pendingPickSurface = surface
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.filter = .images
            config.selectionLimit = 1
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true)
            return
        }

        let option = options[indexPath.item]
        currentTextureNames[surface] = option.name
        collectionView.reloadData()
        delegate?.texturePicker(self, didSelect: option, for: surface)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension TexturePickerViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let surface = pendingPickSurface, let result = results.first else {
            pendingPickSurface = nil
            return
        }
        pendingPickSurface = nil

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            let name = RoomColorManager.shared.saveCustomTexture(image, for: surface.surfaceKind)
            DispatchQueue.main.async {
                self.reloadTextureOptions()
                let option = TextureOption(name: name, displayName: "Custom")
                self.currentTextureNames[surface] = name
                self.collectionViewsBySurface[surface]?.reloadData()
                self.delegate?.texturePicker(self, didSelect: option, for: surface)
            }
        }
    }
}

// MARK: - AddTextureCell

private final class AddTextureCell: UICollectionViewCell {

    static let reuseID = "AddTextureCell"

    private let plusImageView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .light)
        let iv = UIImageView(image: UIImage(systemName: "plus", withConfiguration: config))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = UIColor(white: 0.6, alpha: 1)
        iv.contentMode = .center
        return iv
    }()

    private let borderView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 12
        v.layer.cornerCurve = .continuous
        v.layer.borderWidth = 1.5
        v.layer.borderColor = UIColor(white: 0.4, alpha: 1).cgColor
        v.backgroundColor = UIColor(white: 0.18, alpha: 1)
        return v
    }()

    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text = "Add"
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = UIColor(white: 0.6, alpha: 1)
        lbl.textAlignment = .center
        return lbl
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(borderView)
        borderView.addSubview(plusImageView)
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            borderView.topAnchor.constraint(equalTo: contentView.topAnchor),
            borderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            borderView.heightAnchor.constraint(equalToConstant: 88),

            plusImageView.centerXAnchor.constraint(equalTo: borderView.centerXAnchor),
            plusImageView.centerYAnchor.constraint(equalTo: borderView.centerYAnchor),

            nameLabel.topAnchor.constraint(equalTo: borderView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - TextureCell

private final class TextureCell: UICollectionViewCell {

    static let reuseID = "TextureCell"

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.layer.cornerCurve = .continuous
        iv.backgroundColor = UIColor(white: 0.25, alpha: 1)
        return iv
    }()

    private let checkmark: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.tintColor = AppColors.accent
        iv.isHidden = true
        return iv
    }()

    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        lbl.textColor = .white
        lbl.textAlignment = .center
        return lbl
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.addSubview(checkmark)
        contentView.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 88),

            checkmark.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 6),
            checkmark.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -6),
            checkmark.widthAnchor.constraint(equalToConstant: 20),
            checkmark.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with option: TextureOption, selected: Bool) {
        nameLabel.text = option.displayName
        checkmark.isHidden = !selected
        imageView.layer.borderWidth = selected ? 2 : 0
        imageView.layer.borderColor = selected ? AppColors.accent.cgColor : nil

        if option.name.isEmpty {
            imageView.backgroundColor = UIColor(white: 0.22, alpha: 1)
            let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .light)
            imageView.image = UIImage(systemName: "xmark", withConfiguration: config)
            imageView.tintColor = .secondaryLabel
            imageView.contentMode = .center
        } else {
            imageView.image = RoomColorManager.shared.texturePreviewImage(named: option.name)
            imageView.contentMode = .scaleAspectFill
            imageView.tintColor = nil
            imageView.backgroundColor = UIColor(white: 0.25, alpha: 1)
        }
    }
}
