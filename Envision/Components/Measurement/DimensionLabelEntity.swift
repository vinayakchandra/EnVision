//
//  DimensionLabelEntity.swift
//  Envision
//
//  Billboard text labels for displaying dimensions in AR
//

import RealityKit
import UIKit

/// Axis type for dimension labels
enum DimensionAxis: String {
    case width = "W"
    case height = "H"
    case depth = "D"
    case distance = "↔"
    
    var color: UIColor {
        switch self {
        case .width: return .systemBlue
        case .height: return .systemGreen
        case .depth: return .systemOrange
        case .distance: return AppColors.accent
        }
    }
}

/// A RealityKit Entity that displays a dimension label that can face the camera
final class DimensionLabelEntity: Entity {
    
    // MARK: - Properties
    
    private var textEntity: ModelEntity?
    private var backgroundEntity: ModelEntity?
    
    private let axis: DimensionAxis
    private let value: Float
    private let unit: MeasurementUnit
    
    // MARK: - Configuration
    
    private struct Config {
        static let fontSize: CGFloat = 0.012
        static let extrusionDepth: Float = 0.001
        static let backgroundPadding: Float = 0.005
        static let backgroundCornerRadius: Float = 0.003
        static var textColor: UIColor {
            UITraitCollection.current.userInterfaceStyle == .dark ? .white : .black
        }
        static let backgroundColor: UIColor = AppColors.accent
    }
    
    // MARK: - Initialization
    
    required init() {
        self.axis = .width
        self.value = 0
        self.unit = .metric
        super.init()
    }
    
    /// Initialize with a specific dimension value
    /// - Parameters:
    ///   - value: The dimension value in meters
    ///   - axis: The axis this dimension represents
    ///   - unit: The measurement unit for display
    ///   - position: The position in 3D space
    convenience init(
        value: Float,
        axis: DimensionAxis,
        unit: MeasurementUnit = .metric,
        position: SIMD3<Float>
    ) {
        self.init()
        self.position = position
        setup(value: value, axis: axis, unit: unit)
    }
    
    /// Initialize with pre-formatted text
    /// - Parameters:
    ///   - text: The text to display
    ///   - position: The position in 3D space
    ///   - backgroundColor: Optional custom background color
    convenience init(
        text: String,
        position: SIMD3<Float>,
        backgroundColor: UIColor = AppColors.accent
    ) {
        self.init()
        self.position = position
        setupWithText(text, backgroundColor: backgroundColor)
    }
    
    // MARK: - Setup
    
    private func setup(value: Float, axis: DimensionAxis, unit: MeasurementUnit) {
        let formattedValue = MeasurementManager.shared.formatDimension(value)
        let displayText = "\(axis.rawValue): \(formattedValue)"
        setupWithText(displayText, backgroundColor: Config.backgroundColor)
    }
    
    private func setupWithText(_ text: String, backgroundColor: UIColor) {
        // Create text mesh
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: Config.extrusionDepth,
            font: .systemFont(ofSize: Config.fontSize, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        let textMaterial = SimpleMaterial(color: Config.textColor, roughness: 0.3, isMetallic: false)
        let text3D = ModelEntity(mesh: textMesh, materials: [textMaterial])
        
        // Center the text
        let textBounds = text3D.visualBounds(relativeTo: nil)
        let textWidth = textBounds.max.x - textBounds.min.x
        let textHeight = textBounds.max.y - textBounds.min.y
        text3D.position = SIMD3(-textWidth / 2, -textHeight / 2, Config.extrusionDepth)
        
        // Create background plane
        let bgWidth = textWidth + Config.backgroundPadding * 2
        let bgHeight = textHeight + Config.backgroundPadding * 2
        let bgMesh = MeshResource.generatePlane(width: bgWidth, height: bgHeight, cornerRadius: Config.backgroundCornerRadius)
        let bgMaterial = SimpleMaterial(color: backgroundColor, roughness: 0.5, isMetallic: false)
        let background = ModelEntity(mesh: bgMesh, materials: [bgMaterial])
        background.position = SIMD3(0, 0, 0)
        
        // Add children
        addChild(background)
        addChild(text3D)
        
        self.backgroundEntity = background
        self.textEntity = text3D
    }
    
    // MARK: - Update Methods
    
    /// Update the label to face the camera position
    /// - Parameter cameraPosition: The camera's world position
    func faceCamera(at cameraPosition: SIMD3<Float>) {
        let direction = normalize(cameraPosition - self.position)
        
        // Calculate rotation to face camera
        let up = SIMD3<Float>(0, 1, 0)
        let right = normalize(cross(up, direction))
        let adjustedUp = cross(direction, right)
        
        // Create rotation matrix
        let rotationMatrix = simd_float3x3(columns: (right, adjustedUp, direction))
        self.orientation = simd_quatf(rotationMatrix)
    }
    
    /// Update the displayed value
    /// - Parameters:
    ///   - value: New value in meters
    ///   - unit: Measurement unit
    func updateValue(_ value: Float, unit: MeasurementUnit) {
        // Remove existing entities
        textEntity?.removeFromParent()
        backgroundEntity?.removeFromParent()
        
        // Recreate with new value
        let formattedValue = MeasurementManager.shared.formatDimension(value)
        setupWithText(formattedValue, backgroundColor: Config.backgroundColor)
    }
    
    /// Update background color
    func updateBackgroundColor(_ color: UIColor) {
        let material = SimpleMaterial(color: color, roughness: 0.5, isMetallic: false)
        backgroundEntity?.model?.materials = [material]
    }
    
    // MARK: - Visibility
    
    func setVisible(_ visible: Bool) {
        self.isEnabled = visible
    }
    
    // MARK: - Cleanup
    
    func remove() {
        textEntity?.removeFromParent()
        backgroundEntity?.removeFromParent()
        removeFromParent()
    }
}

// MARK: - Distance Line Label

/// A specialized label for showing distance between two points
final class DistanceLabelEntity: Entity {
    
