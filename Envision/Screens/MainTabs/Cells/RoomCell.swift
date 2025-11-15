//
//  RoomCell.swift
//  Envision
//
//  Created by user@78 on 10/11/25.
//


import UIKit

final class RoomCell: UICollectionViewCell {

    // MARK: - UI Components
    private let previewImageView = UIImageView()
    private let nameLabel = UILabel()
    private let optionsButton = UIButton(type: .system)

    var onOptionsTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 16
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.05
        contentView.layer.shadowRadius = 8
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)

        previewImageView.contentMode = .scaleAspectFit
        previewImageView.tintColor = AppColors.accent
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        
        nameLabel.font = AppFonts.semibold(15)
        nameLabel.textColor = AppColors.textPrimary
        nameLabel.textAlignment = .left
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        optionsButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        optionsButton.tintColor = AppColors.textSecondary
        optionsButton.addTarget(self, action: #selector(optionsTapped), for: .touchUpInside)
        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(previewImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(optionsButton)

        NSLayoutConstraint.activate([
            previewImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            previewImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            previewImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            previewImageView.heightAnchor.constraint(equalToConstant: 100),
            
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            optionsButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            optionsButton.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor)
        ])
    }

    func configure(with model: RoomModel) {
        previewImageView.image = model.preview ?? UIImage(systemName: "cube.transparent")
        nameLabel.text = model.name
    }

    @objc private func optionsTapped() {
        onOptionsTapped?()
    }
}
