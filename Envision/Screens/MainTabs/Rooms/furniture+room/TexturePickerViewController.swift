//
//  TexturePickerViewController.swift
//  Envision
//
//  Bottom-sheet picker showing Floor and Wall texture sections side by side.
//

import UIKit

// MARK: - Surface

enum TextureSurface {
    case floor
    case wall
}

// MARK: - Option

struct TextureOption {
    /// Asset catalog name. Empty string means "no texture / None".
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

    /// Set before presenting so the active selection is highlighted.
    var currentFloorTextureName: String = ""
    var currentWallTextureName: String  = ""

    // MARK: - Catalogue

    static let floorTextures: [TextureOption] = [
        TextureOption(name: "",                     displayName: "None"),
        TextureOption(name: "texture-wooden-board", displayName: "Wood Floor"),
    ]

    static let wallTextures: [TextureOption] = [
        TextureOption(name: "",               displayName: "None"),
        TextureOption(name: "wall-wallpaper", displayName: "Wallpaper"),
    ]

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

    private lazy var floorCollectionView = makeCollectionView(tag: 0)
    private lazy var wallCollectionView  = makeCollectionView(tag: 1)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.12, alpha: 1)
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]

        let floorHeader = makeSectionHeader("Floor")
        let wallHeader  = makeSectionHeader("Wall")

        let stack = UIStackView(arrangedSubviews: [
            floorHeader, floorCollectionView,
            wallHeader,  wallCollectionView,
        ])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 4

        view.addSubview(handleBar)
        view.addSubview(titleLabel)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            handleBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 36),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            stack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            floorCollectionView.heightAnchor.constraint(equalToConstant: 118),
            wallCollectionView.heightAnchor.constraint(equalToConstant: 118),
        ])
    }

    // MARK: - Helpers

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
        return cv
    }

    private func makeSectionHeader(_ title: String) -> UILabel {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text = title.uppercased()
        lbl.font = .systemFont(ofSize: 11, weight: .semibold)
        lbl.textColor = UIColor(white: 0.55, alpha: 1)
        lbl.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        // Indent text via a container view
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            lbl.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            lbl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            lbl.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return lbl
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension TexturePickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    private var floorOptions: [TextureOption] { TexturePickerViewController.floorTextures }
    private var wallOptions:  [TextureOption] { TexturePickerViewController.wallTextures  }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView.tag == 0 ? floorOptions.count : wallOptions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TextureCell.reuseID, for: indexPath) as! TextureCell

        if collectionView.tag == 0 {
            let option = floorOptions[indexPath.item]
            cell.configure(with: option, selected: option.name == currentFloorTextureName)
        } else {
            let option = wallOptions[indexPath.item]
            cell.configure(with: option, selected: option.name == currentWallTextureName)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView.tag == 0 {
            let option = floorOptions[indexPath.item]
            currentFloorTextureName = option.name
            collectionView.reloadData()
            delegate?.texturePicker(self, didSelect: option, for: .floor)
        } else {
            let option = wallOptions[indexPath.item]
            currentWallTextureName = option.name
            collectionView.reloadData()
            delegate?.texturePicker(self, didSelect: option, for: .wall)
        }
        // Don't auto-dismiss — let the user set both surfaces before closing
    }
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
            imageView.image = UIImage(named: option.name)
            imageView.contentMode = .scaleAspectFill
            imageView.tintColor = nil
            imageView.backgroundColor = UIColor(white: 0.25, alpha: 1)
        }
    }
}
