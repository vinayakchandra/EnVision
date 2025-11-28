//
//  RoomCategory.swift
//  Envision
//
//  Room category for filtering and organization
//

import UIKit

enum RoomCategory: String, Codable, CaseIterable {
    case livingRoom = "Living Room"
    case bedroom = "Bedroom"
    case studyRoom = "Study Room"
    case office = "Office"
    
    var sfSymbol: String {
        switch self {
        case .livingRoom:
            return "sofa.fill"
        case .bedroom:
            return "bed.double.fill"
        case .studyRoom:
            return "books.vertical.fill"
        case .office:
            return "briefcase.fill"
        }
    }
    
    var color: UIColor {
        switch self {
        case .livingRoom:
            return .systemOrange
        case .bedroom:
            return .systemPurple
        case .studyRoom:
            return .systemBlue
        case .office:
            return .systemGreen
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}
