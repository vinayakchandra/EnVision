//
//  BackgroundModelProcessor.swift
//  Envision
//
//  Background processing manager for 3D model generation
//  Allows photogrammetry to continue even when user leaves the screen
//

import Foundation
import RealityKit
import UIKit
import UserNotifications

// MARK: - Processing Job Model
struct ProcessingJob: Codable, Identifiable {
    let id: UUID
    let imagesFolder: String
    let outputFileName: String
    let createdAt: Date
    var status: ProcessingStatus
    var progress: Float
    var errorMessage: String?
    
    enum ProcessingStatus: String, Codable {
        case queued
        case processing
        case completed
        case failed
        case cancelled
    }
}

// MARK: - Processing Delegate
protocol BackgroundModelProcessorDelegate: AnyObject {
    func processingDidUpdateProgress(_ progress: Float, status: String)
    func processingDidComplete(savedURL: URL)
    func processingDidFail(error: String)
}

// MARK: - Background Model Processor
final class BackgroundModelProcessor: @unchecked Sendable {
    
    static let shared = BackgroundModelProcessor()
    
    // MARK: - Properties
    weak var delegate: BackgroundModelProcessorDelegate?
    
    private var currentJob: ProcessingJob?
    private var currentSession: PhotogrammetrySession?
    private var preparedInputFolderURL: URL?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    // Processing state (thread-safe access)
    private let lock = NSLock()
    private var _isProcessing = false
    private var _isSavingGeneratedModel = false
    private var _didFinishCurrentRun = false
    private var _currentProgress: Float = 0
    private var _currentStatus: String = ""
    
