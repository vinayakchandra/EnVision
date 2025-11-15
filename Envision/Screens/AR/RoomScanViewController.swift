import UIKit

final class RoomScanViewController: UIViewController {
    
    private let scanPreview = UIImageView(image: UIImage(systemName: "cube.transparent"))
    private let saveButton = PrimaryButton()
    private let instructionLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = "Scan Your Room"
        view.backgroundColor = .black
        
        scanPreview.tintColor = .white.withAlphaComponent(0.6)
        scanPreview.contentMode = .scaleAspectFit
        scanPreview.translatesAutoresizingMaskIntoConstraints = false
        
        instructionLabel.text = "Move your device slowly to scan the room."
        instructionLabel.textColor = .white
        instructionLabel.font = AppFonts.regular(16)
        instructionLabel.textAlignment = .center
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        saveButton.setTitle("Save", for: .normal)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        
        [scanPreview, instructionLabel, saveButton].forEach { view.addSubview($0) }
        
        NSLayoutConstraint.activate([
            scanPreview.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanPreview.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanPreview.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.6),
            scanPreview.heightAnchor.constraint(equalTo: scanPreview.widthAnchor),
            
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            saveButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            saveButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    @objc private func saveTapped() {
        navigationController?.popToRootViewController(animated: true)
    }
}
