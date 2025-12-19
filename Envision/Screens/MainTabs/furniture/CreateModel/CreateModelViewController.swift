import UIKit
import RealityKit
import UniformTypeIdentifiers
import PhotosUI

class CreateModelViewController: UIViewController {

    private var importedFolderURL: URL?

    // MARK: - Progress UI
    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .default)
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.progress = 0
        pv.isHidden = true
        return pv
    }()

    private let progressLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text = ""
        lbl.textAlignment = .center
        lbl.font = UIFont.systemFont(ofSize: 14)
        lbl.isHidden = true
        return lbl
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkPhotogrammetrySupport()
    }


    // MARK: - UI Setup
    func setupUI() {
        title = "Create Model"

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Import Folder",
            style: .plain,
            target: self,
            action: #selector(importFolder)
        )

        // Add progress UI
        view.addSubview(progressView)
        view.addSubview(progressLabel)

        NSLayoutConstraint.activate([
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),

            progressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressLabel.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -12)
        ])
    }

    func showProgressUI() {
        progressView.progress = 0
        progressLabel.text = "Starting…"
        progressView.isHidden = false
        progressLabel.isHidden = false
    }

    func hideProgressUI() {
        progressView.isHidden = true
        progressLabel.isHidden = true
    }


    // MARK: - Support Check
    func checkPhotogrammetrySupport() {
        guard PhotogrammetrySession.isSupported else {
            let alert = UIAlertController(
                title: "Not Supported",
                message: "This device does not support Photogrammetry.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        print("Photogrammetry is supported.")
    }
}


// MARK: - Folder Import
extension CreateModelViewController: UIDocumentPickerDelegate {

    @objc func importFolder() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let folderURL = urls.first else { return }

        guard folderURL.startAccessingSecurityScopedResource() else {
            showAlert(title: "Access Denied", message: "Could not access the selected folder.")
            return
        }
        defer { folderURL.stopAccessingSecurityScopedResource() }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey, .contentTypeKey],
                options: [.skipsHiddenFiles]
            )

            let imageURLs = fileURLs.filter { url in
                if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
                    return type.conforms(to: .image)
                }
                let ext = url.pathExtension.lowercased()
                return ["jpg","jpeg","png","heic","heif","tif","tiff"].contains(ext)
            }

            guard !imageURLs.isEmpty else {
                showAlert(title: "No Images", message: "Folder contains no images.")
                return
            }

            // Create temp input folder
            let tempFolder = FileManager.default.temporaryDirectory
                .appendingPathComponent("photogrammetry-input-\(UUID().uuidString)")

            try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true)

            // Copy images
            for src in imageURLs {
                let dst = tempFolder.appendingPathComponent(src.lastPathComponent)
                try? FileManager.default.removeItem(at: dst)
                try FileManager.default.copyItem(at: src, to: dst)
            }

            startPhotogrammetryUsingFolder(tempFolder)

        } catch {
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
}


// MARK: - Photogrammetry
extension CreateModelViewController {

    func startPhotogrammetryUsingFolder(_ inputFolderUrl: URL) {

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Model_\(UUID().uuidString).usdz")

        print("Output will be:", outputURL.path)

        var config = PhotogrammetrySession.Configuration()
        config.featureSensitivity = .high
        config.sampleOrdering = .sequential
        config.isObjectMaskingEnabled = true

        let session: PhotogrammetrySession
        do {
            session = try PhotogrammetrySession(input: inputFolderUrl, configuration: config)
        } catch {
            showAlert(title: "Session Error", message: error.localizedDescription)
            return
        }

        let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: .reduced)

        DispatchQueue.main.async { self.showProgressUI() }

        Task {
            do {
                for try await output in session.outputs {
                    switch output {
                    case .inputComplete:
                        print("Input ingestion complete.")

                    case .processingComplete:
                        print("Processing complete.")
                        DispatchQueue.main.async {
                            self.progressLabel.text = "Finalizing…"
                        }

                    case .requestProgress(_, let fraction):
                        DispatchQueue.main.async {
                            self.progressView.progress = Float(fraction)
                            self.progressLabel.text = "Processing: \(Int(fraction * 100))%"
                        }

                    case .requestComplete(_, _):
                        DispatchQueue.main.async {
                            self.hideProgressUI()
                            self.askUserForFilename(finalURL: outputURL)
                        }

                    case .requestError(_, let error):
                        DispatchQueue.main.async {
                            self.hideProgressUI()
                            self.showAlert(title: "Processing Error", message: error.localizedDescription)
                        }

                    case .invalidSample(let id, let reason):
                        print("Invalid sample:", id, reason)

                    case .skippedSample(let id):
                        print("Skipped sample:", id)

                    case .automaticDownsampling:
                        print("Downsampling applied.")

                    case .processingCancelled:
                        print("Processing cancelled.")

                    @unknown default:
                        print("Unknown output.")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.hideProgressUI()
                    self.showAlert(title: "Session Output Error", message: error.localizedDescription)
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try session.process(requests: [request])
            } catch {
                DispatchQueue.main.async {
                    self.hideProgressUI()
                    self.showAlert(title: "Process Error", message: error.localizedDescription)
                }
            }
        }
    }
}


// MARK: - Rename Before Saving
extension CreateModelViewController {

    func askUserForFilename(finalURL: URL) {
        let alert = UIAlertController(
            title: "Save Model",
            message: "Enter a filename:",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "MyModel"
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.presentShareSheet(url: finalURL)
        }))

        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { _ in
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)

            guard let name = name, !name.isEmpty else {
                self.presentShareSheet(url: finalURL)
                return
            }

            let renamedURL = finalURL.deletingLastPathComponent()
                .appendingPathComponent("\(name).usdz")

            do {
                if FileManager.default.fileExists(atPath: renamedURL.path) {
                    try FileManager.default.removeItem(at: renamedURL)
                }
                try FileManager.default.moveItem(at: finalURL, to: renamedURL)
                self.presentShareSheet(url: renamedURL)

            } catch {
                self.showAlert(title: "Rename Failed", message: error.localizedDescription)
                self.presentShareSheet(url: finalURL)
            }
        }))

        present(alert, animated: true)
    }
}


// MARK: - Helpers
extension CreateModelViewController {

    func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(a, animated: true)
        }
    }

    func presentShareSheet(url: URL) {
        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(sheet, animated: true)
    }
}
