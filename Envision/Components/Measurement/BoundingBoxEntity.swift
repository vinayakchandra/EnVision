//
//  BoundingBoxEntity.swift
//  Envision
//
//  3D wireframe bounding box visualization for furniture measurements
//

import RealityKit
import UIKit

/// A RealityKit Entity that displays a 3D wireframe bounding box with dimension labels
final class BoundingBoxEntity: Entity {
    
    // MARK: - Properties
    
    private var edgeEntities: [ModelEntity] = []
    private var cornerEntities: [ModelEntity] = []
    private var labelEntities: [ModelEntity] = []
    
    private let boundingBox: BoundingBox
    private let color: UIColor
    private let unit: MeasurementUnit

    private static var measurementTextColor: UIColor {
        UITraitCollection.current.userInterfaceStyle == .dark ? .white : .black
    }
    
    // MARK: - Configuration
    
    private struct Config {
        static let edgeRadius: Float = 0.001      // 1mm edge thickness
        static let cornerRadius: Float = 0.002    // 2mm corner spheres
        static let labelOffset: Float = 0.05      // 5cm label offset
        static let labelScale: Float = 0.8        // Label scale factor
    }
    
    // MARK: - Initialization
    
    required init() {
        self.boundingBox = BoundingBox(min: .zero, max: .one)
        self.color = AppColors.accent
        self.unit = .metric
        super.init()
    }
    
    /// Initialize with a bounding box and customization options
    /// - Parameters:
    ///   - boundingBox: The bounding box to visualize
    ///   - color: The color for edges and corners
    ///   - unit: The measurement unit for labels
    ///   - showLabels: Whether to show dimension labels
    convenience init(
        boundingBox: BoundingBox,
        color: UIColor = AppColors.accent,
        unit: MeasurementUnit = .metric,
        showLabels: Bool = true
    ) {
        self.init()
        
        // Store reference (note: we can't reassign let properties after super.init)
        // So we'll recreate in setup
        setup(boundingBox: boundingBox, color: color, unit: unit, showLabels: showLabels)
    }
    
    /// Create bounding box entity from an Entity's visual bounds
    /// - Parameters:
    ///   - entity: The entity to create bounding box for
    ///   - color: The color for edges and corners
    ///   - unit: The measurement unit for labels
    ///   - showLabels: Whether to show dimension labels
    convenience init(
        for entity: Entity,
        color: UIColor = AppColors.accent,
        unit: MeasurementUnit = .metric,
        showLabels: Bool = true
    ) {
        let box = BoundingBox(from: entity)
        self.init(boundingBox: box, color: color, unit: unit, showLabels: showLabels)
    }
    
    // MARK: - Setup
    
    private func setup(
        boundingBox: BoundingBox,
        color: UIColor,
        unit: MeasurementUnit,
        showLabels: Bool
    ) {
        // Clear any existing entities
        clearAll()
        
        // Create edges
        createEdges(box: boundingBox, color: color)
        
        // Create corners
        createCorners(box: boundingBox, color: color)
        
        // Create labels if requested
        if showLabels {
            createDimensionLabels(box: boundingBox, unit: unit)
        }
    }
    
    // MARK: - Edge Creation
    
    private func createEdges(box: BoundingBox, color: UIColor) {
        let corners = box.corners
        let material = SimpleMaterial(color: color, roughness: 0.5, isMetallic: false)
        
        for (startIdx, endIdx) in BoundingBox.edgeIndices {
            let start = corners[startIdx]
            let end = corners[endIdx]
            let edge = createEdge(from: start, to: end, material: material)
            addChild(edge)
            edgeEntities.append(edge)
        }
    }
    
    private func createEdge(from start: SIMD3<Float>, to end: SIMD3<Float>, material: Material) -> ModelEntity {
        let length = simd_distance(start, end)
        let midpoint = (start + end) / 2
        
        // Create thin box as edge
        let mesh = MeshResource.generateBox(size: [Config.edgeRadius * 2, Config.edgeRadius * 2, length])
        let edge = ModelEntity(mesh: mesh, materials: [material])
        edge.position = midpoint
        
        // Calculate rotation to align edge with direction
        let direction = normalize(end - start)
        alignEntity(edge, toDirection: direction)
        
        return edge
    }
    
    private func alignEntity(_ entity: ModelEntity, toDirection direction: SIMD3<Float>) {
        // Default box is aligned with Z axis
        let defaultDirection = SIMD3<Float>(0, 0, 1)
        
        // Check if directions are nearly parallel
        let dotProduct = dot(direction, defaultDirection)
        
        if abs(dotProduct) > 0.9999 {
            // Directions are parallel
            if dotProduct < 0 {
                // Opposite direction, rotate 180° around X
                entity.orientation = simd_quatf(angle: .pi, axis: SIMD3(1, 0, 0))
            }
            // Same direction, no rotation needed
        } else {
            // Calculate rotation axis and angle
            let axis = normalize(cross(defaultDirection, direction))
            let angle = acos(dotProduct)
            entity.orientation = simd_quatf(angle: angle, axis: axis)
        }
    }
    
