//
//  USDZCell.swift
//  Envision
//
//  Created by admin55 on 16/11/25.
//

import UIKit


final class USDZCell: UICollectionViewCell {

    static let reuseIdentifier = "USDZCell"
    
    // MARK: - UI
    
    private let thumbnailView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.layer.cornerRadius = 8
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemBackground
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let lb = UILabel()
        lb.font = .preferredFont(forTextStyle: .subheadline)
        lb.textAlignment = .center
        lb.numberOfLines = 2
        lb.translatesAutoresizingMaskIntoConstraints = false
        return lb
    }()
    
    private let sizeLabel: UILabel = {
        let lb = UILabel()
        lb.font = .preferredFont(forTextStyle: .caption1)
        lb.textColor = .secondaryLabel
        lb.textAlignment = .center
        lb.translatesAutoresizingMaskIntoConstraints = false
        return lb
    }()
    
    private lazy var mainStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [thumbnailView, titleLabel, sizeLabel])
        stack.axis = .vertical
        stack.spacing = 10    // space between thumbnail → title
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        
        contentView.addSubview(mainStack)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            
            // Bigger thumbnail
            thumbnailView.heightAnchor.constraint(equalToConstant: 90),
            thumbnailView.widthAnchor.constraint(equalTo: thumbnailView.heightAnchor)
        ])
    }
    
    // MARK: - Configure
    
    func configure(name: String, sizeText: String, thumbnail: UIImage?) {
        titleLabel.text = name
        sizeLabel.text = sizeText
        
        if let image = thumbnail {
            thumbnailView.image = image
            thumbnailView.tintColor = nil
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .regular)
            thumbnailView.image = UIImage(systemName: "cube.transparent", withConfiguration: config)
            thumbnailView.tintColor = .tertiaryLabel
        }
    }
}


class USDZCell1: UICollectionViewCell {
    static let reuseIdentifier = "USDZCell"

    private let imageView = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 15
        layer.masksToBounds = true

        //image
        imageView.contentMode = .scaleAspectFit
        imageView.frame = CGRect(x: 10, y: 10, width: frame.width - 20, height: 120)
        imageView.autoresizingMask = [.flexibleWidth]
        addSubview(imageView)

        // label
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.frame = CGRect(x: 5, y: 130, width: frame.width - 10, height: 40)
        label.autoresizingMask = [.flexibleWidth]
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, sizeText: String, thumbnail: UIImage?) {
        label.text = name
        imageView.image = thumbnail ?? UIImage(systemName: "cube")
    }
}