    private var labelEntity: DimensionLabelEntity?
    private var lineEntity: ModelEntity?
    private var startMarker: ModelEntity?
    private var endMarker: ModelEntity?
    
    private let startPoint: SIMD3<Float>
    private let endPoint: SIMD3<Float>
    private var unit: MeasurementUnit
    
    // MARK: - Configuration
    
    private struct Config {
        static let lineRadius: Float = 0.001
        static let markerRadius: Float = 0.004
        static let labelOffset: Float = 0.04
        static let lineColor: UIColor = AppColors.accent
    }
    
    required init() {
        self.startPoint = .zero
        self.endPoint = .zero
        self.unit = .metric
        super.init()
    }
    
    /// Initialize with start and end points
    convenience init(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        unit: MeasurementUnit = .metric
    ) {
        self.init()
        setup(from: start, to: end, unit: unit)
    }
    
    private func setup(from start: SIMD3<Float>, to end: SIMD3<Float>, unit: MeasurementUnit) {
        let material = SimpleMaterial(color: Config.lineColor, roughness: 0.5, isMetallic: false)
        
        // Calculate distance
        let distance = simd_distance(start, end)
        let midpoint = (start + end) / 2
        
        // Create line (cylinder)
        let lineMesh = MeshResource.generateCylinder(height: distance, radius: Config.lineRadius)
        let line = ModelEntity(mesh: lineMesh, materials: [material])
        line.position = midpoint
        
        // Rotate line to align with direction
        let direction = normalize(end - start)
        let up = SIMD3<Float>(0, 1, 0)
        if abs(dot(direction, up)) < 0.9999 {
            let rotation = simd_quatf(from: up, to: direction)
            line.orientation = rotation
        }
        
        addChild(line)
        self.lineEntity = line
        
        // Create endpoint markers
        let markerMesh = MeshResource.generateSphere(radius: Config.markerRadius)
        
        let startM = ModelEntity(mesh: markerMesh, materials: [material])
        startM.position = start
        addChild(startM)
        self.startMarker = startM
        
        let endM = ModelEntity(mesh: markerMesh, materials: [material])
        endM.position = end
        addChild(endM)
        self.endMarker = endM
        
        // Create distance label
        let labelPos = midpoint + SIMD3(0, Config.labelOffset, 0)
        let formattedDistance = MeasurementManager.shared.formatDimension(distance)
        let label = DimensionLabelEntity(text: formattedDistance, position: labelPos)
        addChild(label)
        self.labelEntity = label
    }
    
    /// Update the unit and refresh the label
    func updateUnit(_ newUnit: MeasurementUnit) {
        self.unit = newUnit
        
        // Recalculate and update label
        let distance = simd_distance(startPoint, endPoint)
        labelEntity?.updateValue(distance, unit: newUnit)
    }
    
    /// Update label to face camera
    func faceCamera(at cameraPosition: SIMD3<Float>) {
        labelEntity?.faceCamera(at: cameraPosition)
    }
    
    func remove() {
        lineEntity?.removeFromParent()
        startMarker?.removeFromParent()
        endMarker?.removeFromParent()
        labelEntity?.remove()
        removeFromParent()
    }
}
