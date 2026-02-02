import UIKit

/// Manages saved colors for room elements, persisted per room URL
final class RoomColorManager {
    
    static let shared = RoomColorManager()
    private init() {}
    
    // MARK: - Storage
    /// Dictionary: roomURL.path -> [elementPrefix: colorHex]
    private var colorStorage: [String: [String: String]] = [:]
    
    // MARK: - Keys for element types
    static let wallKey = "wall"
    static let floorKey = "floor"
    static let doorKey = "door"
    static let windowKey = "window"
    static let tableKey = "table"
    static let chairKey = "chair"
    static let storageKey = "storage"
    
    // MARK: - Public API
    
    /// Save a color for a specific element type in a room
    func saveColor(_ color: UIColor, for elementType: String, roomURL: URL) {
        let roomKey = roomURL.path
        let hexColor = color.toHex()
        
        if colorStorage[roomKey] == nil {
            colorStorage[roomKey] = [:]
        }
        colorStorage[roomKey]?[elementType] = hexColor
        
        // Persist to disk
        persistColors(for: roomURL)
    }
    
    /// Get saved color for an element type, or nil if not set
    func getColor(for elementType: String, roomURL: URL) -> UIColor? {
        let roomKey = roomURL.path
        
        // Try memory cache first
        if let hexColor = colorStorage[roomKey]?[elementType] {
            return UIColor(hex: hexColor)
        }
        
        // Try loading from disk
        loadColors(for: roomURL)
        
        if let hexColor = colorStorage[roomKey]?[elementType] {
            return UIColor(hex: hexColor)
        }
        
        return nil
    }
    
    /// Get all saved colors for a room
    func getAllColors(for roomURL: URL) -> [String: UIColor] {
        let roomKey = roomURL.path
        
        // Ensure colors are loaded
        if colorStorage[roomKey] == nil {
            loadColors(for: roomURL)
        }
        
        var result: [String: UIColor] = [:]
        colorStorage[roomKey]?.forEach { key, hexValue in
            result[key] = UIColor(hex: hexValue)
        }
        return result
    }
    
    /// Clear all saved colors for a room
    func clearColors(for roomURL: URL) {
        let roomKey = roomURL.path
        colorStorage[roomKey] = nil
        
        // Remove from disk
        let colorFileURL = colorFileURL(for: roomURL)
        try? FileManager.default.removeItem(at: colorFileURL)
    }
    
    // MARK: - Persistence
    
    private func colorFileURL(for roomURL: URL) -> URL {
        let roomName = roomURL.deletingPathExtension().lastPathComponent
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("RoomColors/\(roomName)_colors.json")
    }
    
    private func persistColors(for roomURL: URL) {
        let roomKey = roomURL.path
        guard let colors = colorStorage[roomKey] else { return }
        
        let fileURL = colorFileURL(for: roomURL)
        
        // Create directory if needed
        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Save as JSON
        if let data = try? JSONEncoder().encode(colors) {
            try? data.write(to: fileURL)
        }
    }
    
    private func loadColors(for roomURL: URL) {
        let roomKey = roomURL.path
        let fileURL = colorFileURL(for: roomURL)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        if let data = try? Data(contentsOf: fileURL),
           let colors = try? JSONDecoder().decode([String: String].self, from: data) {
            colorStorage[roomKey] = colors
        }
    }
    
    // MARK: - Thumbnail Management
    
    /// Get the thumbnail URL for a room
    static func thumbnailURL(for roomURL: URL) -> URL {
        let roomName = roomURL.deletingPathExtension().lastPathComponent
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documentsURL.appendingPathComponent("RoomThumbnails")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        return directory.appendingPathComponent("\(roomName)_thumb.jpg")
    }
    
    /// Save a thumbnail image for a room
    static func saveThumbnail(_ image: UIImage, for roomURL: URL) {
        let thumbnailURL = thumbnailURL(for: roomURL)
        
        // Resize to reasonable thumbnail size
        let targetSize = CGSize(width: 400, height: 400)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { context in
            // Fill with background color first (in case image doesn't fill)
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))
            
            // Calculate aspect-fit rect
            let imageSize = image.size
            let widthRatio = targetSize.width / imageSize.width
            let heightRatio = targetSize.height / imageSize.height
            let scale = min(widthRatio, heightRatio)
            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale
            let x = (targetSize.width - scaledWidth) / 2
            let y = (targetSize.height - scaledHeight) / 2
            
            image.draw(in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
        }
        
        // Save as JPEG
        if let data = resizedImage.jpegData(compressionQuality: 0.85) {
            do {
                try data.write(to: thumbnailURL)
                print("✅ Saved colored room thumbnail to: \(thumbnailURL.lastPathComponent)")
            } catch {
                print("❌ Failed to save thumbnail: \(error)")
            }
        }
    }
    
    /// Check if a custom thumbnail exists
    static func hasCustomThumbnail(for roomURL: URL) -> Bool {
        return FileManager.default.fileExists(atPath: thumbnailURL(for: roomURL).path)
    }
    
    /// Delete custom thumbnail
    static func deleteThumbnail(for roomURL: URL) {
        try? FileManager.default.removeItem(at: thumbnailURL(for: roomURL))
    }
}

// MARK: - UIColor Extension for Hex Output
extension UIColor {
    func toHex() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format: "#%06x", rgb)
    }
}
