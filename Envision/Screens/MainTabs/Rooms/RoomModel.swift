//
//  RoomModel.swift
//  Envisionf2
//

import UIKit
import RoomPlan

/// Lightweight model for a saved room in the "My Rooms" grid.
struct RoomModel {
    let id: UUID
    let name: String
    let createdAt: Date
    let thumbnail: UIImage?
    /// Simple size description shown in the cell meta label.
    /// e.g. "Size: 15.2 kB" or "Size: N/A"
    let sizeDescription: String
    /// CapturedRoom is kept in memory for this session only.
    /// (You can later serialize it if you want persistence.)
    let capturedRoom: CapturedRoom
}
