//
//  FurnitureCategory.swift
//  Envision
//

import UIKit

enum FurnitureCategory: String, Codable, CaseIterable {
    case seating = "Chairs"
    case tables = "Tables"
    case storage = "Storage"
    case beds = "Beds"
    case lighting = "Lighting"
    case decor = "Decor"
    case kitchen = "Kitchen"
    case outdoor = "Outdoor"
    case office = "Office"
    case electronics = "Electronics"
    case other = "Other"

    var sfSymbol: String {
        switch self {
        case .seating: return "chair.fill"
        case .tables: return "table.furniture.fill"
        case .storage: return "cabinet.fill"
        case .beds: return "bed.double.fill"
        case .lighting: return "lamp.floor.fill"
        case .decor: return "photo.artframe"
        case .kitchen: return "refrigerator.fill"
        case .outdoor: return "tree.fill"
        case .office: return "desktopcomputer"
        case .electronics: return "tv.fill"
        case .other: return "shippingbox.fill"
        }
    }

    var icon: String { sfSymbol }

    var color: UIColor {
        switch self {
        case .seating: return .systemBlue
        case .tables: return .systemOrange
        case .storage: return .systemPurple
        case .beds: return .systemIndigo
        case .lighting: return .systemYellow
        case .decor: return .systemPink
        case .kitchen: return .systemTeal
        case .outdoor: return .systemGreen
        case .office: return .systemBrown
        case .electronics: return .systemCyan
        case .other: return .systemGray
        }
    }

    var displayName: String { rawValue }
}

enum FurnitureType: String, Codable, CaseIterable {
    case scanned = "Scanned"
    case imported = "Imported"

    var sfSymbol: String {
        switch self {
        case .scanned: return "camera.viewfinder"
        case .imported: return "square.and.arrow.down.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .scanned: return .systemGreen
        case .imported: return .systemBlue
        }
    }

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .scanned: return "Object Capture"
        case .imported: return "From Files"
        }
    }
}

struct FurnitureMetadata: Codable {
    var category: FurnitureCategory?
    var furnitureType: FurnitureType?
    var createdAt: Date
    var tags: [String]
    var notes: String?
}
