import UIKit

final class ForgotPasswordViewController: UIViewController {

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Single circular back button
//    private let backButton: UIButton = {
//        let btn = UIButton(type: .system)
//        btn.setImage(UIImage(systemName: "chevron.left"), for: .normal)
//        btn.tintColor = .label
//        btn.backgroundColor = .white
//        btn.layer.cornerRadius = 20
//        btn.layer.shadowColor = UIColor.black.cgColor
//        btn.layer.shadowOpacity = 0.12
//        btn.layer.shadowRadius = 4
//        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
//        btn.translatesAutoresizingMaskIntoConstraints = false
//        return btn
//    }()

    private let logoImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "envision"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Forgot Password"
        lbl.font = .systemFont(ofSize: 30, weight: .bold)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let subtitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Enter your email and we’ll send password reset instructions"
        lbl.font = .systemFont(ofSize: 15)
        lbl.textColor = .secondaryLabel
        lbl.numberOfLines = 0
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let emailField = ModernTextField(placeholder: "Enter your email")

    private let errorLabel: UILabel = {
        let lbl = UILabel()
        lbl.textColor = .systemRed
        lbl.font = .systemFont(ofSize: 14)
        lbl.numberOfLines = 0
        lbl.textAlignment = .center
        lbl.alpha = 0
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    private let continueButton = PrimaryButton1(title: "Continue")

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
//        navigationController?.setNavigationBarHidden(true, animated: false)

        setupScroll()
        setupLayout()
        setupActions()
    }

    // MARK: - Setup

    private func setupScroll() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
    }

    private func setupLayout() {
        // Back button is on the main view
//        view.addSubview(backButton)
//        NSLayoutConstraint.activate([
//            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
//            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            backButton.widthAnchor.constraint(equalToConstant: 40),
//            backButton.heightAnchor.constraint(equalToConstant: 40)
//        ])

        // Rest of the content
        [logoImageView, titleLabel, subtitleLabel, emailField, errorLabel, continueButton]
            .forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            // Move the whole block up nicely
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 80),
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.heightAnchor.constraint(equalToConstant: 110),

            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 18),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 35),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -35),

            emailField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            emailField.leadingAnchor.constraint(equalTo: subtitleLabel.leadingAnchor),
            emailField.trailingAnchor.constraint(equalTo: subtitleLabel.trailingAnchor),

            errorLabel.topAnchor.constraint(equalTo: emailField.bottomAnchor, constant: 6),
            errorLabel.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            errorLabel.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),

            continueButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 20),
            continueButton.leadingAnchor.constraint(equalTo: emailField.leadingAnchor),
            continueButton.trailingAnchor.constraint(equalTo: emailField.trailingAnchor),
            continueButton.heightAnchor.constraint(equalToConstant: 54),

            continueButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -80)
        ])
    }

    private func setupActions() {
//        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(handleReset), for: .touchUpInside)
    }

    // MARK: - Actions

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleReset() {
        let email = emailField.textField.text ?? ""

        guard !email.isEmpty else {
            return showError("Email is required")
        }
        guard email.isValidEmail else {
            return showError("Enter a valid email")
        }

        // Hide error on success
        UIView.animate(withDuration: 0.2) { self.errorLabel.alpha = 0 }

        // TODO: trigger actual reset flow
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        UIView.animate(withDuration: 0.25) { self.errorLabel.alpha = 1 }
    }
}
