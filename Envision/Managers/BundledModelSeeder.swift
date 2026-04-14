//
//  BundledModelSeeder.swift
//  Envision
//

import Foundation
import UIKit

final class BundledModelSeeder {
    static let shared = BundledModelSeeder()

    private let seededFlagKey = "didSeedBundledStarterModels_v1"

    private init() {}

    func seedIfNeeded() {
        if UserDefaults.standard.bool(forKey: seededFlagKey) {
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let roomSeeded = self.seedStarterRoomIfNeeded()
            let furnitureSeeded = self.seedStarterFurnitureIfNeeded()

            if roomSeeded || furnitureSeeded {
                UserDefaults.standard.set(true, forKey: self.seededFlagKey)
            }
        }
    }

    @discardableResult
    private func seedStarterRoomIfNeeded() -> Bool {
        let fileManager = FileManager.default
        let folderURL = documentsFolder(named: "roomPlan")

        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create roomPlan folder: \(error.localizedDescription)")
            return false
        }

        let existingRooms = (try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))?
            .filter { $0.pathExtension.lowercased() == "usdz" } ?? []
        if !existingRooms.isEmpty {
            return false
        }

        let destinationURL = folderURL.appendingPathComponent("room.usdz")
        let copied = copyBundledModel(named: "room", withExtension: "usdz", to: destinationURL)
        guard copied else {
            print("⚠️ Bundled starter room not found: room.usdz")
            return false
        }

        let metadata = RoomMetadata(
            category: .studyRoom,
            roomType: .parametric,
            createdAt: Date(),
            dimensions: nil,
            tags: ["starter", "bundled"],
            notes: "Seeded on first app open."
        )
        MetadataManager.shared.updateMetadata(for: destinationURL.lastPathComponent, metadata: metadata)
        return true
    }

    @discardableResult
    private func seedStarterFurnitureIfNeeded() -> Bool {
        let fileManager = FileManager.default
        let folderURL = documentsFolder(named: "furniture")

        do {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            print("❌ Failed to create furniture folder: \(error.localizedDescription)")
            return false
        }

        let existingFurniture = (try? fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]))?
            .filter { $0.pathExtension.lowercased() == "usdz" } ?? []
        if !existingFurniture.isEmpty {
            return false
        }

        let destinationURL = folderURL.appendingPathComponent("chair.usdz")
        let copied = copyBundledModel(named: "chair", withExtension: "usdz", to: destinationURL)
        guard copied else {
            print("⚠️ Bundled starter furniture not found: chair.usdz")
            return false
        }

        UserDefaults.standard.set(FurnitureCategory.seating.rawValue, forKey: "furniture_category_\(destinationURL.lastPathComponent)")
        return true
    }

    private func documentsFolder(named folderName: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(folderName, isDirectory: true)
    }

    private func bundledResourceURL(named name: String, withExtension ext: String) -> URL? {
        let targetFileName = "\(name).\(ext)".lowercased()
        guard let resourceURL = Bundle.main.resourceURL else { return nil }

        let enumerator = FileManager.default.enumerator(
            at: resourceURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.lastPathComponent.lowercased() == targetFileName {
                return fileURL
            }
        }
        return nil
    }

    @discardableResult
    private func copyBundledModel(named name: String, withExtension ext: String, to destinationURL: URL) -> Bool {
        let fileManager = FileManager.default

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
        } catch {
            print("❌ Failed removing existing file at \(destinationURL.lastPathComponent): \(error.localizedDescription)")
            return false
        }

        if let bundledURL = bundledResourceURL(named: name, withExtension: ext) {
            do {
                try fileManager.copyItem(at: bundledURL, to: destinationURL)
                return true
            } catch {
                print("❌ Failed copying bundled file \(name).\(ext): \(error.localizedDescription)")
            }
        }

        if let dataAsset = NSDataAsset(name: name) {
            do {
                try dataAsset.data.write(to: destinationURL, options: .atomic)
                return true
            } catch {
                print("❌ Failed writing data asset \(name): \(error.localizedDescription)")
            }
        }

        return false
    }
}
