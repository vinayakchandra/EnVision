//
//  RealWorldScaleManager.swift
//  Envision
//
//  Manages real-world scale conversion for accurate measurements
//  in the room visualization mode.
//

import Foundation
import RealityKit
import simd

/// Manager for handling real-world scale conversions
/// Ensures measurements match actual physical dimensions
final class RealWorldScaleManager {
    
    // MARK: - Singleton
    static let shared = RealWorldScaleManager()
    private init() {}
    
    // MARK: - Scale Tracking
    
    /// The scale factor applied to the room model (scene units / real meters)
    /// For example, if room is 10m wide but displays as 0.5 units, scaleFactor = 0.05
    private(set) var roomScaleFactor: Float = 1.0
    
    /// Original room dimensions in meters (before scaling)
    private(set) var originalRoomDimensions: SIMD3<Float> = .zero
    
    /// Displayed room dimensions (after scaling for view)
    private(set) var displayedRoomDimensions: SIMD3<Float> = .zero
    
    // MARK: - Configuration
    
    /// Target display size for room models (in scene units)
    /// Room will be scaled so its largest dimension equals this value
    static let targetDisplaySize: Float = 0.6
    
    /// Standard furniture scale relative to room
    /// Furniture should be scaled to match the room's scale factor
    static let defaultFurnitureDisplayScale: Float = 0.1
    
    // MARK: - Room Setup
    
    /// Calculate and store the scale factor for a room model
    /// - Parameters:
    ///   - roomEntity: The original room entity (unscaled)
    ///   - targetSize: Target display size (default 0.6)
    /// - Returns: The scale factor to apply
    @discardableResult
    func setupRoomScale(for roomEntity: Entity, targetSize: Float = targetDisplaySize) -> Float {
        // Get original bounds (in meters from RoomPlan)
        let bounds = roomEntity.visualBounds(relativeTo: nil)
        originalRoomDimensions = bounds.extents
        
        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        guard maxDim > 0 else {
            roomScaleFactor = 1.0
            return 1.0
        }
        
        // Calculate scale factor
        roomScaleFactor = targetSize / maxDim
        displayedRoomDimensions = originalRoomDimensions * roomScaleFactor
        
        print("📐 Room Scale Setup:")
        print("   Original dimensions: \(formatDimensions(originalRoomDimensions))")
        print("   Scale factor: \(roomScaleFactor)")
        print("   Displayed dimensions: \(formatDimensions(displayedRoomDimensions))")
        
        return roomScaleFactor
    }
    
    // MARK: - Furniture Scaling
    
    /// Calculate the appropriate scale for furniture to match room scale
    /// - Parameters:
    ///   - furnitureEntity: The furniture entity
    ///   - realWorldSize: Optional known real-world size in meters (e.g., chair is 0.5m wide)
    /// - Returns: Scale to apply to furniture
    func calculateFurnitureScale(
        for furnitureEntity: Entity,
        realWorldSize: SIMD3<Float>? = nil
    ) -> SIMD3<Float> {
        let bounds = furnitureEntity.visualBounds(relativeTo: nil)
        let furnitureOriginalSize = bounds.extents
        
        if let knownSize = realWorldSize {
            // If we know the real size, scale to match
            // Furniture should appear at: knownSize * roomScaleFactor
            let targetDisplaySize = knownSize * roomScaleFactor
            
            // Calculate scale needed
            var scale = SIMD3<Float>(repeating: 1.0)
            if furnitureOriginalSize.x > 0 {
                scale.x = targetDisplaySize.x / furnitureOriginalSize.x
            }
            if furnitureOriginalSize.y > 0 {
                scale.y = targetDisplaySize.y / furnitureOriginalSize.y
            }
            if furnitureOriginalSize.z > 0 {
                scale.z = targetDisplaySize.z / furnitureOriginalSize.z
            }
            
            // Use uniform scale (average) to maintain proportions
            let uniformScale = (scale.x + scale.y + scale.z) / 3.0
            return SIMD3<Float>(repeating: uniformScale)
        } else {
            // Estimate: assume furniture is roughly 1 meter in largest dimension
            // This is a reasonable default for chairs, tables, etc.
            let estimatedRealSize: Float = 1.0 // meters
            let maxFurnitureDim = max(furnitureOriginalSize.x, furnitureOriginalSize.y, furnitureOriginalSize.z)
            
            guard maxFurnitureDim > 0 else {
                return SIMD3<Float>(repeating: roomScaleFactor)
            }
            
            // Scale so furniture appears as ~1 meter in the scene
            let targetDisplayDim = estimatedRealSize * roomScaleFactor
            let scale = targetDisplayDim / maxFurnitureDim
            
            return SIMD3<Float>(repeating: scale)
        }
    }
    
