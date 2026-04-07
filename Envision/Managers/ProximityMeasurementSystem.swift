//
//  ProximityMeasurementSystem.swift
//  Envision
//
//  Automatic proximity measurement system that detects and displays
//  distances from furniture to surrounding objects (walls, floor, other furniture)
//

import RealityKit
import UIKit
import simd

// MARK: - Proximity Direction

/// Directions for proximity measurements
enum ProximityDirection: String, CaseIterable {
    case left = "←"
    case right = "→"
    case front = "↑"
    case back = "↓"
    case top = "↑↑"
    case bottom = "↓↓"
    
    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .front: return "Front"
        case .back: return "Back"
        case .top: return "Ceiling"
        case .bottom: return "Floor"
        }
    }
    
    var color: UIColor {
        switch self {
        case .left, .right: return .systemBlue
        case .front, .back: return .systemGreen
        case .top, .bottom: return .systemOrange
        }
    }
    
    /// Unit direction vector
    var vector: SIMD3<Float> {
        switch self {
        case .left: return SIMD3(-1, 0, 0)
        case .right: return SIMD3(1, 0, 0)
        case .front: return SIMD3(0, 0, -1)
        case .back: return SIMD3(0, 0, 1)
        case .top: return SIMD3(0, 1, 0)
        case .bottom: return SIMD3(0, -1, 0)
        }
    }
}

// MARK: - Proximity Measurement Result

/// Result of a proximity measurement
struct ProximityMeasurement {
    let direction: ProximityDirection
    let distance: Float  // In scene/display units
    let startPoint: SIMD3<Float>
    let endPoint: SIMD3<Float>
    let targetType: TargetType
    
    enum TargetType {
        case wall
        case floor
        case ceiling
        case furniture(name: String)
        case unknown
    }
    
    /// Get the real-world distance in meters
    var realWorldDistance: Float {
        return RealWorldScaleManager.shared.toRealWorldMeters(distance)
    }
    
    /// Formatted distance in real-world units
    var formattedDistance: String {
        return RealWorldScaleManager.shared.formatDisplayedAsRealWorld(distance)
    }
}

// MARK: - Proximity Measurement System

/// System for automatically measuring distances from furniture to surrounding objects
final class ProximityMeasurementSystem {
    
    // MARK: - Singleton
    static let shared = ProximityMeasurementSystem()
    private init() {}
    
    // MARK: - Configuration
    struct Config {
        static let maxRaycastDistance: Float = 10.0  // Max distance to check
        static let lineRadius: Float = 0.001         // Thickness of distance lines (1mm)
        static let markerRadius: Float = 0.003       // Size of endpoint markers (3mm)
        static let labelOffset: Float = 0.03         // Label offset from line
        static let minDisplayDistance: Float = 0.005 // Minimum distance to display (5mm)
    }
    
    // MARK: - Active Visualizations
    private var activeIndicators: [Entity] = []
    private var activeLabels: [UIView] = []

    private var measurementTextColor: UIColor {
        UITraitCollection.current.userInterfaceStyle == .dark ? .white : .black
    }
    
    // MARK: - Calculate Proximity Measurements
    
    /// Calculate all proximity measurements for a furniture entity within a room
    /// - Parameters:
    ///   - furniture: The furniture entity to measure from
    ///   - roomModel: The room model entity containing walls, floor, etc.
    ///   - otherFurniture: Other furniture items in the scene
    /// - Returns: Array of proximity measurements
    func calculateProximityMeasurements(
        for furniture: Entity,
        in roomModel: Entity?,
        otherFurniture: [Entity]
    ) -> [ProximityMeasurement] {
        
        var measurements: [ProximityMeasurement] = []
        
        // Get furniture world-space bounding box
        // visualBounds(relativeTo: nil) returns bounds in world space already
        let furnitureBounds = furniture.visualBounds(relativeTo: nil)
        let furnitureMin = furnitureBounds.min
        let furnitureMax = furnitureBounds.max
        let furnitureCenter = furnitureBounds.center
        
        // Get room bounds if available (also in world space)
        var roomBounds: (min: SIMD3<Float>, max: SIMD3<Float>)?
        if let room = roomModel {
            let bounds = room.visualBounds(relativeTo: nil)
            roomBounds = (bounds.min, bounds.max)
        }
        
        // Measure in each direction
        for direction in ProximityDirection.allCases {
            if let measurement = measureInDirection(
                direction,
                furnitureCenter: furnitureCenter,
                furnitureBounds: (furnitureMin, furnitureMax),
                roomBounds: roomBounds,
                otherFurniture: otherFurniture,
                sourceFurniture: furniture
            ) {
                measurements.append(measurement)
            }
        }
        
        return measurements
    }
    
