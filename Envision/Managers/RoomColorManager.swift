import UIKit
import RealityKit

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

    // Key suffix for texture names
    static let floorTextureKey = "floor_texture"
    static let wallTextureKey  = "wall_texture"
    static let doorTextureKey = "door_texture"
    static let windowTextureKey = "window_texture"
    static let tableTextureKey = "table_texture"
    static let chairTextureKey = "chair_texture"
    static let storageTextureKey = "storage_texture"
    static let hiddenPrefixesKey = "hidden_entity_prefixes"
    static let forceWhiteSurfacesKey = "force_white_surfaces"
    static let enableColorsKey = "enable_colors"

    enum TextureSurfaceKind {
        case floor
        case wall
        case door
        case window
        case table
        case chair
        case storage
    }

    struct SurfaceConfig {
        let prefix: String
        let colorKey: String
        let textureKey: String
    }

    static let surfaceConfigs: [SurfaceConfig] = [
        .init(prefix: floorKey, colorKey: floorKey, textureKey: floorTextureKey),
        .init(prefix: wallKey, colorKey: wallKey, textureKey: wallTextureKey),
        .init(prefix: doorKey, colorKey: doorKey, textureKey: doorTextureKey),
        .init(prefix: windowKey, colorKey: windowKey, textureKey: windowTextureKey),
        .init(prefix: tableKey, colorKey: tableKey, textureKey: tableTextureKey),
        .init(prefix: chairKey, colorKey: chairKey, textureKey: chairTextureKey),
        .init(prefix: storageKey, colorKey: storageKey, textureKey: storageTextureKey)
    ]

    struct TextureLibraryItem {
        let name: String
        let displayName: String
        let surface: TextureSurfaceKind?
    }

    private struct BundledTextureSeed {
        let name: String
        let displayName: String
        let surface: TextureSurfaceKind
    }

    private let bundledTextureSeeds: [BundledTextureSeed] = [
        BundledTextureSeed(name: "texture-wooden-board", displayName: "Wood Floor", surface: .floor),
        BundledTextureSeed(name: "wall-wallpaper", displayName: "Wallpaper", surface: .wall),
    ]

    private var didSeedBundledTextures = false
    private var textureCache: [String: TextureResource] = [:]
    
    // MARK: - Public API

    /// Normalizes persisted texture names so sentinels like "None"/"" become nil.
    func normalizedTextureName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if lower == "none" || lower == "nil" || lower == "null" {
            return nil
        }
        return trimmed
    }
    
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
    
    /// Save a texture name for a specific element type (e.g. "floor_texture" -> "texture-wooden-board")
    func saveTextureName(_ name: String?, for key: String, roomURL: URL) {
        let roomKey = roomURL.path
        if colorStorage[roomKey] == nil {
            colorStorage[roomKey] = [:]
        }

        if let normalized = normalizedTextureName(name) {
            colorStorage[roomKey]?[key] = normalized
        } else {
            colorStorage[roomKey]?.removeValue(forKey: key)
        }
        persistColors(for: roomURL)
    }

    func clearTexture(for key: String, roomURL: URL) {
        saveTextureName(nil, for: key, roomURL: roomURL)
    }

    /// Get saved texture name for an element type, or nil if not set
    func getTextureName(for key: String, roomURL: URL) -> String? {
        let roomKey = roomURL.path
        if let name = normalizedTextureName(colorStorage[roomKey]?[key]) {
            return name
        }
        loadColors(for: roomURL)
        return normalizedTextureName(colorStorage[roomKey]?[key])
    }

    /// Persist hidden semantic entity prefixes (e.g. wall, chair).
    func saveHiddenEntityPrefixes(_ prefixes: Set<String>, roomURL: URL) {
        let roomKey = roomURL.path
        if colorStorage[roomKey] == nil {
            colorStorage[roomKey] = [:]
        }

        if prefixes.isEmpty {
            colorStorage[roomKey]?.removeValue(forKey: Self.hiddenPrefixesKey)
        } else {
            let encoded = prefixes.sorted().joined(separator: ",")
            colorStorage[roomKey]?[Self.hiddenPrefixesKey] = encoded
        }
        persistColors(for: roomURL)
    }

    /// Load hidden semantic entity prefixes for a room.
    func getHiddenEntityPrefixes(for roomURL: URL) -> Set<String> {
        let roomKey = roomURL.path
        if colorStorage[roomKey] == nil {
            loadColors(for: roomURL)
        }
        guard let encoded = colorStorage[roomKey]?[Self.hiddenPrefixesKey], !encoded.isEmpty else {
            return []
        }
        return Set(
            encoded
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    /// Persist set of semantic prefixes that should be rendered as default white.
    func saveForceWhiteSurfacePrefixes(_ prefixes: Set<String>, roomURL: URL) {
        let roomKey = roomURL.path
        if colorStorage[roomKey] == nil {
            colorStorage[roomKey] = [:]
        }
        if prefixes.isEmpty {
            colorStorage[roomKey]?.removeValue(forKey: Self.forceWhiteSurfacesKey)
        } else {
            colorStorage[roomKey]?[Self.forceWhiteSurfacesKey] = prefixes.sorted().joined(separator: ",")
        }
        persistColors(for: roomURL)
    }

    func getForceWhiteSurfacePrefixes(for roomURL: URL) -> Set<String> {
        let roomKey = roomURL.path
        if colorStorage[roomKey] == nil {
            loadColors(for: roomURL)
        }
        guard let encoded = colorStorage[roomKey]?[Self.forceWhiteSurfacesKey], !encoded.isEmpty else {
            return []
        }
        return Set(
            encoded
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    /// Persist whether "Enable Colors" is ON for a room.
    func saveEnableColorsEnabled(_ enabled: Bool, roomURL: URL) {
        let roomKey = roomURL.path
        if colorStorage[roomKey] == nil {
            colorStorage[roomKey] = [:]
        }

        if enabled {
            colorStorage[roomKey]?[Self.enableColorsKey] = "1"
        } else {
            colorStorage[roomKey]?.removeValue(forKey: Self.enableColorsKey)
        }
        persistColors(for: roomURL)
    }

    /// Load whether "Enable Colors" is ON for a room. Defaults to false.
    func isEnableColorsEnabled(for roomURL: URL) -> Bool {
        let roomKey = roomURL.path
        if colorStorage[roomKey] == nil {
            loadColors(for: roomURL)
        }

        guard let raw = colorStorage[roomKey]?[Self.enableColorsKey] else {
            return false
        }
        return raw == "1" || raw.lowercased() == "true"
    }

    // MARK: - Texture Library

    /// Ensures bundled texture assets are exported to Documents/textures.
    func ensureBundledTexturesAvailable() {
        guard !didSeedBundledTextures else { return }

        let fm = FileManager.default
        let folderURL = texturesFolderURL()
        do {
            try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create textures directory: \(error.localizedDescription)")
            return
        }

        for seed in bundledTextureSeeds {
            if textureFileURL(named: seed.name) != nil {
                continue
            }

            guard let image = UIImage(named: seed.name) else {
                print("⚠️ Bundled texture asset not found: \(seed.name)")
                continue
            }

            let hasAlpha = imageHasAlpha(image)
            let ext = hasAlpha ? "png" : "jpg"
            let outputURL = folderURL.appendingPathComponent(seed.name).appendingPathExtension(ext)
            let data = hasAlpha ? image.pngData() : image.jpegData(compressionQuality: 0.95)

            do {
                try data?.write(to: outputURL, options: .atomic)
            } catch {
                print("❌ Failed to export bundled texture \(seed.name): \(error.localizedDescription)")
            }
        }

        didSeedBundledTextures = true
    }

    /// Returns all texture entries found in Documents/textures.
    func availableTextureItems() -> [TextureLibraryItem] {
        ensureBundledTexturesAvailable()

        let fm = FileManager.default
        let folderURL = texturesFolderURL()
        guard let urls = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let supportedExts = Set(["png", "jpg", "jpeg"])
        let names = Set(
            urls
                .filter { supportedExts.contains($0.pathExtension.lowercased()) }
                .map { $0.deletingPathExtension().lastPathComponent }
        )

        let bundledByName = Dictionary(uniqueKeysWithValues: bundledTextureSeeds.map { ($0.name, $0) })
        let items = names.map { name -> TextureLibraryItem in
            if let seeded = bundledByName[name] {
                return TextureLibraryItem(name: name, displayName: seeded.displayName, surface: seeded.surface)
            }

            let lower = name.lowercased()
            let inferredSurface: TextureSurfaceKind?
            if lower.contains("wall") {
                inferredSurface = .wall
            } else if lower.contains("floor") {
                inferredSurface = .floor
            } else if lower.contains("door") {
                inferredSurface = .door
            } else if lower.contains("window") {
                inferredSurface = .window
            } else if lower.contains("table") {
                inferredSurface = .table
            } else if lower.contains("chair") {
                inferredSurface = .chair
            } else if lower.contains("storage") {
                inferredSurface = .storage
            } else {
                inferredSurface = nil
            }
            return TextureLibraryItem(name: name, displayName: humanizeTextureName(name), surface: inferredSurface)
        }

        return items.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    /// Returns texture options for a specific surface. Items without a known surface appear in both lists.
    func availableTextureItems(for surface: TextureSurfaceKind) -> [TextureLibraryItem] {
        availableTextureItems().filter { item in
            guard let itemSurface = item.surface else { return true }
            return itemSurface == surface
        }
    }

    /// Loads a texture resource by name from Documents/textures with fallback to bundled lookup.
    func textureResource(named name: String) -> TextureResource? {
        ensureBundledTexturesAvailable()

        if let cached = textureCache[name] {
            return cached
        }

        if let fileURL = textureFileURL(named: name),
           let resource = try? TextureResource.load(contentsOf: fileURL) {
            textureCache[name] = resource
            return resource
        }

        if let bundled = try? TextureResource.load(named: name) {
            textureCache[name] = bundled
            return bundled
        }

        return nil
    }

    /// Returns a preview image for the texture name, preferring Documents/textures.
    func texturePreviewImage(named name: String) -> UIImage? {
        ensureBundledTexturesAvailable()

        if let fileURL = textureFileURL(named: name) {
            return UIImage(contentsOfFile: fileURL.path)
        }
        return UIImage(named: name)
    }

    /// Returns the full textures folder URL in Documents.
    func texturesFolderURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("textures", isDirectory: true)
    }

    /// Saves a user-picked image to Documents/textures and returns the texture name.
    /// The surface is encoded in the filename so `availableTextureItems(for:)` picks it up automatically.
    @discardableResult
    func saveCustomTexture(_ image: UIImage, for surface: TextureSurfaceKind) -> String {
        ensureBundledTexturesAvailable()

        let surfaceTag: String
        switch surface {
        case .floor:   surfaceTag = "floor"
        case .wall:    surfaceTag = "wall"
        case .door:    surfaceTag = "door"
        case .window:  surfaceTag = "window"
        case .table:   surfaceTag = "table"
        case .chair:   surfaceTag = "chair"
        case .storage: surfaceTag = "storage"
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let name = "custom-\(surfaceTag)-\(timestamp)"
        let folderURL = texturesFolderURL()
        let outputURL = folderURL.appendingPathComponent(name).appendingPathExtension("jpg")

        if let data = image.jpegData(compressionQuality: 0.92) {
            try? data.write(to: outputURL, options: .atomic)
        }

        return name
    }

    /// Migrate all persisted data (color JSON, thumbnail, memory cache) from the old room URL to the new one.
    /// Call this immediately after the USDZ file is renamed on disk.
    func renameRoom(from oldURL: URL, to newURL: URL) {
        let fm = FileManager.default

        // Move color JSON
        let oldColorFile = colorFileURL(for: oldURL)
        let newColorFile = colorFileURL(for: newURL)
        if fm.fileExists(atPath: oldColorFile.path) {
            try? fm.moveItem(at: oldColorFile, to: newColorFile)
        }

        // Move thumbnail
        let oldThumb = RoomColorManager.thumbnailURL(for: oldURL)
        let newThumb = RoomColorManager.thumbnailURL(for: newURL)
        if fm.fileExists(atPath: oldThumb.path) {
            try? fm.moveItem(at: oldThumb, to: newThumb)
        }

        // Migrate in-memory color cache from old key to new key
        let oldKey = oldURL.path
        let newKey = newURL.path
        if let cached = colorStorage[oldKey] {
            colorStorage[newKey] = cached
            colorStorage.removeValue(forKey: oldKey)
        }
    }

    /// Clear all saved colors for a room
    func clearColors(for roomURL: URL) {
        let roomKey = roomURL.path
        if colorStorage[roomKey] == nil {
            loadColors(for: roomURL)
        }

        let colorKeys = [
            Self.wallKey,
            Self.floorKey,
            Self.doorKey,
            Self.windowKey,
            Self.tableKey,
            Self.chairKey,
            Self.storageKey
        ]

        for key in colorKeys {
            colorStorage[roomKey]?.removeValue(forKey: key)
        }

        if colorStorage[roomKey]?.isEmpty == true {
            colorStorage[roomKey] = nil
            let fileURL = colorFileURL(for: roomURL)
            try? FileManager.default.removeItem(at: fileURL)
        } else {
            persistColors(for: roomURL)
        }
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

    private func textureFileURL(named name: String) -> URL? {
        let folderURL = texturesFolderURL()
        let fm = FileManager.default
        for ext in ["png", "jpg", "jpeg"] {
            let url = folderURL.appendingPathComponent(name).appendingPathExtension(ext)
            if fm.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    private func humanizeTextureName(_ name: String) -> String {
        let replaced = name
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return replaced.split(separator: " ").map { $0.capitalized }.joined(separator: " ")
    }

    private func imageHasAlpha(_ image: UIImage) -> Bool {
        guard let alpha = image.cgImage?.alphaInfo else { return false }
        switch alpha {
        case .premultipliedLast, .premultipliedFirst, .last, .first:
            return true
        default:
            return false
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
    
    /// Save a thumbnail image for a room.
    /// The pixel size is chosen based on the main screen scale so the image is
    /// never upscaled when displayed in collection view cells (avoids soft/blurry thumbnails).
    static func saveThumbnail(_ image: UIImage, for roomURL: URL) {
        let thumbnailURL = thumbnailURL(for: roomURL)

        // Scale-aware target: 400pt × screenScale, capped at 800px to stay reasonable.
        let screenScale = UITraitCollection.current.displayScale
        let basePts: CGFloat = 400
        let pixelSize = min(basePts * screenScale, 800)
        let targetSize = CGSize(width: pixelSize, height: pixelSize)

        // Use a 1× renderer — we're already working in pixels, not points.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        let resizedImage = renderer.image { context in
            UIColor.systemGray6.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))

            let imageSize = image.size
            let ratio = min(targetSize.width / imageSize.width,
                            targetSize.height / imageSize.height)
            let drawWidth  = imageSize.width  * ratio
            let drawHeight = imageSize.height * ratio
            let drawRect = CGRect(
                x: (targetSize.width  - drawWidth)  / 2,
                y: (targetSize.height - drawHeight) / 2,
                width: drawWidth,
                height: drawHeight
            )
            image.draw(in: drawRect)
        }

        // Slightly higher quality on 3× screens to preserve sharpness.
        let quality: CGFloat = screenScale >= 3 ? 0.90 : 0.85

        if let data = resizedImage.jpegData(compressionQuality: quality) {
            do {
                try data.write(to: thumbnailURL)
            } catch {
                print("❌ Failed to save thumbnail: \(error.localizedDescription)")
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
