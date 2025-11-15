//
//  UserProfileViewController.swift
//  Envision
//
//  Created by admin55 on 13/11/25.
//


import UIKit

class ProfileViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    private let profileImageContainer = UIView()
    private let profileImageView = UIImageView()
    private let editImageButton = UIButton(type: .system)
    
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let editProfileButton = UIButton(type: .system)
    
    private let statsContainer = UIStackView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Profile"
        
        setupScrollView()
        setupProfileHeader()
        setupStats()
//        setupMenuItems()
        setupMenuItems()
        
    }
    
    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.axis = .vertical
        contentView.spacing = 24
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leftAnchor.constraint(equalTo: view.leftAnchor),
            scrollView.rightAnchor.constraint(equalTo: view.rightAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.leftAnchor.constraint(equalTo: scrollView.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: scrollView.rightAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }
    private func setupProfileHeader() {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Gradient circle
        profileImageContainer.translatesAutoresizingMaskIntoConstraints = false
        profileImageContainer.layer.cornerRadius = 60
        profileImageContainer.clipsToBounds = true
        
        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.frame = CGRect(x: 0, y: 0, width: 120, height: 120)
        profileImageContainer.layer.insertSublayer(gradient, at: 0)
        
        profileImageContainer.addSubview(profileImageView)
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.image = UIImage(systemName: "person.fill")
        profileImageView.tintColor = .white
        profileImageView.contentMode = .scaleAspectFit
        
        NSLayoutConstraint.activate([
            profileImageContainer.widthAnchor.constraint(equalToConstant: 120),
            profileImageContainer.heightAnchor.constraint(equalToConstant: 120),
            
            profileImageView.centerXAnchor.constraint(equalTo: profileImageContainer.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: profileImageContainer.centerYAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 50),
            profileImageView.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Camera button over image
        editImageButton.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        editImageButton.tintColor = .white
        editImageButton.backgroundColor = .systemBlue
        editImageButton.layer.cornerRadius = 16
        editImageButton.translatesAutoresizingMaskIntoConstraints = false
        editImageButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)
        
        profileImageContainer.addSubview(editImageButton)
        NSLayoutConstraint.activate([
            editImageButton.widthAnchor.constraint(equalToConstant: 32),
            editImageButton.heightAnchor.constraint(equalToConstant: 32),
            editImageButton.bottomAnchor.constraint(equalTo: profileImageContainer.bottomAnchor, constant: 4),
            editImageButton.rightAnchor.constraint(equalTo: profileImageContainer.rightAnchor, constant: 4)
        ])
        
        nameLabel.text = "John Doe"
        nameLabel.font = .systemFont(ofSize: 22, weight: .bold)
        
        emailLabel.text = "john.doe@example.com"
        emailLabel.font = .systemFont(ofSize: 14)
        emailLabel.textColor = .secondaryLabel
        
        editProfileButton.setTitle("Edit Profile", for: .normal)
        editProfileButton.backgroundColor = .systemBlue
        editProfileButton.tintColor = .white
        editProfileButton.layer.cornerRadius = 12
        editProfileButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        editProfileButton.translatesAutoresizingMaskIntoConstraints = false
        editProfileButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        editProfileButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)
        
        container.addArrangedSubview(profileImageContainer)
        container.addArrangedSubview(nameLabel)
        container.addArrangedSubview(emailLabel)
        container.addArrangedSubview(editProfileButton)
        
        contentView.addArrangedSubview(container)
        container.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.9).isActive = true
    }
    private func setupStats() {
        statsContainer.axis = .horizontal
        statsContainer.distribution = .fillEqually
        statsContainer.backgroundColor = UIColor.systemGray6
        statsContainer.layer.cornerRadius = 12
        statsContainer.translatesAutoresizingMaskIntoConstraints = false
        
        statsContainer.addArrangedSubview(makeStat(title: "Posts", value: "42"))
        statsContainer.addArrangedSubview(makeDivider())
        statsContainer.addArrangedSubview(makeStat(title: "Followers", value: "1.2K"))
        statsContainer.addArrangedSubview(makeDivider())
        statsContainer.addArrangedSubview(makeStat(title: "Following", value: "356"))
        
        contentView.addArrangedSubview(statsContainer)
        statsContainer.heightAnchor.constraint(equalToConstant: 80).isActive = true
        statsContainer.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.9).isActive = true
    }

    private func makeStat(title: String, value: String) -> UIView {
        let v = UIStackView()
        v.axis = .vertical
        v.alignment = .center
        v.spacing = 4
        
        let val = UILabel()
        val.text = value
        val.font = .boldSystemFont(ofSize: 18)
        
        let lbl = UILabel()
        lbl.text = title
        lbl.font = .systemFont(ofSize: 12)
        lbl.textColor = .secondaryLabel
        
        v.addArrangedSubview(val)
        v.addArrangedSubview(lbl)
        return v
    }

    private func makeDivider() -> UIView {
        let d = UIView()
        d.backgroundColor = .systemGray3
        d.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return d
    }
    private func setupMenuItems() {
        let menuStack = UIStackView()
        menuStack.axis = .vertical
        menuStack.spacing = 12
        menuStack.translatesAutoresizingMaskIntoConstraints = false
        
        menuStack.addArrangedSubview(menuItem(icon: "person.circle", title: "My Account"))
        menuStack.addArrangedSubview(menuItem(icon: "heart.fill", title: "Favorites"))
        menuStack.addArrangedSubview(menuItem(icon: "bookmark.fill", title: "Saved Items"))
        menuStack.addArrangedSubview(menuItem(icon: "bell.fill", title: "Notifications"))
        menuStack.addArrangedSubview(menuItem(icon: "lock.fill", title: "Privacy & Security"))
        menuStack.addArrangedSubview(menuItem(icon: "gearshape.fill", title: "Settings"))
        
        contentView.addArrangedSubview(menuStack)
        menuStack.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.9).isActive = true
    }

    private func menuItem(icon: String, title: String) -> UIView {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemGray6
        button.layer.cornerRadius = 12
        button.setTitle(title, for: .normal)
        button.contentHorizontalAlignment = .left
        button.setTitleColor(.label, for: .normal)
        
        button.heightAnchor.constraint(equalToConstant: 56).isActive = true
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .systemBlue
        iconView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(iconView)
        
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .secondaryLabel
        chevron.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(chevron)
        
        NSLayoutConstraint.activate([
            iconView.leftAnchor.constraint(equalTo: button.leftAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            chevron.rightAnchor.constraint(equalTo: button.rightAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
        
        return button
    }
    @objc private func editProfileTapped() {
        let vc = EditProfileViewController()
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

}

