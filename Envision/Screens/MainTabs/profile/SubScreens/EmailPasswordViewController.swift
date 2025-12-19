//
//  EmailPasswordViewController.swift
//  Envision
//

import UIKit

class EmailPasswordViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Email & Password"
        view.backgroundColor = .systemBackground
        
        setupTableView()
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func showChangeEmailAlert() {
        let alert = UIAlertController(title: "Change Email", message: "Enter your new email address", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "New email"
            textField.keyboardType = .emailAddress
            textField.autocapitalizationType = .none
            textField.text = UserManager.shared.currentUser?.email
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let email = alert.textFields?.first?.text, !email.isEmpty else { return }
            
            if email.isValidEmail {
                UserManager.shared.updateProfile(email: email)
                self?.showToast("Email updated successfully")
                self?.tableView.reloadData()
            } else {
                self?.showToast("Please enter a valid email")
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showChangePasswordAlert() {
        let alert = UIAlertController(title: "Change Password", message: "Password changes are stored locally", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Current password"
            textField.isSecureTextEntry = true
        }
        
        alert.addTextField { textField in
            textField.placeholder = "New password"
            textField.isSecureTextEntry = true
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Confirm new password"
            textField.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Change", style: .default) { [weak self] _ in
            guard let newPassword = alert.textFields?[1].text,
                  let confirmPassword = alert.textFields?[2].text else { return }
            
            if newPassword == confirmPassword && newPassword.count >= 8 {
                self?.showToast("Password changed successfully")
            } else if newPassword != confirmPassword {
                self?.showToast("Passwords don't match")
            } else {
                self?.showToast("Password must be at least 8 characters")
            }
        })
        
        present(alert, animated: true)
    }
    
    private func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
}

extension EmailPasswordViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Email" : "Password"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        var config = cell.defaultContentConfiguration()
        
        if indexPath.section == 0 {
            config.text = "Change Email"
            config.secondaryText = UserManager.shared.currentUser?.email ?? "Not set"
            config.image = UIImage(systemName: "envelope.fill")
        } else {
            config.text = "Change Password"
            config.secondaryText = "••••••••"
            config.image = UIImage(systemName: "lock.fill")
        }
        
        config.imageProperties.tintColor = AppColors.accent
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            showChangeEmailAlert()
        } else {
            showChangePasswordAlert()
        }
    }
}
