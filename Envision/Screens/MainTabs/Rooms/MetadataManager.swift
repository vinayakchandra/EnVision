//
//  MetadataManager.swift
//  Envision
//

import Foundation

class MetadataManager {
    static let shared = MetadataManager()

    private let metadataFileName = "rooms_metadata.json"
    private var cache: RoomsMetadata?
    private init() {
        // Don't load on init - let it load lazily when needed
    }

    private func metadataFileURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("roomPlan", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(metadataFileName)
    }

    // MARK: - Public Methods

    func loadMetadata() -> RoomsMetadata {
        // Return cached version if available
        if let cached = cache {
            return cached
        }

        let url = metadataFileURL()

        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("📝 No metadata file found, creating new one")
            let empty = RoomsMetadata(version: "1.0", rooms: [:])
            cache = empty
            return empty
        }

        // Try to load existing file
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadata = try decoder.decode(RoomsMetadata.self, from: data)

            print(" Loaded metadata with \(metadata.rooms.count) rooms")
            cache = metadata
            return metadata
        } catch {
            print(" Error loading metadata: \(error)")
            // If file is corrupted, create backup and start fresh
            let backupURL = url.deletingPathExtension().appendingPathExtension("backup.json")
            try? FileManager.default.copyItem(at: url, to: backupURL)
            print(" Created backup at: \(backupURL.lastPathComponent)")

            let empty = RoomsMetadata(version: "1.0", rooms: [:])
            cache = empty
            return empty
        }
    }

    func saveMetadata(_ metadata: RoomsMetadata) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(metadata)
            try data.write(to: self.metadataFileURL(), options: .atomic)

            print(" Saved metadata with \(metadata.rooms.count) rooms")
            self.cache = metadata
        } catch {
            print(" Error saving metadata: \(error)")
        }
    }

    func getMetadata(for filename: String) -> RoomMetadata? {
        return loadMetadata().rooms[filename]
    }

    func updateMetadata(for filename: String, metadata: RoomMetadata) {
        var allMetadata = loadMetadata()
        allMetadata.rooms[filename] = metadata
        saveMetadata(allMetadata)

        print(" Updated metadata for: \(filename)")
    }

    func deleteMetadata(for filename: String) {
        var allMetadata = loadMetadata()
        allMetadata.rooms.removeValue(forKey: filename)
        saveMetadata(allMetadata)

        print(" Deleted metadata for: \(filename)")
    }

    func renameMetadata(from oldFilename: String, to newFilename: String) {
        var allMetadata = loadMetadata()

        if let metadata = allMetadata.rooms[oldFilename] {
            allMetadata.rooms.removeValue(forKey: oldFilename)
            allMetadata.rooms[newFilename] = metadata
            saveMetadata(allMetadata)

            print(" Renamed metadata: \(oldFilename) → \(newFilename)")
        }
    }

    func cleanupOrphanedMetadata() {
        let folder = metadataFileURL().deletingLastPathComponent()
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return
        }

        let usdzFiles = Set(files.filter { $0.pathExtension == "usdz" }.map { $0.lastPathComponent })
        var metadata = loadMetadata()

        let beforeCount = metadata.rooms.count
        metadata.rooms = metadata.rooms.filter { usdzFiles.contains($0.key) }
        let afterCount = metadata.rooms.count

        if beforeCount != afterCount {
            saveMetadata(metadata)
            print(" Cleaned up \(beforeCount - afterCount) orphaned metadata entries")
        }
    }

    func getAllMetadata() -> [String: RoomMetadata] {
        return loadMetadata().rooms
    }

    // Debug method to print all metadata
    func printAllMetadata() {
        let metadata = loadMetadata()
        print(" Metadata Summary:")
        print("   Total rooms: \(metadata.rooms.count)")
        print("   File location: \(metadataFileURL().path)")

        for (filename, meta) in metadata.rooms {
            print("   - \(filename): \(meta.category.displayName) (\(meta.roomType.displayName))")
        }
    }
}

// MARK: - Models
struct RoomsMetadata: Codable {
    let version: String
    var rooms: [String: RoomMetadata]
}

struct RoomMetadata: Codable {
    var category: RoomCategory
    var roomType: RoomType
    let createdAt: Date
    var dimensions: RoomDimensions?
    var tags: [String]
    var notes: String?

    struct RoomDimensions: Codable {
        let width: Double
        let height: Double
        let length: Double
    }

    init(category: RoomCategory, roomType: RoomType, createdAt: Date = Date(), dimensions: RoomDimensions? = nil, tags: [String] = [], notes: String? = nil) {
        self.category = category
        self.roomType = roomType
        self.createdAt = createdAt
        self.dimensions = dimensions
        self.tags = tags
        self.notes = notes
    }
}