    var isProcessing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isProcessing
    }
    
    var currentProgress: Float {
        lock.lock()
        defer { lock.unlock() }
        return _currentProgress
    }
    
    var currentStatus: String {
        lock.lock()
        defer { lock.unlock() }
        return _currentStatus
    }
    
    // Observers for UI updates when user returns
    var onProgressUpdate: ((Float, String) -> Void)?
    var onCompletion: ((URL) -> Void)?
    var onError: ((String) -> Void)?
    
    private init() {
        requestNotificationPermission()
    }
    
    // MARK: - Notification Permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print(" Notification permission: \(granted ? "granted" : "denied")")
        }
    }
    
    // MARK: - Start Processing
    func startProcessing(
        imagesFolder: URL,
        detailLevel: PhotogrammetrySession.Request.Detail = .reduced,
        completion: @escaping @Sendable (Result<URL, Error>) -> Void
    ) {
        guard PhotogrammetrySession.isSupported else {
            completion(.failure(ProcessingError.processingFailed("Object Capture is not supported on this device.")))
            return
        }

        lock.lock()
        guard !_isProcessing else {
            lock.unlock()
            completion(.failure(ProcessingError.alreadyProcessing))
            return
        }
        _isProcessing = true
        _isSavingGeneratedModel = false
        _didFinishCurrentRun = false
        _currentProgress = 0
        _currentStatus = "Preparing..."
        lock.unlock()
        
        // Generate output filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let outputFileName = "Furniture_\(timestamp).usdz"
        
        // Create job
        currentJob = ProcessingJob(
            id: UUID(),
            imagesFolder: imagesFolder.path,
            outputFileName: outputFileName,
            createdAt: Date(),
            status: .processing,
            progress: 0,
            errorMessage: nil
        )
        
        // Start background task for extended processing
        beginBackgroundTask()
        
        // Start processing on background thread
        processPhotogrammetry(
            imagesFolder: imagesFolder,
            outputFileName: outputFileName,
            detailLevel: detailLevel,
            completion: completion
        )
    }
    
    // MARK: - Background Task Management
    private func beginBackgroundTask() {
        DispatchQueue.main.async { [weak self] in
            self?.backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "PhotogrammetryProcessing") { [weak self] in
                self?.handleBackgroundTimeExpiring()
            }
            print(" Background task started")
        }
    }
    
    private func endBackgroundTask() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.backgroundTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(self.backgroundTaskID)
                self.backgroundTaskID = .invalid
                print(" Background task ended")
            }
        }
    }
    
    private func handleBackgroundTimeExpiring() {
        print(" Background time expiring...")
        endBackgroundTask()
    }
    
    // MARK: - Core Processing
    private func processPhotogrammetry(
        imagesFolder: URL,
        outputFileName: String,
        detailLevel: PhotogrammetrySession.Request.Detail,
        completion: @escaping @Sendable (Result<URL, Error>) -> Void
    ) {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(outputFileName)
        
        // Optimized configuration for speed
        var config = PhotogrammetrySession.Configuration()
        config.sampleOrdering = .sequential
        config.featureSensitivity = .normal
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let startTime = Date()
            print(" Starting photogrammetry processing...")
            print(" Input: \(imagesFolder.path)")
            print(" Output: \(outputURL.path)")
            print(" Detail level: \(detailLevel)")
            
            let preparedInputURL: URL
            let validImageCount: Int
            do {
                let prepared = try self.preparePhotogrammetryInput(from: imagesFolder)
                preparedInputURL = prepared.url
                validImageCount = prepared.validCount
                self.preparedInputFolderURL = preparedInputURL
                print(" Prepared \(prepared.validCount) valid images (skipped \(prepared.skippedCount))")
            } catch {
                self.handleFailure(error: error.localizedDescription, completion: completion)
                return
            }

            print(" Processing \(validImageCount) images")
            
            guard let session = try? PhotogrammetrySession(
                input: preparedInputURL,
                configuration: config
            ) else {
                self.handleFailure(error: "Failed to create photogrammetry session", completion: completion)
                return
            }
            
            self.currentSession = session
            
            // Create the request with specified detail level
            let request = PhotogrammetrySession.Request.modelFile(
                url: outputURL,
                detail: detailLevel
            )
            
            // Process outputs asynchronously
            Task {
                do {
                    for try await output in session.outputs {
                        switch output {
                            
                        case .processingComplete:
                            print(" Processing complete!")
                            
                        case .inputComplete:
                            print(" Input complete")
                            await MainActor.run {
                                self.updateProgress(0.1, status: "Analyzing images...")
                            }
                            
                        case .requestProgress(_, let fraction):
                            let mappedProgress = 0.1 + (Float(fraction) * 0.85)

                            let statusText: String
                            if fraction < 0.3 {
                                statusText = " Analyzing images..."
                            } else if fraction < 0.6 {
                                statusText = " Building 3D mesh..."
                            } else if fraction < 0.9 {
                                statusText = " Applying textures..."
                            } else {
                                statusText = " Finalizing model..."
                            }
                            
                            await MainActor.run {
                                self.updateProgress(mappedProgress, status: statusText)
                            }
                            
                        case .requestComplete(_, _):
                            let elapsed = Date().timeIntervalSince(startTime)
                            print(" Model generated in \(String(format: "%.1f", elapsed))s")
                            
                            await MainActor.run {
                                self.updateProgress(0.95, status: " Saving model...")
                                self.saveGeneratedModel(outputURL, completion: completion)
                            }
                            
                        case .requestError(_, let error):
                            print(" Request error: \(error)")
                            await MainActor.run {
                                self.handleFailure(error: error.localizedDescription, completion: completion)
                            }
                            
                        case .processingCancelled:
                            print(" Processing cancelled")
                            await MainActor.run {
                                self.handleFailure(error: "Processing was cancelled", completion: completion)
                            }
                            
                        case .invalidSample(let id, let reason):
                            print(" Invalid sample \(id): \(reason)")
                            
                        case .skippedSample(let id):
                            print(" Skipped sample: \(id)")
                            
                        case .automaticDownsampling:
                            print(" Automatic downsampling applied")
                            
                        default:
                            break
                        }
                    }
                } catch {
                    print(" Task error: \(error)")
                    await MainActor.run {
                        self.handleFailure(error: error.localizedDescription, completion: completion)
                    }
                }
            }
            
            // Start processing
            do {
                try session.process(requests: [request])
            } catch {
                print(" Process start error: \(error)")
                self.handleFailure(error: error.localizedDescription, completion: completion)
            }
        }
    }
    
    // MARK: - Progress Updates
    private func updateProgress(_ progress: Float, status: String) {
        lock.lock()
        _currentProgress = progress
        _currentStatus = status
        currentJob?.progress = progress
        lock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.processingDidUpdateProgress(progress, status: status)
            self.onProgressUpdate?(progress, status)
            print(" Progress: \(Int(progress * 100))% - \(status)")
        }
    }
    
    // MARK: - Save Model
    private func saveGeneratedModel(_ url: URL, completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        lock.lock()
        if _isSavingGeneratedModel || _didFinishCurrentRun {
            lock.unlock()
            return
        }
        _isSavingGeneratedModel = true
        lock.unlock()

        SaveManager.shared.saveModel(from: url, type: .furniture, customName: nil) { [weak self] result in
            guard let self = self else { return }
            
            self.endBackgroundTask()
            
            self.lock.lock()
            self._isProcessing = false
            self.lock.unlock()
            
            self.currentSession = nil
            self.cleanupPreparedInputFolder()
            
            switch result {
            case .success(let savedURL):
                guard self.markRunFinishedIfNeeded() else { return }
                self.currentJob?.status = .completed
                self.updateProgress(1.0, status: " Complete!")
                
                DispatchQueue.main.async {
                    self.delegate?.processingDidComplete(savedURL: savedURL)
                    self.onCompletion?(savedURL)
                }
                
                self.sendCompletionNotification(success: true)
                completion(.success(savedURL))
                
            case .failure(let error):
                self.lock.lock()
                self._isSavingGeneratedModel = false
                self.lock.unlock()
                self.handleFailure(error: error.localizedDescription, completion: completion)
            }
        }
    }
    
    // MARK: - Error Handling
    private func handleFailure(error: String, completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        guard markRunFinishedIfNeeded() else { return }

        endBackgroundTask()
        
        lock.lock()
        _isProcessing = false
        _isSavingGeneratedModel = false
        lock.unlock()
        
        currentSession = nil
        cleanupPreparedInputFolder()
        currentJob?.status = .failed
        currentJob?.errorMessage = error
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.processingDidFail(error: error)
            self?.onError?(error)
        }
        
        sendCompletionNotification(success: false, errorMessage: error)
        completion(.failure(ProcessingError.processingFailed(error)))
    }
    
    // MARK: - Local Notifications
    func postModelGenerationNotification(success: Bool, errorMessage: String? = nil) {
        sendCompletionNotification(success: success, errorMessage: errorMessage)
    }

    private func sendCompletionNotification(success: Bool, errorMessage: String? = nil) {
        DispatchQueue.main.async {
            let notificationsEnabled = UserManager.shared.currentUser?.preferences.notificationsEnabled ?? true
            guard notificationsEnabled else { return }
            guard UIApplication.shared.applicationState != .active else { return }

            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let isAuthorized = settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                    || settings.authorizationStatus == .ephemeral
                guard isAuthorized else { return }

                let content = UNMutableNotificationContent()

                if success {
                    content.title = "3D Model Ready!"
                    content.body = "Your furniture model has been generated and saved."
                    content.sound = .default
                } else {
                    content.title = "Model Generation Failed"
                    content.body = errorMessage ?? "An error occurred during processing."
                    content.sound = .default
                }

                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )

                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print(" Notification error: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Cancel Processing
    func cancelProcessing() {
        currentSession?.cancel()
        currentSession = nil
        cleanupPreparedInputFolder()
        
        lock.lock()
        _isProcessing = false
        lock.unlock()
        
        currentJob?.status = .cancelled
        endBackgroundTask()
        
        print(" Processing cancelled by user")
    }
    
    // MARK: - Get Current State
    func getCurrentState() -> (isProcessing: Bool, progress: Float, status: String) {
        lock.lock()
        defer { lock.unlock() }
        return (_isProcessing, _currentProgress, _currentStatus)
    }

    private func markRunFinishedIfNeeded() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if _didFinishCurrentRun { return false }
        _didFinishCurrentRun = true
        return true
    }

    // MARK: - Input Preparation
    private func preparePhotogrammetryInput(from sourceFolder: URL) throws -> (url: URL, validCount: Int, skippedCount: Int) {
        let fm = FileManager.default
        let allFiles = try fm.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: nil)
            .filter { ["jpg", "jpeg", "heic", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let tempFolder = fm.temporaryDirectory.appendingPathComponent("photogrammetry_input_\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempFolder, withIntermediateDirectories: true)

        var validCount = 0
        var skippedCount = 0

        for fileURL in allFiles {
            autoreleasepool {
                guard let image = UIImage(contentsOfFile: fileURL.path) else {
                    skippedCount += 1
                    return
                }

                let destinationURL = tempFolder.appendingPathComponent(String(format: "frame_%04d.jpg", validCount + 1))
                let normalized = image.downscaledIfNeeded(maxDimension: 2048)
                guard let jpegData = normalized.jpegData(compressionQuality: 0.95) else {
                    skippedCount += 1
                    return
                }
                do {
                    try jpegData.write(to: destinationURL, options: .atomic)
                    validCount += 1
                } catch {
                    skippedCount += 1
                }
            }
        }

        guard validCount >= 10 else {
            try? fm.removeItem(at: tempFolder)
            throw ProcessingError.processingFailed("Not enough valid photos for model generation. Try capturing at least 20 clear photos.")
        }

        return (tempFolder, validCount, skippedCount)
    }

    private func cleanupPreparedInputFolder() {
        guard let folder = preparedInputFolderURL else { return }
        try? FileManager.default.removeItem(at: folder)
        preparedInputFolderURL = nil
    }
}

private extension UIImage {
    func downscaledIfNeeded(maxDimension: CGFloat) -> UIImage {
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, longestSide > 0 else { return self }

        let scaleFactor = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

// MARK: - Errors
enum ProcessingError: LocalizedError {
    case alreadyProcessing
    case processingFailed(String)
    case sessionCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "A model is already being processed. Please wait."
        case .processingFailed(let message):
            return message
        case .sessionCreationFailed:
            return "Failed to create photogrammetry session."
        }
    }
}
