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
        contentView.addSubview(container)
        container.addSubview(thumbnailView)
        container.addSubview(titleLabel)
        container.addSubview(sizeLabel)

        contentView.backgroundColor = .clear
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 4
        contentView.layer.shadowOpacity = 0.1

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            thumbnailView.topAnchor.constraint(equalTo: container.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            thumbnailView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.65),

            titleLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),

            sizeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            sizeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            sizeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            sizeLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.image = nil
        titleLabel.text = nil
        sizeLabel.text = nil
    }

    // MARK: - Configure

    /// Use this version when working with disk files
    func configure(fileName: String, size: String, thumbnail: UIImage?) {
        titleLabel.text = fileName
        sizeLabel.text = size
        thumbnailView.image = thumbnail ?? UIImage(systemName: "arkit")!
    }

    /// Use this version if you're working with RoomModel directly
    func configure(with model: RoomModel) {
        titleLabel.text = model.name ?? "Room"
//        sizeLabel.text = model.metadata ?? ""
        thumbnailView.image = model.thumbnail ?? UIImage(systemName: "square.split.2x2")!
    }
}
