//
//  MeasurementManager.swift
//  Envision
//
//  Core manager for AR measurement calculations and state management
//

import Foundation
import RealityKit
import Combine
import UIKit

// MARK: - Measurement Unit

/// Unit system for measurements
enum MeasurementUnit: String, CaseIterable {
    case metric
    case imperial
    
    var lengthSuffix: String {
        switch self {
        case .metric: return "m"
        case .imperial: return "ft"
        }
    }
    
    var smallLengthSuffix: String {
        switch self {
        case .metric: return "cm"
        case .imperial: return "in"
        }
    }
    
    var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }
}

// MARK: - Bounding Box

/// Represents a 3D axis-aligned bounding box
struct BoundingBox {
    let min: SIMD3<Float>
    let max: SIMD3<Float>
    
    var width: Float { max.x - min.x }
    var height: Float { max.y - min.y }
    var depth: Float { max.z - min.z }
    var center: SIMD3<Float> { (min + max) / 2 }
    
    /// All 8 corners of the bounding box
    var corners: [SIMD3<Float>] {
        [
            SIMD3(min.x, min.y, min.z), // 0: front-bottom-left
            SIMD3(max.x, min.y, min.z), // 1: front-bottom-right
            SIMD3(max.x, min.y, max.z), // 2: back-bottom-right
            SIMD3(min.x, min.y, max.z), // 3: back-bottom-left
            SIMD3(min.x, max.y, min.z), // 4: front-top-left
            SIMD3(max.x, max.y, min.z), // 5: front-top-right
            SIMD3(max.x, max.y, max.z), // 6: back-top-right
            SIMD3(min.x, max.y, max.z)  // 7: back-top-left
        ]
    }
    
    /// All 12 edges as pairs of corner indices
    static let edgeIndices: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 0), // Bottom edges
        (4, 5), (5, 6), (6, 7), (7, 4), // Top edges
        (0, 4), (1, 5), (2, 6), (3, 7)  // Vertical edges
    ]
    
    /// Create from RealityKit bounds
    init(min: SIMD3<Float>, max: SIMD3<Float>) {
        self.min = min
        self.max = max
    }
    
    /// Create from entity's visual bounds
    init(from entity: Entity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        self.min = bounds.min
        self.max = bounds.max
    }
}

// MARK: - Measurement Manager

