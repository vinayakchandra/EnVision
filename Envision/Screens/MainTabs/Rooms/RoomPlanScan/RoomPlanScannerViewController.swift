//
//  RoomPlanScannerViewController.swift
//  Envisionf2
//

import UIKit
import RoomPlan

final class RoomPlanScannerViewController: UIViewController, RoomCaptureSessionDelegate {

    // MARK: - RoomPlan

    private let captureSession = RoomCaptureSession()

    // IMPORTANT: RoomCaptureView has no `.session` setter.
    // We must embed ARSession automatically by using simple init.
    private lazy var captureView: RoomCaptureView = {
        let v = RoomCaptureView(frame: .zero)
        return v
    }()

    private var capturedRoom: CapturedRoom?
    private var previewThumbnail: UIImage?

    // MARK: - UI

    private let miniPreview: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 14
        iv.alpha = 1
        return iv
    }()

    private let saveButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Save", for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = UIColor(red: 173/255, green: 106/255, blue: 64/255, alpha: 1)
        btn.tintColor = .white
        btn.layer.cornerRadius = 18
        btn.alpha = 1
        btn.widthAnchor.constraint(equalToConstant: 100).isActive = true
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "Scan Your Room"

        setupCaptureView()
//        setupMiniPreview()
        setupSaveButton()
        startRoomCapture()
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

//    private func setupMiniPreview() {
//        miniPreview.translatesAutoresizingMaskIntoConstraints = false
//        view.addSubview(miniPreview)
//
//        NSLayoutConstraint.activate([
//            miniPreview.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
//            miniPreview.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
//            miniPreview.widthAnchor.constraint(equalToConstant: 110),
//            miniPreview.heightAnchor.constraint(equalToConstant: 110)
//        ])
//    }

    private func setupSaveButton() {
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)

        NSLayoutConstraint.activate([
            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    private func startRoomCapture() {
        captureView.captureSession.delegate = self
        
        let config = RoomCaptureSession.Configuration()
        captureView.captureSession.run(configuration: config)
    }

    // MARK: - RoomCaptureSessionDelegate

    func captureSession(_ session: RoomCaptureSession,
                        didUpdate room: CapturedRoom) {

        capturedRoom = room

        if previewThumbnail == nil {
            previewThumbnail = UIImage(named: "room_placeholder") ??
                               UIImage(systemName: "house.fill")
            miniPreview.image = previewThumbnail

            UIView.animate(withDuration: 0.25) {
                self.miniPreview.alpha = 1
                self.saveButton.alpha = 1
            }
        }
    }

    func captureSession(_ session: RoomCaptureSession,
                        didEndWith room: CapturedRoom, error: Error?) {
        capturedRoom = room
    }

    // MARK: - Actions

    @objc private func saveTapped() {
        guard let room = capturedRoom else { return }

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