    // MARK: - Corner Creation
    
    private func createCorners(box: BoundingBox, color: UIColor) {
        let corners = box.corners
        let material = SimpleMaterial(color: color, roughness: 0.5, isMetallic: false)
        let mesh = MeshResource.generateSphere(radius: Config.cornerRadius)
        
        for corner in corners {
            let sphere = ModelEntity(mesh: mesh, materials: [material])
            sphere.position = corner
            addChild(sphere)
            cornerEntities.append(sphere)
        }
    }
    
    // MARK: - Label Creation
    
    private func createDimensionLabels(box: BoundingBox, unit: MeasurementUnit) {
        let manager = MeasurementManager.shared
        
        // Width label (X axis) - positioned below and in front
        let widthText = "W: \(manager.formatDimension(box.width))"
        let widthPos = SIMD3<Float>(
            box.center.x,
            box.min.y - Config.labelOffset,
            box.max.z + Config.labelOffset * 0.5
        )
        let widthLabel = createLabel(text: widthText, at: widthPos)
        addChild(widthLabel)
        labelEntities.append(widthLabel)
        
        // Height label (Y axis) - positioned to the right
        let heightText = "H: \(manager.formatDimension(box.height))"
        let heightPos = SIMD3<Float>(
            box.max.x + Config.labelOffset,
            box.center.y,
            box.max.z
        )
        let heightLabel = createLabel(text: heightText, at: heightPos)
        addChild(heightLabel)
        labelEntities.append(heightLabel)
        
        // Depth label (Z axis) - positioned to the right and below
        let depthText = "D: \(manager.formatDimension(box.depth))"
        let depthPos = SIMD3<Float>(
            box.max.x + Config.labelOffset * 0.5,
            box.min.y - Config.labelOffset * 0.5,
            box.center.z
        )
        let depthLabel = createLabel(text: depthText, at: depthPos)
        addChild(depthLabel)
        labelEntities.append(depthLabel)
    }
    
    private func createLabel(text: String, at position: SIMD3<Float>) -> ModelEntity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.015, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        let material = SimpleMaterial(color: Self.measurementTextColor, roughness: 0.3, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        entity.scale = SIMD3<Float>(repeating: Config.labelScale)
        
        return entity
    }
    
    // MARK: - Update Methods
    
    /// Update the bounding box color
    func updateColor(_ newColor: UIColor) {
        let material = SimpleMaterial(color: newColor, roughness: 0.5, isMetallic: false)
        
        for edge in edgeEntities {
            edge.model?.materials = [material]
        }
        
        for corner in cornerEntities {
            corner.model?.materials = [material]
        }
    }
    
    /// Update labels for a new measurement unit
    func updateUnit(_ newUnit: MeasurementUnit, box: BoundingBox) {
        // Remove old labels
        labelEntities.forEach { $0.removeFromParent() }
        labelEntities.removeAll()
        
        // Create new labels
        createDimensionLabels(box: box, unit: newUnit)
    }
    
    // MARK: - Visibility
    
    /// Show/hide labels
    func setLabelsVisible(_ visible: Bool) {
        labelEntities.forEach { $0.isEnabled = visible }
    }
    
    /// Show/hide entire bounding box
    func setVisible(_ visible: Bool) {
        self.isEnabled = visible
    }
    
    // MARK: - Cleanup
    
    private func clearAll() {
        edgeEntities.forEach { $0.removeFromParent() }
        edgeEntities.removeAll()
        
        cornerEntities.forEach { $0.removeFromParent() }
        cornerEntities.removeAll()
        
        labelEntities.forEach { $0.removeFromParent() }
        labelEntities.removeAll()
    }
    
    /// Remove this bounding box from the scene
    func remove() {
        clearAll()
        removeFromParent()
    }
}

// MARK: - Factory Methods

extension BoundingBoxEntity {
    
    /// Create a bounding box for measuring room dimensions
    static func forRoom(entity: Entity, unit: MeasurementUnit = .metric) -> BoundingBoxEntity {
        return BoundingBoxEntity(
            for: entity,
            color: AppColors.accent.withAlphaComponent(0.8),
            unit: unit,
            showLabels: true
        )
    }
    
    /// Create a bounding box for measuring furniture
    static func forFurniture(entity: Entity, unit: MeasurementUnit = .metric) -> BoundingBoxEntity {
        return BoundingBoxEntity(
            for: entity,
            color: AppColors.accent,
            unit: unit,
            showLabels: true
        )
    }
    
    /// Create a simple bounding box without labels (for selection highlighting)
    static func forSelection(entity: Entity, color: UIColor = .systemBlue) -> BoundingBoxEntity {
        return BoundingBoxEntity(
            for: entity,
            color: color,
            unit: .metric,
            showLabels: false
        )
    }
}
