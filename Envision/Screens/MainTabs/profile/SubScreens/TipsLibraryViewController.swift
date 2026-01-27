//
//  TipsLibraryViewController.swift
//  Envision
//

import UIKit

final class TipsLibraryViewController: UIViewController {

    // MARK: - Data
    struct TipItem {
        let title: String
        let message: String
        let icon: String
        let color: UIColor
    }
    
    struct TipSection {
        let title: String
        let items: [TipItem]
    }
    
    private var sections: [TipSection] = []

    // MARK: - UI
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(TipLibraryCell.self, forCellReuseIdentifier: "TipCell")
        return tv
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Tips & Tutorials"
        view.backgroundColor = .systemGroupedBackground
        
        setupData()
        setupUI()
    }
    
    private func setupData() {
        // Prepare static data matching the real tips
        // This allows viewing tips regardless of TipKit state rules
        
        sections = [
            TipSection(title: "Getting Started", items: [
                TipItem(title: "Welcome to EnVision", message: "Take a tour to learn how to scan rooms and furniture.", icon: "hand.wave.fill", color: .systemBlue),
                TipItem(title: "Customize Your Profile", message: "Set your preferences and personalize your experience.", icon: "person.crop.circle", color: .systemOrange)
            ]),
            
            TipSection(title: "Room Scanning", items: [
                TipItem(title: "Scan Your First Room", message: "Use the green camera button to start scanning with LiDAR.", icon: "camera.viewfinder", color: .systemGreen),
                TipItem(title: "Scan Slowly", message: "Move your device slowly for the best accuracy.", icon: "tortoise.fill", color: .systemTeal),
                TipItem(title: "Import Models", message: "Bring in existing USDZ models from Files.", icon: "square.and.arrow.down", color: .systemIndigo)
            ]),
            
            TipSection(title: "Furniture Capture", items: [
                TipItem(title: "Capture Furniture", message: "Scan objects using 360° photogrammetry.", icon: "camera.metering.center.weighted", color: .systemPurple),
                TipItem(title: "Good Lighting", message: "Ensure even lighting and avoid harsh shadows.", icon: "sun.max.fill", color: .systemYellow),
                TipItem(title: "360° Coverage", message: "Walk around the entire object to capture all angles.", icon: "arrow.triangle.2.circlepath.camera", color: .systemRed)
            ]),
            
            TipSection(title: "Organization", items: [
                TipItem(title: "Categories", message: "Organize your rooms and furniture with smart categories.", icon: "tag.fill", color: .systemPink),
                TipItem(title: "Actions Menu", message: "Select, delete, or share multiple items at once.", icon: "ellipsis.circle", color: .systemGray)
            ])
        ]
    }

    private func setupUI() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        tableView.dataSource = self
        tableView.delegate = self
    }
}

// MARK: - UITableViewDataSource
extension TipsLibraryViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "TipCell", for: indexPath) as? TipLibraryCell else {
            return UITableViewCell()
        }
        
        let item = sections[indexPath.section].items[indexPath.row]
        cell.configure(item: item)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Could expand or show detail VC if needed
    }
}

// MARK: - Cell
final class TipLibraryCell: UITableViewCell {
    
    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.layer.cornerRadius = 8
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        
        iconContainer.addSubview(iconView)
        contentView.addSubview(iconContainer)
        contentView.addSubview(titleLabel)
        contentView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            iconContainer.widthAnchor.constraint(equalToConstant: 32),
            iconContainer.heightAnchor.constraint(equalToConstant: 32),
            
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.topAnchor.constraint(equalTo: iconContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            messageLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(item: TipsLibraryViewController.TipItem) {
        titleLabel.text = item.title
        messageLabel.text = item.message
        iconView.image = UIImage(systemName: item.icon)
        iconContainer.backgroundColor = item.color
    }
}
