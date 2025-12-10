//
//  PrivacyPolicyViewController.swift
//  Envision
//

import UIKit

class PrivacyPolicyViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Privacy Policy"
        view.backgroundColor = .systemBackground
        
        setupUI()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentLabel.numberOfLines = 0
        contentLabel.font = .systemFont(ofSize: 15)
        contentLabel.textColor = .label
        contentLabel.text = privacyText
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentLabel)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            contentLabel.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentLabel.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentLabel.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }
    
    private let privacyText = """
    PRIVACY POLICY
    
    Last Updated: December 2025
    
    1. INTRODUCTION
    
    EnVision ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.
    
    2. INFORMATION WE COLLECT
    
    Local Data Storage:
    • Room scans and 3D models are stored locally on your device
    • Profile information (name, email) is stored locally
    • App preferences and settings
    
    We DO NOT collect:
    • Location data
    • Personal photos (unless you choose to set a profile picture)
    • Room scan data on our servers
    
    3. HOW WE USE YOUR INFORMATION
    
    Your data is used solely to:
    • Provide app functionality
    • Store your scanned rooms and furniture models
    • Personalize your app experience
    • Improve app performance (if analytics enabled)
    
    4. DATA STORAGE
    
    All your scans and models are stored locally on your device. We do not upload or sync your room data to any external servers. Your data remains private and under your control.
    
    5. CAMERA AND SENSORS
    
    The App requires access to:
    • Camera: For scanning rooms and capturing objects
    • LiDAR sensor: For accurate depth measurement (if available)
    • Photo Library: For saving and importing images
    
    These permissions are used only for the intended scanning features.
    
    6. DATA SHARING
    
    We do not sell, trade, or share your personal information with third parties. You may choose to export and share your scanned models, but this is entirely at your discretion.
    
    7. DATA SECURITY
    
    We implement appropriate security measures to protect your locally stored data. However, no method of electronic storage is 100% secure.
    
    8. CHILDREN'S PRIVACY
    
    The App is not intended for children under 13. We do not knowingly collect information from children under 13.
    
    9. YOUR RIGHTS
    
    You have the right to:
    • Access your data (stored locally on your device)
    • Delete your data by uninstalling the app
    • Export your scanned models
    • Modify your profile information
    
    10. CHANGES TO THIS POLICY
    
    We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy in the App.
    
    11. CONTACT US
    
    If you have questions about this Privacy Policy, please contact us through the App's feedback feature.
    """
}