    /// Measure distance in a specific direction
    private func measureInDirection(
        _ direction: ProximityDirection,
        furnitureCenter: SIMD3<Float>,
        furnitureBounds: (min: SIMD3<Float>, max: SIMD3<Float>),
        roomBounds: (min: SIMD3<Float>, max: SIMD3<Float>)?,
        otherFurniture: [Entity],
        sourceFurniture: Entity
    ) -> ProximityMeasurement? {
        
        // Calculate ray start point (edge of furniture in that direction)
        let rayStart: SIMD3<Float>
        switch direction {
        case .left:
            rayStart = SIMD3(furnitureBounds.min.x, furnitureCenter.y, furnitureCenter.z)
        case .right:
            rayStart = SIMD3(furnitureBounds.max.x, furnitureCenter.y, furnitureCenter.z)
        case .front:
            rayStart = SIMD3(furnitureCenter.x, furnitureCenter.y, furnitureBounds.min.z)
        case .back:
            rayStart = SIMD3(furnitureCenter.x, furnitureCenter.y, furnitureBounds.max.z)
        case .top:
            rayStart = SIMD3(furnitureCenter.x, furnitureBounds.max.y, furnitureCenter.z)
        case .bottom:
            rayStart = SIMD3(furnitureCenter.x, furnitureBounds.min.y, furnitureCenter.z)
        }
        
        // Find closest hit
        var closestDistance: Float = Config.maxRaycastDistance
        var targetType: ProximityMeasurement.TargetType = .unknown
        var hitPoint: SIMD3<Float>?
        
        // Check against room bounds first
        if let room = roomBounds {
            let roomHit = raycastToRoomBounds(
                from: rayStart,
                direction: direction.vector,
                roomBounds: room
            )
            if let hit = roomHit, hit.distance < closestDistance {
                closestDistance = hit.distance
                hitPoint = hit.point
                targetType = hit.targetType
            }
        }
        
        // Check against other furniture
        for otherFurn in otherFurniture {
            guard otherFurn !== sourceFurniture else { continue }
            
            // Get other furniture's world-space bounds
            let otherBounds = otherFurn.visualBounds(relativeTo: nil)
            
            if let hit = raycastToAABB(
                from: rayStart,
                direction: direction.vector,
                boxMin: otherBounds.min,
                boxMax: otherBounds.max
            ) {
                if hit < closestDistance {
                    closestDistance = hit
                    hitPoint = rayStart + direction.vector * hit
                    targetType = .furniture(name: otherFurn.name.isEmpty ? "Furniture" : otherFurn.name)
                }
            }
        }
        
        // Create measurement if we found a hit
        guard closestDistance < Config.maxRaycastDistance,
              closestDistance > Config.minDisplayDistance,
              let endPoint = hitPoint else {
            return nil
        }
        
        return ProximityMeasurement(
            direction: direction,
            distance: closestDistance,
            startPoint: rayStart,
            endPoint: endPoint,
            targetType: targetType
        )
    }
    
    /// Raycast to room bounds (walls, floor, ceiling)
    private func raycastToRoomBounds(
        from origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        roomBounds: (min: SIMD3<Float>, max: SIMD3<Float>)
    ) -> (distance: Float, point: SIMD3<Float>, targetType: ProximityMeasurement.TargetType)? {
        
        // Check each plane of the room bounds
        var closestT: Float = Config.maxRaycastDistance
        var hitPoint: SIMD3<Float>?
        var targetType: ProximityMeasurement.TargetType = .unknown
        
        // Left wall (x = min.x)
        if direction.x < 0 {
            let t = (roomBounds.min.x - origin.x) / direction.x
            if t > 0 && t < closestT {
                closestT = t
                hitPoint = origin + direction * t
                targetType = .wall
            }
        }
        
        // Right wall (x = max.x)
        if direction.x > 0 {
            let t = (roomBounds.max.x - origin.x) / direction.x
            if t > 0 && t < closestT {
                closestT = t
                hitPoint = origin + direction * t
                targetType = .wall
            }
        }
        
        // Front wall (z = min.z)
        if direction.z < 0 {
            let t = (roomBounds.min.z - origin.z) / direction.z
            if t > 0 && t < closestT {
                closestT = t
                hitPoint = origin + direction * t
                targetType = .wall
            }
        }
        
        // Back wall (z = max.z)
        if direction.z > 0 {
            let t = (roomBounds.max.z - origin.z) / direction.z
            if t > 0 && t < closestT {
                closestT = t
                hitPoint = origin + direction * t
                targetType = .wall
            }
        }
        
        // Floor (y = min.y)
        if direction.y < 0 {
            let t = (roomBounds.min.y - origin.y) / direction.y
            if t > 0 && t < closestT {
                closestT = t
                hitPoint = origin + direction * t
                targetType = .floor
            }
        }
        
        // Ceiling (y = max.y)
        if direction.y > 0 {
            let t = (roomBounds.max.y - origin.y) / direction.y
            if t > 0 && t < closestT {
                closestT = t
                hitPoint = origin + direction * t
                targetType = .ceiling
            }
        }
        
        guard let point = hitPoint else { return nil }
        return (closestT, point, targetType)
    }
    
