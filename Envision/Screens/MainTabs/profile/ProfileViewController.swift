//
//  SettingsViewController.swift
//  Envision
//
//  Created by admin55 on 17/11/25.
//

import UIKit

class ProfileViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // MARK: - Profile Components
    private let profileHeaderView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()

    private let profileImageContainer = UIView()
    private let profileImageView = UIImageView()
    private let editImageButton = UIButton(type: .system)

    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let editProfileButton = UIButton(type: .system)

    private let statsStackH = UIStackView()

    // MARK: - Sections & Items
    private enum Section: Int, CaseIterable {
        case account
        case preferences
        case privacy
        case about

        var title: String {
            switch self {
            case .account: return "Account"
            case .preferences: return "Preferences"
            case .privacy: return "Privacy & Security"
            case .about: return "About"
            }
        }
    }

    private let items: [Section: [(icon: String, title: String)]] = [
        .account: [
            ("person.crop.circle", "My Profile"),
            ("envelope.fill", "Email & Password")
        ],
        .preferences: [
            ("paintbrush.fill", "Appearance"),
            ("bell.badge.fill", "Notifications"),
            ("bookmark.fill", "Saved Items")
        ],
        .privacy: [
            ("lock.fill", "Privacy Controls"),
            ("hand.raised.fill", "Permissions"),
            ("key.fill", "Security")
        ],
        .about: [
            ("info.circle.fill", "App Info"),
            ("doc.text.fill", "Terms of Service"),
            ("shield.lefthalf.filled", "Privacy Policy")
        ]
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground

        setupTable()
        setupProfileHeader()
        tableView.tableHeaderView = profileHeaderView
    }

    // MARK: - Table Setup
    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self

        tableView.register(ProfileCell.self, forCellReuseIdentifier: "SettingsCell")
        
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // MARK: - Profile Header Setup
    private func setupProfileHeader() {
        profileHeaderView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 280)

        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        profileHeaderView.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: profileHeaderView.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: profileHeaderView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: profileHeaderView.trailingAnchor)
        ])

        // MARK: - Profile Image (simple, no gradient, no camera button)
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
        profileImageView.tintColor = .systemGray4
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 60

        container.addArrangedSubview(profileImageView)

        NSLayoutConstraint.activate([
            profileImageView.widthAnchor.constraint(equalToConstant: 120),
            profileImageView.heightAnchor.constraint(equalToConstant: 120)
        ])

        // MARK: - Name & Email
        nameLabel.text = "Shaurya"
        nameLabel.font = .boldSystemFont(ofSize: 22)

        emailLabel.text = "shaurya@gmail.com"
        emailLabel.font = .systemFont(ofSize: 14)
        emailLabel.textColor = .secondaryLabel

        container.addArrangedSubview(nameLabel)
        container.addArrangedSubview(emailLabel)

        // MARK: - Edit Profile Button
        editProfileButton.setTitle("Edit Profile", for: .normal)
        editProfileButton.backgroundColor = AppColors.accent
        editProfileButton.tintColor = .white
        editProfileButton.layer.cornerRadius = 10
        editProfileButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        editProfileButton.translatesAutoresizingMaskIntoConstraints = false
        editProfileButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)

        container.addArrangedSubview(editProfileButton)

        NSLayoutConstraint.activate([
            editProfileButton.widthAnchor.constraint(equalToConstant: 200),
            editProfileButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func makeStat(title: String, value: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 3

        let valLabel = UILabel()
        valLabel.text = value
        valLabel.font = .boldSystemFont(ofSize: 18)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabel

        stack.addArrangedSubview(valLabel)
        stack.addArrangedSubview(titleLabel)

        return stack
    }

    private func makeDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .systemGray6
        divider.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return divider
    }

    @objc private func editProfileTapped() {
        let editProfileVC = EditProfileViewController()
        let nav = UINavigationController(rootViewController: editProfileVC)
        nav.modalPresentationStyle = .formSheet

        present(nav, animated: true)
    }

}

// MARK: - TableView Delegates
extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sec = Section(rawValue: section)!
        return items[sec]?.count ?? 0
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let section = Section(rawValue: indexPath.section)!
        let item = items[section]![indexPath.row]

        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath) as! ProfileCell

        cell.configure(icon: item.icon, title: item.title)
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let section = Section(rawValue: indexPath.section)!
        let item = items[section]![indexPath.row]

        if section == .preferences && item.title == "Appearance" {
            let vc = AppearanceViewController()
            navigationController?.pushViewController(vc, animated: true)
            return
        }

        print("Tapped:", item.title)
    }
}
