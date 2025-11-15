import UIKit

final class ARIntroViewController: UIViewController {
    
    private let cardView = UIView()
    private let infoLabel = UILabel()
    private let continueButton = PrimaryButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = "Scan Your Room"
        view.backgroundColor = AppColors.background

        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 20
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowRadius = 10
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        infoLabel.text = """
        Before you start scanning:

        • Point your device at all walls, doors, and furniture.
        • Move slowly to ensure accurate capture.
        • You can preview and save your scan afterward.
        """
        infoLabel.font = AppFonts.regular(15)
        infoLabel.textColor = AppColors.textPrimary
        infoLabel.numberOfLines = 0
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        
        continueButton.setTitle("Continue", for: .normal)
        continueButton.addTarget(self, action: #selector(startScanning), for: .touchUpInside)
        continueButton.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(cardView)
        cardView.addSubview(infoLabel)
        view.addSubview(continueButton)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            infoLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            infoLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            infoLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
            
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    @objc private func startScanning() {
        let scanVC = RoomScanViewController()
        navigationController?.pushViewController(scanVC, animated: true)
    }
}
