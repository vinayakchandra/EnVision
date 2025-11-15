import UIKit

final class ScanFurnitureViewController: UIViewController {

    private let titleLabel = UILabel()
    private let infoLabel = UILabel()
    private let startScanButton = PrimaryButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = "Scan Furniture"
        view.backgroundColor = AppColors.background
        
        titleLabel.text = "Scan Furniture"
        titleLabel.font = AppFonts.bold(22)
        titleLabel.textColor = AppColors.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        infoLabel.text = "Use your camera to capture and convert any furniture item into a 3D model."
        infoLabel.font = AppFonts.regular(16)
        infoLabel.textColor = AppColors.textSecondary
        infoLabel.numberOfLines = 0
        infoLabel.textAlignment = .center
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        startScanButton.setTitle("Start Scanning", for: .normal)
        startScanButton.addTarget(self, action: #selector(startScanTapped), for: .touchUpInside)
        startScanButton.translatesAutoresizingMaskIntoConstraints = false
        
        [titleLabel, infoLabel, startScanButton].forEach { view.addSubview($0) }
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            infoLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            startScanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            startScanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            startScanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            startScanButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func startScanTapped() {
        let scanVC = RoomScanViewController()
        navigationController?.pushViewController(scanVC, animated: true)
    }
}
