import UIKit

final class RoomCell: UICollectionViewCell {

    static let reuseID = "RoomCell"

    // MARK: - UI

    private let thumbnailView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10
        iv.backgroundColor = UIColor.secondarySystemBackground
        return iv
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 14, weight: .semibold)
        lbl.textColor = .label
        lbl.numberOfLines = 2
        return lbl
    }()

    private let sizeLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 12, weight: .regular)
        lbl.textColor = .secondaryLabel
        lbl.numberOfLines = 1
        return lbl
    }()

    private let container: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        return v
    }()

    // MARK: - Selection UI
    private let selectionCircle: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.image = UIImage(systemName: "circle")
        iv.tintColor = .systemGray3
        iv.isHidden = true
        return iv
    }()

    private var containerLeadingConstraint: NSLayoutConstraint!

    // MARK: - Category Badge

    private let categoryBadge: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground.withAlphaComponent(0.7)
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.isHidden = true
        return view
    }()

    private let categoryIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let categoryLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        return lbl
    }()

    // MARK: - RoomType Badge

    private let roomTypeBadge: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground.withAlphaComponent(0.7)
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.isHidden = true
        return view
    }()

    private let roomTypeIcon: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private let roomTypeLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 11, weight: .medium)
        return lbl
    }()

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupUI() {
        contentView.backgroundColor = .clear
        contentView.addSubview(selectionCircle)
        contentView.addSubview(container)
        container.addSubview(thumbnailView)
        container.addSubview(titleLabel)
        container.addSubview(sizeLabel)

        thumbnailView.addSubview(categoryBadge)
        thumbnailView.addSubview(roomTypeBadge)

        roomTypeBadge.addSubview(roomTypeIcon)
        roomTypeBadge.addSubview(roomTypeLabel)

        categoryBadge.addSubview(categoryIcon)
        categoryBadge.addSubview(categoryLabel)

        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 4
        contentView.layer.shadowOpacity = 0.1

        containerLeadingConstraint = container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)

        NSLayoutConstraint.activate([
            // Selection Circle
            selectionCircle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            selectionCircle.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            selectionCircle.widthAnchor.constraint(equalToConstant: 30),
            selectionCircle.heightAnchor.constraint(equalToConstant: 30),

            // Container
            containerLeadingConstraint,
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Thumbnail
            thumbnailView.topAnchor.constraint(equalTo: container.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            thumbnailView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.65),

            // Title
            titleLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

            // Size
            sizeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            sizeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            sizeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            sizeLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),

            // RoomType Badge
            roomTypeBadge.topAnchor.constraint(equalTo: thumbnailView.topAnchor, constant: 8),
            roomTypeBadge.trailingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: -8),
            roomTypeBadge.heightAnchor.constraint(equalToConstant: 24),

            roomTypeIcon.leadingAnchor.constraint(equalTo: roomTypeBadge.leadingAnchor, constant: 6),
            roomTypeIcon.centerYAnchor.constraint(equalTo: roomTypeBadge.centerYAnchor),
            roomTypeIcon.widthAnchor.constraint(equalToConstant: 14),
            roomTypeIcon.heightAnchor.constraint(equalToConstant: 14),

            roomTypeLabel.leadingAnchor.constraint(equalTo: roomTypeIcon.trailingAnchor, constant: 4),
            roomTypeLabel.trailingAnchor.constraint(equalTo: roomTypeBadge.trailingAnchor, constant: -8),
            roomTypeLabel.centerYAnchor.constraint(equalTo: roomTypeBadge.centerYAnchor),

            // Category Badge
            categoryBadge.topAnchor.constraint(equalTo: roomTypeBadge.bottomAnchor, constant: 6),
            categoryBadge.trailingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: -8),
            categoryBadge.heightAnchor.constraint(equalToConstant: 24),

            categoryIcon.leadingAnchor.constraint(equalTo: categoryBadge.leadingAnchor, constant: 6),
            categoryIcon.centerYAnchor.constraint(equalTo: categoryBadge.centerYAnchor),
            categoryIcon.widthAnchor.constraint(equalToConstant: 14),
            categoryIcon.heightAnchor.constraint(equalToConstant: 14),

            categoryLabel.leadingAnchor.constraint(equalTo: categoryIcon.trailingAnchor, constant: 4),
            categoryLabel.trailingAnchor.constraint(equalTo: categoryBadge.trailingAnchor, constant: -8),
            categoryLabel.centerYAnchor.constraint(equalTo: categoryBadge.centerYAnchor),
        ])
    }

    // MARK: - Selection Mode

    func setSelectionMode(_ enabled: Bool, animated: Bool) {
        let changes = {
            self.selectionCircle.isHidden = !enabled
            self.containerLeadingConstraint.constant = enabled ? 60 : 12
            self.layoutIfNeeded()
        }

        animated
            ? UIView.animate(withDuration: 0.25, animations: changes)
            : changes()
    }

    override var isSelected: Bool {
        didSet {
            let imageName = isSelected ? "checkmark.circle.fill" : "circle"
            selectionCircle.image = UIImage(systemName: imageName)
            selectionCircle.tintColor = isSelected ? .systemBlue : .systemGray3
        }
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.image = nil
        titleLabel.text = nil
        sizeLabel.text = nil
        categoryBadge.isHidden = true
        roomTypeBadge.isHidden = true
        selectionCircle.image = UIImage(systemName: "circle")
    }

    // MARK: - Configure

    func configure(
        fileName: String,
        size: String,
        thumbnail: UIImage?,
        category: RoomCategory? = nil,
        roomType: RoomType? = nil
    ) {
        titleLabel.text = fileName
        sizeLabel.text = size
        thumbnailView.image = thumbnail ?? UIImage(systemName: "arkit")

        categoryBadge.isHidden = true
        roomTypeBadge.isHidden = true

        if let category = category {
            categoryIcon.image = UIImage(systemName: category.sfSymbol)
            categoryIcon.tintColor = category.color
            categoryLabel.text = category.displayName
            categoryLabel.textColor = category.color
            categoryBadge.isHidden = false
        }

        if let roomType = roomType {
            roomTypeIcon.image = UIImage(systemName: roomType.sfSymbol)
            roomTypeIcon.tintColor = roomType.color
            roomTypeLabel.text = roomType.displayName
            roomTypeLabel.textColor = roomType.color
            roomTypeBadge.isHidden = false
        }
    }
}
