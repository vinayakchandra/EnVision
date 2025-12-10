//
//  AppInfoViewController.swift
//  Envision
//

import UIKit

class AppInfoViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    private let appInfo: [(title: String, value: String)] = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let iosVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        
        return [
            ("App Version", version),
            ("Build Number", build),
            ("iOS Version", iosVersion),
            ("Device", deviceModel)
        ]
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "App Info"
        view.backgroundColor = .systemBackground
        
        setupTableView()
        setupHeader()
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "InfoCell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupHeader() {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 180))
        
        let iconView = UIImageView(image: UIImage(named: "envision"))
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = "EnVision"
        nameLabel.font = .boldSystemFont(ofSize: 24)
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let taglineLabel = UILabel()
        taglineLabel.text = "Scan & Visualize Your Space"
        taglineLabel.font = .systemFont(ofSize: 14)
        taglineLabel.textColor = .secondaryLabel
        taglineLabel.textAlignment = .center
        taglineLabel.translatesAutoresizingMaskIntoConstraints = false
        
        header.addSubview(iconView)
        header.addSubview(nameLabel)
        header.addSubview(taglineLabel)
        
        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: header.topAnchor, constant: 20),
            iconView.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),
            
            nameLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
            nameLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            
            taglineLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            taglineLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor)
        ])
        
        tableView.tableHeaderView = header
    }
}

extension AppInfoViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? appInfo.count : 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "Information" : "Feedback"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "InfoCell", for: indexPath)
        
        if indexPath.section == 0 {
            let info = appInfo[indexPath.row]
            cell.textLabel?.text = info.title
            cell.detailTextLabel?.text = info.value
            cell.selectionStyle = .none
            
            let valueLabel = UILabel()
            valueLabel.text = info.value
            valueLabel.textColor = .secondaryLabel
            valueLabel.font = .systemFont(ofSize: 16)
            cell.accessoryView = valueLabel
            valueLabel.sizeToFit()
        } else {
            cell.textLabel?.text = "Rate This App"
            cell.textLabel?.textColor = AppColors.accent
            cell.accessoryView = nil
            cell.selectionStyle = .default
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 1 {
            // Open App Store for rating
            // Replace with your actual App Store ID
            if let url = URL(string: "itms-apps://itunes.apple.com/app/idYOUR_APP_ID?action=write-review") {
                UIApplication.shared.open(url)
            }
        }
    }
}
