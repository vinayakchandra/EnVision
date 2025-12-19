//
//  NotificationsViewController.swift
//  Envision
//

import UIKit

class NotificationsViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    private var settings: [(title: String, key: String, isOn: Bool)] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Notifications"
        view.backgroundColor = .systemBackground
        
        loadSettings()
        setupTableView()
    }
    
    private func loadSettings() {
        let prefs = UserManager.shared.currentUser?.preferences ?? UserPreferences()
        settings = [
            ("All Notifications", "notificationsEnabled", prefs.notificationsEnabled),
            ("Scan Reminders", "scanReminders", prefs.scanReminders),
            ("New Feature Alerts", "newFeatureAlerts", prefs.newFeatureAlerts)
        ]
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
        
        switch key {
        case "notificationsEnabled":
            UserManager.shared.setNotificationsEnabled(sender.isOn)
        case "scanReminders":
            UserManager.shared.setScanReminders(sender.isOn)
        case "newFeatureAlerts":
            UserManager.shared.setNewFeatureAlerts(sender.isOn)
        default:
            break
        }
    }
}

extension NotificationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath)
        let setting = settings[indexPath.row]
        
        cell.textLabel?.text = setting.title
        cell.selectionStyle = .none
        
        let toggle = UISwitch()
        toggle.isOn = setting.isOn
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(switchChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Enable notifications to receive updates about your scans and new features."
    }
}