/// Central manager for all measurement operations in AR
final class MeasurementManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = MeasurementManager()
    
    // MARK: - Published State
    @Published var isEnabled: Bool = false
    @Published var currentUnit: MeasurementUnit = .metric
    @Published var selectedEntityID: UInt64?
    
    // MARK: - Configuration
    struct Config {
        static let boxColor: UIColor = AppColors.accent
        static let labelBackgroundColor: UIColor = AppColors.accent
        static var labelTextColor: UIColor {
            UITraitCollection.current.userInterfaceStyle == .dark ? .white : .black
        }
        static let edgeRadius: Float = 0.001      // 1mm edge thickness
        static let cornerRadius: Float = 0.002    // 2mm corner spheres
        static let labelOffset: Float = 0.05      // 5cm label offset from edge
        static let labelFontSize: CGFloat = 0.02  // Font size for 3D text
    }
    
    // MARK: - Active Visualizations
    private var boundingBoxEntities: [Entity] = []
    private var dimensionLabelEntities: [Entity] = []
    private var distanceLineEntities: [Entity] = []
    
    // MARK: - Initialization
    private init() {
        loadPreferences()
    }
    
    // MARK: - Preferences
    
    private func loadPreferences() {
        if let unitRaw = UserDefaults.standard.string(forKey: "measurementUnit"),
           let unit = MeasurementUnit(rawValue: unitRaw) {
            currentUnit = unit
        }
    }
    
    func savePreferences() {
        UserDefaults.standard.set(currentUnit.rawValue, forKey: "measurementUnit")
    }
    
    // MARK: - Bounding Box Calculations
    
    /// Get bounding box for an entity
    func getBoundingBox(for entity: Entity) -> BoundingBox {
        return BoundingBox(from: entity)
    }
    
    /// Get dimensions of an entity in current unit
    func getDimensions(for entity: Entity) -> (width: Float, height: Float, depth: Float) {
        let box = getBoundingBox(for: entity)
        return (box.width, box.height, box.depth)
    }
    
    // MARK: - Distance Calculations
    
    /// Calculate distance between two points
    func distance(from pointA: SIMD3<Float>, to pointB: SIMD3<Float>) -> Float {
        return simd_distance(pointA, pointB)
    }
    
    /// Calculate distance between two entities (center to center)
    func distance(from entityA: Entity, to entityB: Entity) -> Float {
        let posA = entityA.position(relativeTo: nil)
        let posB = entityB.position(relativeTo: nil)
        return simd_distance(posA, posB)
    }
    
    /// Calculate closest distance between two entity bounding boxes
    func closestDistance(from entityA: Entity, to entityB: Entity) -> Float {
        let boxA = getBoundingBox(for: entityA)
        let boxB = getBoundingBox(for: entityB)
        let posA = entityA.position(relativeTo: nil)
        let posB = entityB.position(relativeTo: nil)
        
        // Calculate world-space bounds
        let minA = posA + boxA.min
        let maxA = posA + boxA.max
        let minB = posB + boxB.min
        let maxB = posB + boxB.max
        
        // Calculate closest points between AABBs
        var closestA = SIMD3<Float>.zero
        var closestB = SIMD3<Float>.zero
        
        for i in 0..<3 {
            if maxA[i] < minB[i] {
                closestA[i] = maxA[i]
                closestB[i] = minB[i]
            } else if maxB[i] < minA[i] {
                closestA[i] = minA[i]
                closestB[i] = maxB[i]
            } else {
                // Overlapping on this axis
                closestA[i] = (Swift.max(minA[i], minB[i]) + Swift.min(maxA[i], maxB[i])) / 2
                closestB[i] = closestA[i]
            }
        }
        
        return simd_distance(closestA, closestB)
    }
    
    // MARK: - Unit Conversion & Formatting
    
    /// Convert meters to current unit
    func convertToCurrentUnit(_ meters: Float) -> Float {
        switch currentUnit {
        case .metric:
            return meters
        case .imperial:
            return meters * 3.28084 // meters to feet
        }
    }
    
    /// Format a displayed distance as real-world measurement
    /// Uses RealWorldScaleManager to convert from scene units to real meters
    func formatDisplayedDistance(_ displayedDistance: Float) -> String {
        let realMeters = RealWorldScaleManager.shared.toRealWorldMeters(displayedDistance)
        return formatDimension(realMeters)
    }
    
    /// Format dimension value for display (input is in real-world meters)
    func formatDimension(_ meters: Float) -> String {
        switch currentUnit {
        case .metric:
            if meters >= 1.0 {
                return String(format: "%.2f m", meters)
            } else {
                return String(format: "%.1f cm", meters * 100)
            }
        case .imperial:
            let feet = meters * 3.28084
            if feet >= 1.0 {
                return String(format: "%.2f ft", feet)
            } else {
                let inches = meters * 39.3701
                return String(format: "%.1f in", inches)
            }
        }
    }
    
    /// Format dimension with axis label
    func formatDimensionWithLabel(_ meters: Float, axis: String) -> String {
        return "\(axis): \(formatDimension(meters))"
    }
    
    // MARK: - Visualization Management
    
    /// Add bounding box visualization to an entity
    func showBoundingBox(for entity: Entity, in scene: RealityKit.Scene, color: UIColor? = nil) {
        let box = getBoundingBox(for: entity)
        let position = entity.position(relativeTo: nil)
        let boxColor = color ?? Config.boxColor
        
        // Create bounding box entity
        let boxEntity = createBoundingBoxEntity(box: box, color: boxColor)
        boxEntity.position = position
        
        if let anchor = scene.anchors.first {
            anchor.addChild(boxEntity)
            boundingBoxEntities.append(boxEntity)
        }
        
        // Add dimension labels
        addDimensionLabels(for: box, at: position, in: scene)
    }
    
    /// Create the bounding box wireframe entity
    private func createBoundingBoxEntity(box: BoundingBox, color: UIColor) -> Entity {
        let container = Entity()
        let material = SimpleMaterial(color: color, isMetallic: false)
        
        // Create edges
        let corners = box.corners
        for (startIdx, endIdx) in BoundingBox.edgeIndices {
            let start = corners[startIdx]
            let end = corners[endIdx]
            let edge = createEdgeEntity(from: start, to: end, material: material)
            container.addChild(edge)
        }
        
        // Create corner spheres
        let sphereMesh = MeshResource.generateSphere(radius: Config.cornerRadius)
        for corner in corners {
            let sphere = ModelEntity(mesh: sphereMesh, materials: [material])
            sphere.position = corner
            container.addChild(sphere)
        }
        
        return container
    }
    
    /// Create a single edge entity between two points
    private func createEdgeEntity(from start: SIMD3<Float>, to end: SIMD3<Float>, material: Material) -> ModelEntity {
        let length = simd_distance(start, end)
        let midpoint = (start + end) / 2
        
        // Create thin box as edge
        let mesh = MeshResource.generateBox(size: [Config.edgeRadius * 2, Config.edgeRadius * 2, length])
        let edge = ModelEntity(mesh: mesh, materials: [material])
        edge.position = midpoint
        
        // Rotate to align with edge direction
        let direction = normalize(end - start)
        let up = SIMD3<Float>(0, 0, 1)
        
        // Handle edge cases where direction is parallel to up vector
        if abs(dot(direction, up)) > 0.999 {
            // Edge is vertical, no rotation needed for Z-aligned box
            if direction.z < 0 {
                edge.orientation = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
            }
        } else {
            edge.look(at: end, from: midpoint, relativeTo: nil)
        }
        
        return edge
    }
    
    /// Add dimension labels for width, height, depth
    private func addDimensionLabels(for box: BoundingBox, at position: SIMD3<Float>, in scene: RealityKit.Scene) {
        guard let anchor = scene.anchors.first else { return }
        
        // Width label (along X axis, below the box)
        let widthPos = SIMD3(
            box.center.x,
            box.min.y - Config.labelOffset,
            box.max.z + Config.labelOffset
        ) + position
        let widthLabel = createTextLabel(
            text: formatDimensionWithLabel(box.width, axis: "W"),
            at: widthPos
        )
        anchor.addChild(widthLabel)
        dimensionLabelEntities.append(widthLabel)
        
        // Height label (along Y axis, to the right)
        let heightPos = SIMD3(
            box.max.x + Config.labelOffset,
            box.center.y,
            box.max.z + Config.labelOffset
        ) + position
        let heightLabel = createTextLabel(
            text: formatDimensionWithLabel(box.height, axis: "H"),
            at: heightPos
        )
        anchor.addChild(heightLabel)
        dimensionLabelEntities.append(heightLabel)
        
        // Depth label (along Z axis, to the front)
        let depthPos = SIMD3(
            box.max.x + Config.labelOffset,
            box.min.y - Config.labelOffset,
            box.center.z
        ) + position
        let depthLabel = createTextLabel(
            text: formatDimensionWithLabel(box.depth, axis: "D"),
            at: depthPos
        )
        anchor.addChild(depthLabel)
        dimensionLabelEntities.append(depthLabel)
    }
    
    /// Create a 3D text label entity
    private func createTextLabel(text: String, at position: SIMD3<Float>) -> Entity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: Config.labelFontSize, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        let material = SimpleMaterial(color: Config.labelTextColor, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        
        // Scale down for appropriate size in AR
        entity.scale = SIMD3<Float>(repeating: 1.0)
        
        return entity
    }
    
    /// Show distance line between two entities
    func showDistanceLine(from entityA: Entity, to entityB: Entity, in scene: RealityKit.Scene) {
        let posA = entityA.position(relativeTo: nil)
        let posB = entityB.position(relativeTo: nil)
        
        let lineEntity = createDistanceLineEntity(from: posA, to: posB)
        
        if let anchor = scene.anchors.first {
            anchor.addChild(lineEntity)
            distanceLineEntities.append(lineEntity)
        }
    }
    
    /// Create distance line with label
    private func createDistanceLineEntity(from start: SIMD3<Float>, to end: SIMD3<Float>) -> Entity {
        let container = Entity()
        let material = SimpleMaterial(color: Config.boxColor, isMetallic: false)
        
        // Create line
        let dist = simd_distance(start, end)
        let midpoint = (start + end) / 2
        
        let lineMesh = MeshResource.generateCylinder(height: dist, radius: Config.edgeRadius)
        let line = ModelEntity(mesh: lineMesh, materials: [material])
        line.position = midpoint
        
        // Rotate cylinder to align with direction
        let direction = normalize(end - start)
        let up = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(from: up, to: direction)
        line.orientation = rotation
        
        container.addChild(line)
        
        // Create endpoint markers
        let markerMesh = MeshResource.generateSphere(radius: Config.cornerRadius * 1.5)
        
        let startMarker = ModelEntity(mesh: markerMesh, materials: [material])
        startMarker.position = start
        container.addChild(startMarker)
        
        let endMarker = ModelEntity(mesh: markerMesh, materials: [material])
        endMarker.position = end
        container.addChild(endMarker)
        
        // Add distance label
        let labelPos = midpoint + SIMD3(0, Config.labelOffset, 0)
        let label = createTextLabel(text: formatDimension(dist), at: labelPos)
        container.addChild(label)
        
        return container
    }
    
    /// Clear all measurement visualizations
    func clearAllMeasurements() {
        boundingBoxEntities.forEach { $0.removeFromParent() }
        boundingBoxEntities.removeAll()
        
        dimensionLabelEntities.forEach { $0.removeFromParent() }
        dimensionLabelEntities.removeAll()
        
        distanceLineEntities.forEach { $0.removeFromParent() }
        distanceLineEntities.removeAll()
    }
    
    /// Clear only bounding boxes and labels (not distance lines)
    func clearBoundingBoxes() {
        boundingBoxEntities.forEach { $0.removeFromParent() }
        boundingBoxEntities.removeAll()
        
        dimensionLabelEntities.forEach { $0.removeFromParent() }
        dimensionLabelEntities.removeAll()
    }
    
    /// Clear only distance lines
    func clearDistanceLines() {
        distanceLineEntities.forEach { $0.removeFromParent() }
        distanceLineEntities.removeAll()
    }
    
    /// Update all labels to reflect current unit
    func refreshLabelsForUnitChange(in scene: RealityKit.Scene) {
        // Clear existing visualizations
        clearAllMeasurements()
        
        // Recreate with new unit (caller should handle this)
        savePreferences()
    }
    
    // MARK: - Toggle State
    
    func toggle() {
        isEnabled.toggle()
        if !isEnabled {
            clearAllMeasurements()
        }
    }
    
    func enable() {
        isEnabled = true
    }
    
    func disable() {
        isEnabled = false
        clearAllMeasurements()
    }
}
