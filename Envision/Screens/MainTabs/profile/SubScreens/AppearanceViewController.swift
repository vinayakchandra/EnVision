//
//  AppearanceViewController.swift
//  Envision
//
//  Created by admin55 on 17/11/25.
//


import UIKit

class AppearanceViewController: UIViewController {
    
    private let themeControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Light", "Dark", "System"])
        control.selectedSegmentIndex = 2 // default: system
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Appearance"
        view.backgroundColor = .systemBackground
        
        setupUI()
        loadSavedTheme()
        
        themeControl.addTarget(self, action: #selector(themeChanged), for: .valueChanged)
    }
    
    private func setupUI() {
        view.addSubview(themeControl)
        
        NSLayoutConstraint.activate([
            themeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            themeControl.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            themeControl.widthAnchor.constraint(equalToConstant: 260)
        ])
    }
    
    // MARK: - Theme Change Logic
    
    @objc private func themeChanged() {
        let selected = themeControl.selectedSegmentIndex
        
        switch selected {
        case 0:
            applyTheme(.light)
        case 1:
            applyTheme(.dark)
        default:
            applyTheme(.unspecified) // system
        }
        
        UserDefaults.standard.set(selected, forKey: "selectedTheme")
    }
    
    private func loadSavedTheme() {
        let saved = UserDefaults.standard.integer(forKey: "selectedTheme")
        themeControl.selectedSegmentIndex = saved
        themeChanged()
    }
    
    private func applyTheme1(_ style: UIUserInterfaceStyle) {
        // Apply to entire app window
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.overrideUserInterfaceStyle = style
        }
    }
    private func applyTheme(_ style: UIUserInterfaceStyle) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {

            // Smooth crossfade animation
            UIView.transition(with: window,
                              duration: 0.35,
                              options: [.transitionCrossDissolve, .allowAnimatedContent],
                              animations: {
                                  window.overrideUserInterfaceStyle = style
                              },
                              completion: nil)
        }
    }


}
