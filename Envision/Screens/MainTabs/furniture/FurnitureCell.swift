//
//  FurnitureCell.swift
//  Envision
//
//  Collection view cell for displaying furniture model thumbnails
//

import UIKit

final class FurnitureCell: UICollectionViewCell {
    
    static let reuseIdentifier = "FurnitureCell"
    
    // MARK: - UI Elements
    
    private let container: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        return v
    }()
    
    private let thumbnailImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .tertiarySystemBackground
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 14, weight: .semibold)
        lbl.textColor = .label
        lbl.numberOfLines = 2
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let sizeLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 11, weight: .regular)
        lbl.textColor = .secondaryLabel
        lbl.numberOfLines = 1
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let dateLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 11, weight: .regular)
        lbl.textColor = .tertiaryLabel
        lbl.numberOfLines = 1
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let selectionOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        v.layer.cornerRadius = 12
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let checkmarkImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "checkmark.circle.fill")
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let placeholderIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "cube.fill")
        iv.tintColor = .systemGray3
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
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
        container.addSubview(thumbnailImageView)
        container.addSubview(nameLabel)
        container.addSubview(sizeLabel)
        container.addSubview(dateLabel)
        container.addSubview(selectionOverlay)
        container.addSubview(checkmarkImageView)
        thumbnailImageView.addSubview(placeholderIcon)
        
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
            
            thumbnailImageView.topAnchor.constraint(equalTo: container.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            thumbnailImageView.heightAnchor.constraint(equalTo: container.heightAnchor, multiplier: 0.65),
            
            placeholderIcon.centerXAnchor.constraint(equalTo: thumbnailImageView.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: thumbnailImageView.centerYAnchor),
            placeholderIcon.widthAnchor.constraint(equalToConstant: 40),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 40),
            
            nameLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            
            sizeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            sizeLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            sizeLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            
            dateLabel.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            dateLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            dateLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            
            selectionOverlay.topAnchor.constraint(equalTo: thumbnailImageView.topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: thumbnailImageView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor),
            
            checkmarkImageView.topAnchor.constraint(equalTo: thumbnailImageView.topAnchor, constant: 8),
            checkmarkImageView.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: -8),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 28),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
    
    // MARK: - Configuration
    
    func configure(name: String, sizeText: String, dateText: String, thumbnail: UIImage?) {
        nameLabel.text = name
        sizeLabel.text = sizeText
        dateLabel.text = dateText
        
        if let thumbnail = thumbnail {
            thumbnailImageView.image = thumbnail
            placeholderIcon.isHidden = true
        } else {
            thumbnailImageView.image = nil
            placeholderIcon.isHidden = false
        }
    }
    
    override var isSelected: Bool {
        didSet {
            selectionOverlay.isHidden = !isSelected
            checkmarkImageView.isHidden = !isSelected
        }
    }
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        nameLabel.text = nil
        sizeLabel.text = nil
        dateLabel.text = nil
        placeholderIcon.isHidden = false
        isSelected = false
    }
}
