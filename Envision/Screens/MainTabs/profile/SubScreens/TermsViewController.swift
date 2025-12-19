//
//  TermsViewController.swift
//  Envision
//

import UIKit

class TermsViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Terms of Service"
        view.backgroundColor = .systemBackground
        
        setupUI()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentLabel.numberOfLines = 0
        contentLabel.font = .systemFont(ofSize: 15)
        contentLabel.textColor = .label
        contentLabel.text = termsText
        
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
    
    private let termsText = """
    TERMS OF SERVICE
    
    Last Updated: December 2025
    
    1. ACCEPTANCE OF TERMS
    
    By accessing and using EnVision ("the App"), you accept and agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.
    
    2. DESCRIPTION OF SERVICE
    
    EnVision is a room and furniture scanning application that allows users to:
    • Scan rooms using RoomPlan technology
    • Capture 3D models of furniture and objects
    • Store and manage scanned models locally
    • Visualize models in augmented reality
    
    3. USER RESPONSIBILITIES
    
    You agree to:
    • Use the App only for lawful purposes
    • Not misuse or attempt to reverse engineer the App
    • Ensure you have permission to scan spaces that are not your own
    • Keep your account credentials secure
    
    4. PRIVACY
    
    Your privacy is important to us. All scanned data is stored locally on your device. We do not collect or transmit your room scans to external servers without your explicit consent.
    
    5. INTELLECTUAL PROPERTY
    
    The App and its original content, features, and functionality are owned by EnVision and are protected by international copyright, trademark, and other intellectual property laws.
    
    6. DISCLAIMER
    
    The App is provided "as is" without warranties of any kind. We do not guarantee the accuracy of room measurements or 3D model representations.
    
    7. LIMITATION OF LIABILITY
    
    EnVision shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the App.
    
    8. CHANGES TO TERMS
    
    We reserve the right to modify these terms at any time. Continued use of the App after changes constitutes acceptance of the new terms.
    
    9. CONTACT
    
    For questions about these Terms, please contact us through the App's feedback feature.
    """
}
