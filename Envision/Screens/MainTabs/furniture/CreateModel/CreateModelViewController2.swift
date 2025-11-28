import UIKit
import RealityKit

class CreateModelViewController2: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkPhotogrammetrySupport()
    }

    func setupUI() {
        title = "Create Model"
        view.backgroundColor = .systemBackground
    }

    func checkPhotogrammetrySupport() {
        guard PhotogrammetrySession.isSupported else {
            showNotSupportedAlert()
            return
        }
        print("Photogrammetry is supported on this device.")
    }

    func showNotSupportedAlert() {
        let alert = UIAlertController(
            title: "Not Supported",
            message: "This device does not support Photogrammetry Object Capture.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // ------------------------------------------------------------
    // MARK: - Create Object Capture Session
    // ------------------------------------------------------------
    func createObjectCaptureSession(with imagesFolderURL: URL) {
        do {
            print("Starting Object Capture session...")
            print("Input folder: \(imagesFolderURL.path)")

            // 1. Create session
            let session = try PhotogrammetrySession(input: imagesFolderURL)

            // 2. Output model location
            let outputURL = imagesFolderURL.appendingPathComponent("model.usdz")
            print("Output model will be saved to: \(outputURL.path)")

            // 3. Request high-quality model generation
            let request = PhotogrammetrySession.Request.modelFile(
                url: outputURL,
                detail: .reduced
            )

            // 4. Process session outputs asynchronously
            Task {
                do {
                    for try await output in session.outputs {
                        switch output {
                        case .processingComplete:
                            print("✔ Processing Completed")

                        case .requestError(let id, let error):
                            print("❌ Error in request \(id): \(error.localizedDescription)")

                        case .requestProgress(let id, let progress):
                            let percent = Int(progress * 100)
                            print("⏳ Progress (\(id)): \(percent)%")

                        case .requestComplete(let id, let result):
                            print("🎉 Request \(id) completed: \(result)")

                        default:
                            break
                        }
                    }
                } catch {
                    print("❌ Session failed: \(error)")
                }
            }

            // 5. Start processing
            try session.process(requests: [request])

        } catch {
            print("❌ Couldn't create PhotogrammetrySession: \(error)")
        }
    }

    // ------------------------------------------------------------
    // MARK: - Example Trigger
    // ------------------------------------------------------------
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Example: look in Documents/ObjectCaptureImages
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ObjectCaptureImages")

        // You must place images in this folder beforehand
        createObjectCaptureSession(with: folder)
    }
}
