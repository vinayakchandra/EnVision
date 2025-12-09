//
//  RoomCategory.swift
//  Envision
//

import UIKit

enum RoomCategory: String, Codable, CaseIterable {
    case livingRoom = "Living Room"
    case bedroom = "Bedroom"
    case studyRoom = "Study Room"
    case office = "Office"
    case other = "Other"

    var sfSymbol: String {
        switch self {
        case .livingRoom: "sofa.fill"
        case .bedroom: "bed.double.fill"
        case .studyRoom: "books.vertical.fill"
        case .office: "briefcase.fill"
        case .other: "questionmark.folder.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .livingRoom: .systemOrange
        case .bedroom: .systemPurple
        case .studyRoom: .systemBlue
        case .office: .systemGreen
        case .other: .systemGray
        }
    }

    var displayName: String { rawValue }
}

enum RoomType: String, Codable, CaseIterable {
    case parametric = "Parametric"
    case textured = "Textured"

    var sfSymbol: String {
        switch self {
        case .parametric: "cube.transparent"
        case .textured: "photo.fill.on.rectangle.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .parametric: .systemTeal
        case .textured: .systemPink
        }
    }

    var displayName: String { rawValue }

    var description: String {
        switch self {
        case .parametric: "RoomPlan API"
        case .textured: "Object Capture"
        }
    }
}