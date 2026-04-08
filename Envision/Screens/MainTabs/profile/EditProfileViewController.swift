//
//  EditProfileViewController.swift
//  Envision
//
//  Created by admin55 on 13/11/25.
//


import UIKit
import FirebaseAuth

extension Notification.Name {
    static let profileDidUpdate = Notification.Name("profileDidUpdate")
    static let tourDidStart = Notification.Name("tourDidStart")
}

class EditProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private let photoContainerView = UIView()
    private let profileImageView = UIImageView()
    private let changePhotoButton = UIButton(type: .system)

    private let nameField = UITextField()
    private var selectedProfileImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Edit Profile"

        setupNavBar()
        setupForm()
        view.layoutIfNeeded()
        updateProfileImageMask()
        populateUserData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateProfileImageMask()
    }

    private func updateProfileImageMask() {
        let radius = min(profileImageView.bounds.width, profileImageView.bounds.height) / 2
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        profileImageView.layer.cornerRadius = radius
        profileImageView.layer.masksToBounds = true
        CATransaction.commit()
    }

    private func setupNavBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Save",
            style: .prominent,
            target: self,
            action: #selector(saveTapped)
        )
    }

    private func setupForm() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        photoContainerView.translatesAutoresizingMaskIntoConstraints = false
        photoContainerView.heightAnchor.constraint(equalToConstant: 150).isActive = true

        profileImageView.translatesAutoresizingMaskIntoConstraints = false
        profileImageView.image = UIImage(systemName: "person.crop.circle.fill")
        profileImageView.tintColor = .systemGray4
        profileImageView.contentMode = .scaleAspectFill
        profileImageView.layer.cornerRadius = 62
        profileImageView.clipsToBounds = true
        profileImageView.layer.masksToBounds = true
        profileImageView.layer.borderWidth = 3
        profileImageView.layer.borderColor = UIColor(hex: "#4A9085").withAlphaComponent(0.85).cgColor
        profileImageView.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.25)
        profileImageView.widthAnchor.constraint(equalToConstant: 124).isActive = true
        profileImageView.heightAnchor.constraint(equalToConstant: 124).isActive = true

        photoContainerView.addSubview(profileImageView)
        NSLayoutConstraint.activate([
            profileImageView.centerXAnchor.constraint(equalTo: photoContainerView.centerXAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: photoContainerView.centerYAnchor)
        ])

        var buttonConfig = UIButton.Configuration.plain()
        buttonConfig.title = "Change Profile Photo"
        buttonConfig.baseForegroundColor = UIColor(hex: "#33A1FF")
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        changePhotoButton.configuration = buttonConfig
        changePhotoButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        changePhotoButton.addTarget(self, action: #selector(changePhotoTapped), for: .touchUpInside)

        nameField.placeholder = "Name"
        nameField.borderStyle = .roundedRect

        stack.addArrangedSubview(photoContainerView)
        stack.addArrangedSubview(changePhotoButton)
        stack.addArrangedSubview(nameField)

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            stack.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
        ])
    }

    private func populateUserData() {
        if let firebaseUser = Auth.auth().currentUser {
            nameField.text = firebaseUser.displayName
                ?? UserManager.shared.currentUser?.name
                ?? firebaseUser.email?.components(separatedBy: "@").first?.capitalized
                ?? "User"
        } else {
            nameField.text = UserManager.shared.currentUser?.name ?? "User"
        }

        if let image = UserManager.shared.loadProfileImage() {
            profileImageView.image = image
            profileImageView.tintColor = nil
        } else if let photoURL = Auth.auth().currentUser?.photoURL {
            loadRemoteImage(photoURL)
        }
    }

    private func loadRemoteImage(_ url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.profileImageView.image = image
                self.profileImageView.tintColor = nil
            }
        }.resume()
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        let name = (nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            let alert = UIAlertController(title: "Name Required", message: "Please enter your name.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        UserManager.shared.updateProfile(name: name)

        if let image = selectedProfileImage {
            let saved = UserManager.shared.saveProfileImage(image)
            if !saved {
                let alert = UIAlertController(
                    title: "Image Save Failed",
                    message: "Could not save profile image. Please try another image.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
                return
            }
        }

        if let firebaseUser = Auth.auth().currentUser {
            let request = firebaseUser.createProfileChangeRequest()
            request.displayName = name
            request.commitChanges { [weak self] error in
                DispatchQueue.main.async {
                    if let error {
                        let alert = UIAlertController(
                            title: "Saved Locally",
                            message: "Profile saved on device, but cloud profile update failed: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                            self?.dismiss(animated: true)
                        })
                        self?.present(alert, animated: true)
                        return
                    }
                    NotificationCenter.default.post(name: .profileDidUpdate, object: nil)
                    self?.dismiss(animated: true)
                }
            }
            return
        }

        NotificationCenter.default.post(name: .profileDidUpdate, object: nil)
        dismiss(animated: true)
    }

    @objc private func changePhotoTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true // built-in square crop
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let edited = info[.editedImage] as? UIImage
        let original = info[.originalImage] as? UIImage
        guard let picked = edited ?? original else { return }

        let square = picked.croppedToSquare()
        selectedProfileImage = square
        profileImageView.image = square
        profileImageView.tintColor = nil
    }
}

private extension UIImage {
    func croppedToSquare() -> UIImage {
        let originalSize = size
        let side = min(originalSize.width, originalSize.height)
        let originX = (originalSize.width - side) / 2.0
        let originY = (originalSize.height - side) / 2.0
        let cropRect = CGRect(x: originX, y: originY, width: side, height: side)

        guard let cgImage = self.cgImage?.cropping(to: cropRect) else { return self }
        return UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)
    }
}
