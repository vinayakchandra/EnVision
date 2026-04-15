//
//  ProfileViewController.swift
//  Envision
//

import UIKit
import FirebaseAuth

class ProfileViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    // MARK: - Profile Components
    private let profileHeaderView = UIView()
    private let profileImageView = UIImageView()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let editProfileButton = UIButton(type: .system)

    // MARK: - Sections & Items
    private enum Section: Int, CaseIterable {
        case account
        case preferences
        case privacy
        case about
        case logout

        var title: String? {
            switch self {
            case .account: return "Account"
            case .preferences: return "Preferences"
            case .privacy: return "Privacy & Security"
            case .about: return "About"
            case .logout: return nil
            }
        }
    }

    private let items: [Section: [(icon: String, title: String, isDestructive: Bool)]] = [
        .account: [
            ("person.crop.circle", "My Profile", false),
        ],
        .preferences: [
            ("paintbrush.fill", "Appearance", false),
            ("bell.badge.fill", "Notifications", false),
        ],
        .privacy: [
            ("lock.fill", "Privacy Controls", false),
            ("hand.raised.fill", "Permissions", false),
            // ("key.fill", "Security", false),
        ],
        .about: [
            ("info.circle.fill", "App Info", false),
            ("lightbulb.fill", "Tips & Tutorials", false),
            ("arrow.counterclockwise", "Restart App Tour", false),
            ("doc.text.fill", "Terms of Service", false),
            ("shield.lefthalf.filled", "Privacy Policy", false),
        ],
        .logout: [
            ("rectangle.portrait.and.arrow.right", "Sign Out", true),
            ("trash.fill", "Delete Account", true),
        ],
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Profile"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground

        setupTable()
        setupProfileHeader()
        setupFooter()
        tableView.tableHeaderView = profileHeaderView
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileDidUpdate), name: .profileDidUpdate, object: nil)
        refreshProfileHeader()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .profileDidUpdate, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProfileHeader()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        profileImageView.layer.cornerRadius = min(profileImageView.bounds.width, profileImageView.bounds.height) / 2
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
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // MARK: - Profile Header Setup
    private func setupProfileHeader() {
        profileHeaderView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 260)

        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 12
        container.translatesAutoresizingMaskIntoConstraints = false
        profileHeaderView.addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: profileHeaderView.topAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: profileHeaderView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: profileHeaderView.trailingAnchor),
        ])

        // Profile Image
        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
        profileImageView.tintColor = .systemGray4
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.clipsToBounds = true
        profileImageView.layer.cornerRadius = 55
        profileImageView.layer.borderWidth = 4
        profileImageView.layer.borderColor = UIColor(hex: "#4A9085").withAlphaComponent(0.85).cgColor
        profileImageView.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.25)

        container.addArrangedSubview(profileImageView)

        NSLayoutConstraint.activate([
            profileImageView.widthAnchor.constraint(equalToConstant: 110),
            profileImageView.heightAnchor.constraint(equalToConstant: 110),
        ])

        // MARK: - Name & Email
        nameLabel.text = "User"
        nameLabel.font = .boldSystemFont(ofSize: 22)

        emailLabel.text = "No email"
        emailLabel.font = .systemFont(ofSize: 14)
        emailLabel.textColor = .secondaryLabel

        container.addArrangedSubview(nameLabel)
        container.addArrangedSubview(emailLabel)

        // Edit Profile Button
        editProfileButton.setTitle("Edit Profile", for: .normal)
        editProfileButton.backgroundColor = AppColors.accent
        editProfileButton.setTitleColor(.white, for: .normal)
        editProfileButton.layer.cornerRadius = 10
        editProfileButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        editProfileButton.translatesAutoresizingMaskIntoConstraints = false
        editProfileButton.addTarget(self, action: #selector(editProfileTapped), for: .touchUpInside)

        container.addArrangedSubview(editProfileButton)

        NSLayoutConstraint.activate([
            editProfileButton.widthAnchor.constraint(equalToConstant: 200),
            editProfileButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func refreshProfileHeader() {
        if let firebaseUser = Auth.auth().currentUser {
            let resolvedName = firebaseUser.displayName
                ?? firebaseUser.email?.components(separatedBy: "@").first?.capitalized
                ?? "User"
            nameLabel.text = resolvedName
            emailLabel.text = firebaseUser.email ?? "No email"

            let syncedUser = UserModel(
                id: firebaseUser.uid,
                name: resolvedName,
                email: firebaseUser.email ?? ""
            )
            UserManager.shared.currentUser = syncedUser

            if let localImage = UserManager.shared.loadProfileImage() {
                profileImageView.image = localImage
                profileImageView.tintColor = nil
            } else if let photoURL = firebaseUser.photoURL {
                loadProfileImage(from: photoURL)
            } else {
                profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
                profileImageView.tintColor = .systemGray4
            }
            return
        }

        if let user = UserManager.shared.currentUser {
            nameLabel.text = user.name
            emailLabel.text = user.email

            if let localImage = UserManager.shared.loadProfileImage() {
                profileImageView.image = localImage
                profileImageView.tintColor = nil
            } else {
                profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
                profileImageView.tintColor = .systemGray4
            }
            return
        }

        nameLabel.text = "User"
        emailLabel.text = "No email"
        profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
        profileImageView.tintColor = .systemGray4
    }

    private func loadProfileImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let image = UIImage(data: data)
            else { return }

            DispatchQueue.main.async {
                self.profileImageView.image = image
                self.profileImageView.tintColor = nil
            }
        }.resume()
    }

    @objc private func handleProfileDidUpdate() {
        refreshProfileHeader()
        tableView.reloadData()
    }

    // Logout
    private func handleDeleteAccount() {
        HapticsManager.shared.warning()
        let sheet = UIAlertController(
            title: "Delete Account",
            message: "This will permanently delete your account and all associated data. This action cannot be undone.",
            preferredStyle: .actionSheet
        )

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.addAction(
            UIAlertAction(title: "Delete Account", style: .destructive) { [weak self] _ in
                self?.confirmDeleteAccount()
            })

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(sheet, animated: true)
    }

    private func confirmDeleteAccount() {
        let confirm = UIAlertController(
            title: "Are you sure?",
            message: "Your account will be permanently deleted. You cannot recover it.",
            preferredStyle: .alert
        )

        confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        confirm.addAction(
            UIAlertAction(title: "Yes, Delete", style: .destructive) { [weak self] _ in
                self?.performDeleteAccount()
            })

        present(confirm, animated: true)
    }

    private func performDeleteAccount() {
        AuthManager.shared.deleteAccount { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    HapticsManager.shared.success()
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let sceneDelegate = scene.delegate as? SceneDelegate {
                        sceneDelegate.switchToLogin()
                    }
                case .failure(let error):
                    HapticsManager.shared.error()
                    let alert = UIAlertController(
                        title: "Delete Failed",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    private func handleLogout() {
        HapticsManager.shared.warning()
        let alert = UIAlertController(
            title: "Sign Out",
            message: "Are you sure you want to sign out?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
                self?.performLogout()
            })

        present(alert, animated: true)
    }

    private func performLogout() {
        do {
            try AuthManager.shared.signOut()
        } catch {
            HapticsManager.shared.error()
            let alert = UIAlertController(
                title: "Sign Out Failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        // Navigate back to login
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let sceneDelegate = scene.delegate as? SceneDelegate
        {
            sceneDelegate.switchToLogin()
        }
    }

    // MARK: - Footer
    private func setupFooter() {
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 60))

        let versionLabel = UILabel()
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        versionLabel.textAlignment = .center
        versionLabel.font = .systemFont(ofSize: 12)
        versionLabel.textColor = .tertiaryLabel

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        versionLabel.text = "Version \(version) (\(build))"

        footer.addSubview(versionLabel)
        NSLayoutConstraint.activate([
            versionLabel.centerXAnchor.constraint(equalTo: footer.centerXAnchor),
            versionLabel.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
        ])

        tableView.tableFooterView = footer
    }

    @objc private func editProfileTapped() {
        HapticsManager.shared.impactLight()
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
        cell.configure(icon: item.icon, title: item.title, isDestructive: item.isDestructive)

        if section == .logout {
            cell.accessoryType = .none
        } else {
            cell.accessoryType = .disclosureIndicator
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        HapticsManager.shared.selection()

        let section = Section(rawValue: indexPath.section)!
        let item = items[section]![indexPath.row]

        switch (section, item.title) {
        case (.account, "My Profile"):
            editProfileTapped()

        case (.preferences, "Appearance"):
            navigationController?.pushViewController(AppearanceViewController(), animated: true)

        case (.preferences, "Notifications"):
            navigationController?.pushViewController(NotificationsViewController(), animated: true)

        case (.privacy, "Privacy Controls"):
            navigationController?.pushViewController(PrivacyControlsViewController(), animated: true)

        case (.privacy, "Permissions"):
            navigationController?.pushViewController(PermissionsViewController(), animated: true)
            
        case (.about, "Tips & Tutorials"):
            navigationController?.pushViewController(TipsLibraryViewController(), animated: true)

        case (.about, "Restart App Tour"):
            handleRestartTour()

        case (.about, "App Info"):
            navigationController?.pushViewController(AppInfoViewController(), animated: true)

        case (.about, "Terms of Service"):
            navigationController?.pushViewController(TermsViewController(), animated: true)

        case (.about, "Privacy Policy"):
            navigationController?.pushViewController(PrivacyPolicyViewController(), animated: true)

        case (.logout, "Sign Out"):
            handleLogout()

        case (.logout, "Delete Account"):
            handleDeleteAccount()

        default:
            break
        }

        print("Tapped:", item.title)
    }
    
    private func handleRestartTour() {
        let alert = UIAlertController(
            title: "Restart App Tour?",
            message: "This will reset all tips and guided tours.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Restart", style: .default) { _ in
            HapticsManager.shared.success()
            TourManager.shared.resetTour()
            
            let confirm = UIAlertController(title: "Tour Reset", message: "The app tour will appear again as you navigate.", preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                guard let self else { return }
                self.tabBarController?.selectedIndex = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    (self.tabBarController as? MainTabBarController)?.showWelcomeTipIfNeeded()
                }
            })
            self.present(confirm, animated: true)
        })
        
        present(alert, animated: true)
    }
}