    /// Raycast to an axis-aligned bounding box
    private func raycastToAABB(
        from origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        boxMin: SIMD3<Float>,
        boxMax: SIMD3<Float>
    ) -> Float? {
        var tMin: Float = 0
        var tMax: Float = Config.maxRaycastDistance
        
        for i in 0..<3 {
            if abs(direction[i]) < 0.0001 {
                // Ray is parallel to this axis
                if origin[i] < boxMin[i] || origin[i] > boxMax[i] {
                    return nil
                }
            } else {
                let t1 = (boxMin[i] - origin[i]) / direction[i]
                let t2 = (boxMax[i] - origin[i]) / direction[i]
                
                let tNear = min(t1, t2)
                let tFar = max(t1, t2)
                
                tMin = max(tMin, tNear)
                tMax = min(tMax, tFar)
                
                if tMin > tMax {
                    return nil
                }
            }
        }
        
        return tMin > 0 ? tMin : nil
    }
    
    // MARK: - Visualization
    
    /// Create visual indicators for proximity measurements
    /// - Parameters:
    ///   - measurements: Array of proximity measurements
    ///   - scene: The RealityKit scene to add indicators to
    func showProximityIndicators(
        for measurements: [ProximityMeasurement],
        in scene: RealityKit.Scene
    ) {
        // Clear existing indicators
        clearIndicators()
        
        guard let anchor = scene.anchors.first else { return }
        
        for measurement in measurements {
            let indicator = createDistanceIndicator(for: measurement)
            anchor.addChild(indicator)
            activeIndicators.append(indicator)
        }
    }
    
    /// Create a distance indicator entity (line + label)
    private func createDistanceIndicator(for measurement: ProximityMeasurement) -> Entity {
        let container = Entity()
        let color = measurement.direction.color
        let material = SimpleMaterial(color: color, roughness: 0.5, isMetallic: false)
        
        let start = measurement.startPoint
        let end = measurement.endPoint
        let distance = measurement.distance
        let midpoint = (start + end) / 2
        let direction = normalize(end - start)
        
        // Create solid line (single cylinder for performance)
        let cylinderMesh = MeshResource.generateCylinder(height: distance, radius: Config.lineRadius)
        let line = ModelEntity(mesh: cylinderMesh, materials: [material])
        line.position = midpoint
        
        // Rotate to align with direction
        let up = SIMD3<Float>(0, 1, 0)
        if abs(dot(direction, up)) < 0.9999 {
            let rotation = simd_quatf(from: up, to: direction)
            line.orientation = rotation
        }
        container.addChild(line)
        
        // Create endpoint markers
        let markerMesh = MeshResource.generateSphere(radius: Config.markerRadius)
        
        let startMarker = ModelEntity(mesh: markerMesh, materials: [material])
        startMarker.position = start
        container.addChild(startMarker)
        
        let endMarker = ModelEntity(mesh: markerMesh, materials: [material])
        endMarker.position = end
        container.addChild(endMarker)
        
        // Create 3D text label
        let labelText = "\(measurement.direction.displayName): \(measurement.formattedDistance)"
        let labelMesh = MeshResource.generateText(
            labelText,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.015, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        let labelMaterial = SimpleMaterial(color: measurementTextColor, roughness: 0.3, isMetallic: false)
        let label = ModelEntity(mesh: labelMesh, materials: [labelMaterial])
        
        // Position label at midpoint, offset perpendicular to the line
        var labelPos = midpoint
        // Offset based on direction for better visibility
        switch measurement.direction {
        case .left, .right:
            labelPos.y += Config.labelOffset
        case .front, .back:
            labelPos.y += Config.labelOffset
        case .top, .bottom:
            labelPos.x += Config.labelOffset
        }
        label.position = labelPos
        container.addChild(label)
        
        return container
    }
    
    /// Clear all proximity indicators
    func clearIndicators() {
        activeIndicators.forEach { $0.removeFromParent() }
        activeIndicators.removeAll()
        
        activeLabels.forEach { $0.removeFromSuperview() }
        activeLabels.removeAll()
    }
}

// MARK: - Convenience Extension for Entity Arrays

extension ProximityMeasurementSystem {
    
    /// Show proximity measurements for a selected furniture item
    func showProximityForFurniture(
        _ furniture: Entity,
        roomModel: Entity?,
        otherFurniture: [Entity],
        in scene: RealityKit.Scene
    ) {
        let measurements = calculateProximityMeasurements(
            for: furniture,
            in: roomModel,
            otherFurniture: otherFurniture
        )
        
        showProximityIndicators(for: measurements, in: scene)
    }
    
    /// Show proximity measurements for all placed furniture
    func showProximityForAllFurniture(
        _ allFurniture: [Entity],
        roomModel: Entity?,
        in scene: RealityKit.Scene
    ) {
        clearIndicators()
        
        guard let anchor = scene.anchors.first else { return }
        
        for furniture in allFurniture {
            let otherFurniture = allFurniture.filter { $0 !== furniture }
            let measurements = calculateProximityMeasurements(
                for: furniture,
                in: roomModel,
                otherFurniture: otherFurniture
            )
            
            for measurement in measurements {
                let indicator = createDistanceIndicator(for: measurement)
                anchor.addChild(indicator)
                activeIndicators.append(indicator)
            }
        }
    }
}
