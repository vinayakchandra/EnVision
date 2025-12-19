//
//  ScanRoomTip.swift
//  Envision
//
//  TipKit tip for the room scanning feature.
//  This tip helps users discover how to scan rooms using LiDAR.
//
//  NOTE: TipKit is only used for lightweight UI discovery (buttons, filters).
//  It is NOT used in AR views, RoomPlan scanning, or Object Capture cameras
//  because those screens have their own dedicated instruction overlays.
//

import Foundation

#if canImport(TipKit)
import TipKit

/// Tip shown on the My Rooms tab to encourage users to scan their first room.
@available(iOS 17.0, *)
struct ScanRoomTip: Tip {
    
    // MARK: - Tip Content
    
    var title: Text {
        Text("Scan Your Room")
    }
    
    var message: Text? {
        Text("Scan your room using your phone's LiDAR sensor.")
    }
    
    var image: Image? {
        Image(systemName: "camera.viewfinder")
    }
    
    // MARK: - Tip Options
    
    /// Show this tip only once per user (default TipKit behavior persists this)
    var options: [TipOption] {
        // Tip appears immediately, no special rules needed
        []
    }
}
#endif
