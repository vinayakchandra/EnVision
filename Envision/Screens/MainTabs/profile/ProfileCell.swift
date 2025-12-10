//
//  ProfileCell.swift
//  Envision
//

import UIKit

class ProfileCell: UITableViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 17)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
                                        iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                                        iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                                        iconView.widthAnchor.constraint(equalToConstant: 24),
                                        iconView.heightAnchor.constraint(equalToConstant: 24),

                                        titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
                                        titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16)
                                    ])
    }

    func configure(icon: String, title: String, isDestructive: Bool = false) {
        iconView.image = UIImage(systemName: icon)
        titleLabel.text = title

        if isDestructive {
            iconView.tintColor = .systemRed
            titleLabel.textColor = .systemRed
        } else {
            iconView.tintColor = AppColors.accent
            titleLabel.textColor = .label
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.tintColor = AppColors.accent
        titleLabel.textColor = .label
    }
}
