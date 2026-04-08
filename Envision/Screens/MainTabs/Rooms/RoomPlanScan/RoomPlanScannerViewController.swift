//
//  RoomPlanScannerViewController.swift
//  Envisionf2
//

import UIKit
import RoomPlan

final class RoomPlanScannerViewController: UIViewController, RoomCaptureSessionDelegate {

    // MARK: - RoomPlan
    private let captureSession = RoomCaptureSession()

    private lazy var captureView: RoomCaptureView = {
        let v = RoomCaptureView(frame: .zero)
        return v
    }()

    private var capturedRoom: CapturedRoom?
    private var previewThumbnail: UIImage?
    private weak var onboardingView: LiDAROnboardingView?

    // MARK: - UI
    private let saveButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Save", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = AppColors.accent
        btn.tintColor = .white
        btn.layer.cornerRadius = 18
        btn.alpha = 1
        btn.widthAnchor.constraint(equalToConstant: 100).isActive = true
        return btn
    }()

    private let helpButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let helpLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 12, weight: .semibold)
        lbl.textColor = .white
        lbl.text = "Help"
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()

    // MARK: - Init
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        hidesBottomBarWhenPushed = true
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "Scan Your Room"

        setupCaptureView()
        setupSaveButton()
        setupHelpButton()
        startRoomCapture()
    }

    // MARK: - LiDAR Onboarding

    private func showLiDAROnboarding() {
        guard onboardingView == nil else { return }

        // Pause capture until the user finishes reading
        captureView.captureSession.stop(pauseARSession: true)

        let onboarding = LiDAROnboardingView()
        onboardingView = onboarding
        onboarding.onDismiss = { [weak self] in
            self?.onboardingView = nil
            self?.captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
        }
        onboarding.present(in: view)
    }

    // MARK: - Setup
    private func setupCaptureView() {
        captureView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captureView)

        NSLayoutConstraint.activate([
                                        captureView.topAnchor.constraint(equalTo: view.topAnchor),
                                        captureView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        captureView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        captureView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                                    ])
    }

    private func setupSaveButton() {
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
                                        saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                        saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
                                    ])
    }

    private func setupHelpButton() {
        let helpStack = UIStackView(arrangedSubviews: [helpButton, helpLabel])
        helpStack.axis = .vertical
        helpStack.spacing = 4
        helpStack.alignment = .center
        helpStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(helpStack)

        NSLayoutConstraint.activate([
            helpStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            helpStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            helpButton.widthAnchor.constraint(equalToConstant: 40),
            helpButton.heightAnchor.constraint(equalToConstant: 40)
        ])

        helpButton.addTarget(self, action: #selector(helpTapped), for: .touchUpInside)
    }

    private func startRoomCapture() {
        captureView.captureSession.delegate = self

        let config = RoomCaptureSession.Configuration()
        captureView.captureSession.run(configuration: config)
    }

    // MARK: - RoomCaptureSessionDelegate
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        capturedRoom = room

        if previewThumbnail == nil {
            previewThumbnail = UIImage(named: "room_placeholder") ?? UIImage(systemName: "house.fill")

            UIView.animate(withDuration: 0.25) {
                self.saveButton.alpha = 1
            }
        }
    }

    func captureSession(_ session: RoomCaptureSession, didEndWith room: CapturedRoom, error: Error?) {
        capturedRoom = room
    }

    // MARK: - Actions
    @objc private func helpTapped() {
        showLiDAROnboarding()
    }

    @objc private func saveTapped() {
        guard let room = capturedRoom else {
            return
        }

        let model = RoomModel(
            id: room.identifier,
            name: "My Room",
            createdAt: Date(),
            thumbnail: previewThumbnail,
            sizeDescription: "Size: N/A",
            capturedRoom: room
        )

        let previewVC = RoomPreviewViewController(roomModel: model)
        navigationController?.pushViewController(previewVC, animated: true)
    }
}
