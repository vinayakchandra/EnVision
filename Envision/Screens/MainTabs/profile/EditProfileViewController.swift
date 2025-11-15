//
//  EditProfileViewController.swift
//  Envision
//
//  Created by admin55 on 13/11/25.
//


import UIKit

class EditProfileViewController: UIViewController {

    private let nameField = UITextField()
    private let emailField = UITextField()
    private let bioField = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Edit Profile"

        setupNavBar()
        setupForm()
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
            style: .done,
            target: self,
            action: #selector(saveTapped)
        )
    }

    private func setupForm() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false

        nameField.placeholder = "Name"
        nameField.borderStyle = .roundedRect
        nameField.text = "John Doe"

        emailField.placeholder = "Email"
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.borderStyle = .roundedRect
        emailField.text = "john.doe@example.com"

        bioField.layer.cornerRadius = 8
        bioField.layer.borderWidth = 1
        bioField.layer.borderColor = UIColor.systemGray4.cgColor
        bioField.text = "iOS Developer"
        bioField.font = .systemFont(ofSize: 16)
        bioField.heightAnchor.constraint(equalToConstant: 120).isActive = true

        stack.addArrangedSubview(nameField)
        stack.addArrangedSubview(emailField)
        stack.addArrangedSubview(bioField)

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20),
            stack.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20),
        ])
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func saveTapped() {
        // Your save logic here
        dismiss(animated: true)
    }
}
