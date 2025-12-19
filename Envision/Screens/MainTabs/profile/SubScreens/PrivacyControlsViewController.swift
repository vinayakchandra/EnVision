//
//  PrivacyControlsViewController.swift
//  Envision
//

import UIKit

class PrivacyControlsViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    private var settings: [(title: String, subtitle: String, key: String, isOn: Bool)] = [
        ("Analytics", "Help improve the app by sharing usage data", "analytics", false),
        ("Crash Reports", "Automatically send crash reports", "crashReports", true),
        ("Personalized Experience", "Allow personalized recommendations", "personalized", true)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Privacy Controls"
        view.backgroundColor = .systemBackground
        
        loadSettings()
        setupTableView()
    }
    
    private func loadSettings() {
        for i in 0..<settings.count {
            settings[i].isOn = UserDefaults.standard.bool(forKey: "privacy_\(settings[i].key)")
        }
        // Set defaults for first launch
        if !UserDefaults.standard.bool(forKey: "privacy_settings_initialized") {
            UserDefaults.standard.set(true, forKey: "privacy_crashReports")
            UserDefaults.standard.set(true, forKey: "privacy_personalized")
            UserDefaults.standard.set(true, forKey: "privacy_settings_initialized")
            loadSettings()
        }
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SwitchCell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    @objc private func switchChanged(_ sender: UISwitch) {
        let key = settings[sender.tag].key
        settings[sender.tag].isOn = sender.isOn
        UserDefaults.standard.set(sender.isOn, forKey: "privacy_\(key)")
    }
}

extension PrivacyControlsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? settings.count : 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Data Sharing" : "Your Data"
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "These settings control how your data is used to improve the app experience."
        }
        return nil
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
        
        if indexPath.section == 0 {
            let setting = settings[indexPath.row]
            
            var config = cell.defaultContentConfiguration()
            config.text = setting.title
            config.secondaryText = setting.subtitle
            config.secondaryTextProperties.color = .secondaryLabel
            config.secondaryTextProperties.font = .systemFont(ofSize: 12)
            cell.contentConfiguration = config
            cell.selectionStyle = .none
            
            let toggle = UISwitch()
            toggle.isOn = setting.isOn
            toggle.tag = indexPath.row
            toggle.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggle
        } else {
            var config = cell.defaultContentConfiguration()
            config.text = "Request My Data"
            config.textProperties.color = AppColors.accent
            config.image = UIImage(systemName: "arrow.down.doc.fill")
            config.imageProperties.tintColor = AppColors.accent
            cell.contentConfiguration = config
            cell.accessoryView = nil
            cell.selectionStyle = .default
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 1 {
            let alert = UIAlertController(
                title: "Request Data",
                message: "Your data is stored locally on your device. You can export your scanned rooms and furniture models from their respective tabs.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
