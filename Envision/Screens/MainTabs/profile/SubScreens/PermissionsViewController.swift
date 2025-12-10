//
//  PermissionsViewController.swift
//  Envision
//

import UIKit
import AVFoundation
import Photos

class PermissionsViewController: UIViewController {
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    private enum Permission: CaseIterable {
        case camera
        case photoLibrary
        
        var title: String {
            switch self {
            case .camera: return "Camera"
            case .photoLibrary: return "Photo Library"
            }
        }
        
        var icon: String {
            switch self {
            case .camera: return "camera.fill"
            case .photoLibrary: return "photo.fill"
            }
        }
        
        var description: String {
            switch self {
            case .camera: return "Required for scanning rooms and furniture"
            case .photoLibrary: return "Required for saving and importing photos"
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Permissions"
        view.backgroundColor = .systemBackground
        
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PermissionCell")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func getPermissionStatus(for permission: Permission) -> (status: String, color: UIColor) {
        switch permission {
        case .camera:
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            switch status {
            case .authorized: return ("Allowed", .systemGreen)
            case .denied, .restricted: return ("Denied", .systemRed)
            case .notDetermined: return ("Not Set", .systemOrange)
            @unknown default: return ("Unknown", .systemGray)
            }
            
        case .photoLibrary:
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch status {
            case .authorized, .limited: return ("Allowed", .systemGreen)
            case .denied, .restricted: return ("Denied", .systemRed)
            case .notDetermined: return ("Not Set", .systemOrange)
            @unknown default: return ("Unknown", .systemGray)
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

extension PermissionsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Permission.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PermissionCell", for: indexPath)
        let permission = Permission.allCases[indexPath.row]
        let (status, color) = getPermissionStatus(for: permission)
        
        var config = cell.defaultContentConfiguration()
        config.image = UIImage(systemName: permission.icon)
        config.imageProperties.tintColor = AppColors.accent
        config.text = permission.title
        config.secondaryText = permission.description
        config.secondaryTextProperties.color = .secondaryLabel
        config.secondaryTextProperties.font = .systemFont(ofSize: 12)
        
        cell.contentConfiguration = config
        
        let statusLabel = UILabel()
        statusLabel.text = status
        statusLabel.textColor = color
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.sizeToFit()
        cell.accessoryView = statusLabel
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let alert = UIAlertController(
            title: "Change Permission",
            message: "To change this permission, please go to Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { [weak self] _ in
            self?.openSettings()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Tap on a permission to change it in Settings. Some features may not work without proper permissions."
    }
}
