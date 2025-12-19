//
//  ScanFurnitureTip.swift
//  Envision
//
//  TipKit tip for the furniture scanning feature.
//  This tip helps users discover how to capture furniture using Object Capture.
//
//  NOTE: TipKit is only used for lightweight UI discovery (buttons, filters).
//  It is NOT used in AR views, RoomPlan scanning, or Object Capture cameras
//  because those screens have their own dedicated instruction overlays.
//

import Foundation

#if canImport(TipKit)
import TipKit

/// Tip shown on the My Furniture tab to encourage users to scan furniture.
@available(iOS 17.0, *)
struct ScanFurnitureTip: Tip {
    
    // MARK: - Tip Content
    
    var title: Text {
        Text("Capture Furniture")
    }
    
    var message: Text? {
        Text("Capture furniture using Object Capture to create a 3D model.")
    }
    
    var image: Image? {
        Image(systemName: "cube.transparent")
    }
    
    // MARK: - Tip Options
    
    var options: [TipOption] {
        []
    }
}
#endif
