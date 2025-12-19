//
//  SaveManager.swift
//  Envision
//
//  Centralized save management for furniture and room models
//

import Foundation
import UIKit
import QuickLookThumbnailing

enum ModelType {
    case furniture
    case room
    
    var folderName: String {
        switch self {
        case .furniture: return "furniture"
        case .room: return "roomPlan"
        }
    }
    
    var displayName: String {
        switch self {
        case .furniture: return "Furniture"
        case .room: return "Room"
        }
    }
}

struct ModelMetadata: Codable {
    let fileName: String
    let originalName: String?
    let createdDate: Date
    let fileSize: Int64
    let modelType: String
    let thumbnailPath: String?
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
}

final class SaveManager {
    
    static let shared = SaveManager()
    
    private init() {}
    
    // MARK: - Save Model
    
    func saveModel(
        from sourceURL: URL,
        type: ModelType,
        customName: String? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Create destination folder
                let folderURL = try self.getFolderURL(for: type)
                
                // Generate unique filename
                let fileName = self.generateFileName(
                    originalName: customName ?? sourceURL.deletingPathExtension().lastPathComponent,
                    type: type
                )
                
                let destinationURL = folderURL.appendingPathComponent(fileName)
                
                // Copy or move file
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                
                // Generate thumbnail
                self.generateAndSaveThumbnail(for: destinationURL, type: type)
                
                // Save metadata
                try self.saveMetadata(for: destinationURL, type: type, originalName: customName)
                
                DispatchQueue.main.async {
                    completion(.success(destinationURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Get Saved Models
    
    func getSavedModels(type: ModelType) -> [URL] {
        guard let folderURL = try? getFolderURL(for: type) else { return [] }
        
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        return urls.filter { $0.pathExtension.lowercased() == "usdz" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
    }
    
    // MARK: - Delete Model
    
    func deleteModel(at url: URL, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Delete thumbnail if exists
                let thumbnailURL = self.getThumbnailURL(for: url)
                if FileManager.default.fileExists(atPath: thumbnailURL.path) {
                    try? FileManager.default.removeItem(at: thumbnailURL)
                }
                
                // Delete metadata if exists
                let metadataURL = self.getMetadataURL(for: url)
                if FileManager.default.fileExists(atPath: metadataURL.path) {
                    try? FileManager.default.removeItem(at: metadataURL)
                }
                
                // Delete model file
                try FileManager.default.removeItem(at: url)
                
                DispatchQueue.main.async {
                    completion(true)
                }
            } catch {
                print("❌ Error deleting model: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }
    
    // MARK: - Metadata
    
    func getMetadata(for url: URL) -> ModelMetadata? {
        let metadataURL = getMetadataURL(for: url)
        guard let data = try? Data(contentsOf: metadataURL),
              let metadata = try? JSONDecoder().decode(ModelMetadata.self, from: data) else {
            return nil
        }
        return metadata
    }
    
    private func saveMetadata(for url: URL, type: ModelType, originalName: String?) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        
        let metadata = ModelMetadata(
            fileName: url.lastPathComponent,
            originalName: originalName,
            createdDate: Date(),
            fileSize: fileSize,
            modelType: type.displayName,
            thumbnailPath: getThumbnailURL(for: url).lastPathComponent
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        
        let metadataURL = getMetadataURL(for: url)
        try data.write(to: metadataURL)
    }
    
    // MARK: - Thumbnails
    
    func getThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
        let thumbnailURL = getThumbnailURL(for: url)
        
        // Check if cached thumbnail exists
        if let image = UIImage(contentsOfFile: thumbnailURL.path) {
            completion(image)
            return
        }
        
        // Generate new thumbnail
        let req = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 400, height: 400),
            scale: UIScreen.main.scale,
            representationTypes: .all
        )
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
            DispatchQueue.main.async {
                let image = rep?.uiImage
                // Save thumbnail to disk
                if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
                    try? data.write(to: thumbnailURL)
                }
                completion(image)
            }
        }
    }
    
    private func generateAndSaveThumbnail(for url: URL, type: ModelType) {
        let thumbnailURL = getThumbnailURL(for: url)
        
        let req = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 400, height: 400),
            scale: 2.0,
            representationTypes: .all
        )
        
        QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
            if let image = rep?.uiImage, let data = image.jpegData(compressionQuality: 0.8) {
                try? data.write(to: thumbnailURL)
            }
        }
    }
    
    // MARK: - Storage Info
    
    func getStorageInfo(type: ModelType) -> (count: Int, totalSize: Int64) {
        let models = getSavedModels(type: type)
        var totalSize: Int64 = 0
        
        for url in models {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        
        return (models.count, totalSize)
    }
    
    // MARK: - Helper Methods
    
    private func getFolderURL(for type: ModelType) throws -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folderURL = documentsURL.appendingPathComponent(type.folderName, isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
        
        return folderURL
    }
    
    private func generateFileName(originalName: String, type: ModelType) -> String {
        let timestamp = Date().timeIntervalSince1970
        let sanitized = originalName.replacingOccurrences(of: " ", with: "_")
        return "\(type.folderName)_\(sanitized)_\(Int(timestamp)).usdz"
    }
    
    private func getThumbnailURL(for modelURL: URL) -> URL {
        let thumbnailName = modelURL.deletingPathExtension().lastPathComponent + "_thumb.jpg"
        return modelURL.deletingLastPathComponent().appendingPathComponent(thumbnailName)
    }
    
    private func getMetadataURL(for modelURL: URL) -> URL {
        let metadataName = modelURL.deletingPathExtension().lastPathComponent + "_meta.json"
        return modelURL.deletingLastPathComponent().appendingPathComponent(metadataName)
    }
}