    /// Calculate furniture scale based on a known real-world dimension
    /// - Parameters:
    ///   - furnitureEntity: The furniture entity
    ///   - realWidthMeters: Known width in meters
    /// - Returns: Uniform scale to apply
    func calculateFurnitureScaleFromWidth(
        for furnitureEntity: Entity,
        realWidthMeters: Float
    ) -> Float {
        let bounds = furnitureEntity.visualBounds(relativeTo: nil)
        let originalWidth = bounds.extents.x
        
        guard originalWidth > 0 else { return roomScaleFactor }
        
        // Target display width = real width * room scale factor
        let targetDisplayWidth = realWidthMeters * roomScaleFactor
        return targetDisplayWidth / originalWidth
    }
    
    // MARK: - Measurement Conversion
    
    /// Convert a displayed distance to real-world meters
    /// - Parameter displayedDistance: Distance in scene units
    /// - Returns: Distance in real-world meters
    func toRealWorldMeters(_ displayedDistance: Float) -> Float {
        guard roomScaleFactor > 0 else { return displayedDistance }
        return displayedDistance / roomScaleFactor
    }
    
    /// Convert real-world meters to displayed scene units
    /// - Parameter realMeters: Distance in real-world meters
    /// - Returns: Distance in scene units
    func toDisplayUnits(_ realMeters: Float) -> Float {
        return realMeters * roomScaleFactor
    }
    
    /// Convert a displayed position to real-world coordinates
    /// - Parameter displayedPosition: Position in scene units
    /// - Returns: Position in real-world meters
    func toRealWorldPosition(_ displayedPosition: SIMD3<Float>) -> SIMD3<Float> {
        guard roomScaleFactor > 0 else { return displayedPosition }
        return displayedPosition / roomScaleFactor
    }
    
    /// Convert displayed extents to real-world dimensions
    /// - Parameter displayedExtents: Extents in scene units (width, height, depth)
    /// - Returns: Dimensions in real-world meters
    func toRealWorldDimensions(_ displayedExtents: SIMD3<Float>) -> (width: Float, height: Float, depth: Float) {
        let realWidth = toRealWorldMeters(displayedExtents.x)
        let realHeight = toRealWorldMeters(displayedExtents.y)
        let realDepth = toRealWorldMeters(displayedExtents.z)
        return (realWidth, realHeight, realDepth)
    }
    
    // MARK: - Formatting
    
    /// Format a real-world distance for display
    /// - Parameter meters: Distance in meters
    /// - Returns: Formatted string (e.g., "1.5 m" or "45 cm")
    func formatRealWorldDistance(_ meters: Float) -> String {
        if meters >= 1.0 {
            return String(format: "%.2f m", meters)
        } else {
            return String(format: "%.0f cm", meters * 100)
        }
    }
    
    /// Format displayed distance as real-world measurement
    /// - Parameter displayedDistance: Distance in scene units
    /// - Returns: Formatted real-world string
    func formatDisplayedAsRealWorld(_ displayedDistance: Float) -> String {
        let realMeters = toRealWorldMeters(displayedDistance)
        return formatRealWorldDistance(realMeters)
    }
    
    private func formatDimensions(_ dims: SIMD3<Float>) -> String {
        return String(format: "W: %.2fm, H: %.2fm, D: %.2fm", dims.x, dims.y, dims.z)
    }
    
    // MARK: - Reset
    
    func reset() {
        roomScaleFactor = 1.0
        originalRoomDimensions = .zero
        displayedRoomDimensions = .zero
    }
}

// MARK: - Entity Extension for Easy Access

extension Entity {
    /// Get the real-world dimensions of this entity
    var realWorldDimensions: SIMD3<Float> {
        let bounds = self.visualBounds(relativeTo: nil)
        let scaleManager = RealWorldScaleManager.shared
        return SIMD3<Float>(
            scaleManager.toRealWorldMeters(bounds.extents.x),
            scaleManager.toRealWorldMeters(bounds.extents.y),
            scaleManager.toRealWorldMeters(bounds.extents.z)
        )
    }
    
    /// Get the real-world position of this entity
    var realWorldPosition: SIMD3<Float> {
        let pos = self.position(relativeTo: nil)
        return RealWorldScaleManager.shared.toRealWorldPosition(pos)
    }
}
