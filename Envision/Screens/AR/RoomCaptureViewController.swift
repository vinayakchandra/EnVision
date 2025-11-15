import UIKit
import ARKit
import RoomPlan
import RealityKit

class RoomCaptureViewController: UIViewController, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {

    private var roomCaptureView: RoomCaptureView!
    private var roomCaptureSession: RoomCaptureSession?
    private var isScanning = false
    private var finalResults: CapturedRoom?

    private var exportButton: UIButton!
    private var doneButton: UIBarButtonItem!
    private var cancelButton: UIBarButtonItem!
    private var activityIndicator: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Scan Your Room"
        view.backgroundColor = .white

        setupUI()
        setupRoomCaptureView()
    }

    // MARK: - Setup UI
    private func setupUI() {
        exportButton = UIButton(type: .system)
        exportButton.setTitle("Export", for: .normal)
        exportButton.addTarget(self, action: #selector(exportResults), for: .touchUpInside)
        exportButton.frame = CGRect(x: 20, y: 40, width: 100, height: 40)
        exportButton.isEnabled = false  // Fixed: Initially disabled until scan completes
        view.addSubview(exportButton)

        doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneScanning))
        cancelButton = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelScanning))
        navigationItem.rightBarButtonItem = doneButton
        navigationItem.leftBarButtonItem = cancelButton

        activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.center = view.center
        view.addSubview(activityIndicator)
    }

    // MARK: - RoomCaptureView Setup
    private func setupRoomCaptureView() {
        roomCaptureView = RoomCaptureView(frame: view.bounds)
        roomCaptureView.delegate = self

        // Initialize RoomCaptureSession
        roomCaptureSession = RoomCaptureSession()
        roomCaptureSession?.delegate = self

        view.insertSubview(roomCaptureView, at: 0)
    }

    // MARK: - Session Management
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func startSession() {
        isScanning = true
        roomCaptureSession?.run(configuration: RoomCaptureSession.Configuration())
        activityIndicator.startAnimating()
    }

    private func stopSession() {
        isScanning = false
        roomCaptureSession?.stop()
        activityIndicator.stopAnimating()
    }

    // MARK: - RoomCaptureViewDelegate
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
        return true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
        finalResults = processedResult
        exportButton.isEnabled = true
        activityIndicator.stopAnimating()
    }

    // MARK: - RoomCaptureSessionDelegate (Fixed: Added required methods)
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
        // Update UI with room data if needed
    }
    
    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
        if let error = error {
            print("Capture session ended with error: \(error)")
            showAlert(message: "Scan ended with error: \(error.localizedDescription)")
            return
        }
        activityIndicator.startAnimating()
    }
    
    func captureSession(_ session: RoomCaptureSession, didAdd room: CapturedRoom) {
        finalResults = room
    }
    
    func captureSession(_ session: RoomCaptureSession, didChange room: CapturedRoom) {
        // Handle room changes during scanning
    }
    
    func captureSession(_ session: RoomCaptureSession, didRemove room: CapturedRoom) {
        // Handle room removal
    }

    @objc private func doneScanning() {
        if isScanning {
            stopSession()
        }
        activityIndicator.startAnimating()
    }

    @objc private func cancelScanning() {
        navigationController?.dismiss(animated: true)
    }

    // MARK: - Export Results
    @objc private func exportResults() {
        guard let room = finalResults else {
            showAlert(message: "No room data available to export")
            return
        }
        
        let destinationFolderURL = FileManager.default.temporaryDirectory.appendingPathComponent("Export")
        let destinationURL = destinationFolderURL.appendingPathComponent("Room.usdz")

        do {
            try FileManager.default.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true)
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(room)
            let capturedRoomURL = destinationFolderURL.appendingPathComponent("Room.json")
            try jsonData.write(to: capturedRoomURL)

            // Export the model to USDZ format
            try room.export(to: destinationURL, exportOptions: .mesh)

            let activityVC = UIActivityViewController(activityItems: [destinationFolderURL], applicationActivities: nil)
            present(activityVC, animated: true, completion: nil)

        } catch {
            showAlert(message: "Error during export: \(error.localizedDescription)")
        }
    }

    // MARK: - Texture Application
    private func applyTexturesToModel(_ entity: ModelEntity, with image: UIImage) {
        // Fixed: Removed access to non-existent room.image property
        // Now requires image to be passed as parameter
        guard let imageURL = saveCapturedImageToDocuments(image) else {
            print("Failed to save image for texture")
            return
        }
        
        // Fixed: Proper optional handling instead of force unwrapping
        guard let texture = try? TextureResource.load(contentsOf: imageURL) else {
            print("Failed to load texture from image")
            return
        }

        // Create PhysicallyBasedMaterial with texture
        var material = PhysicallyBasedMaterial()
//        material.baseColor = MaterialColorParameter.texture(texture)
//        material.roughness = MaterialScalarParameter.float(0.8)
        material.baseColor = PhysicallyBasedMaterial.BaseColor(
            texture: MaterialParameters.Texture(texture)
        )
        material.roughness = .init(floatLiteral: 0.8)

        entity.model?.materials = [material]
    }

    // MARK: - Helper Methods
    // Fixed: Returns optional URL instead of empty URL on failure
    private func saveCapturedImageToDocuments(_ image: UIImage) -> URL? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imageURL = documentDirectory.appendingPathComponent("roomScan_\(UUID().uuidString).jpg")

        do {
            try imageData.write(to: imageURL)
            return imageURL
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    // MARK: - Display in AR
    private func displayModelInAR(_ entity: ModelEntity) {
        let arView = ARView(frame: view.bounds)
        view.subviews.forEach { $0.removeFromSuperview() }
        view.addSubview(arView)

        // Fixed: Use proper SIMD3<Float> instead of .zero
        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -1))
        anchor.addChild(entity)
        arView.scene.addAnchor(anchor)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Notice", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
