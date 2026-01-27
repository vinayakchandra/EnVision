# EnVision - AR Measurement Tool Implementation Plan
*Complete Guide for Adding Measurement Features to Room & Furniture Viewing*

---

## Table of Contents
1. [Overview](#1-overview)
2. [Measurement Types](#2-measurement-types)
3. [Technical Architecture](#3-technical-architecture)
4. [UI/UX Design](#4-uiux-design)
5. [RealityKit Implementation](#5-realitykit-implementation)
6. [ARKit Implementation (Alternative)](#6-arkit-implementation-alternative)
7. [Measurement Precision](#7-measurement-precision)
8. [Code Implementation](#8-code-implementation)
9. [Testing Plan](#9-testing-plan)
10. [Enhancement Ideas](#10-enhancement-ideas)

---

## 1. Overview

### 1.1 Purpose
Add real-world measurement capabilities to EnVision's 3D viewing experience, allowing users to:
- Measure distances between furniture pieces
- Measure dimensions of individual furniture items
- Measure room dimensions (walls, floor area, ceiling height)
- Verify furniture will fit in specific locations
- Plan room layouts with accurate spacing

### 1.2 User Stories
1. **"Will this sofa fit?"** - User measures sofa length and compares to wall space
2. **"How much clearance?"** - User measures distance between furniture pieces
3. **"Room dimensions?"** - User measures room walls to verify model accuracy
4. **"Height check"** - User measures furniture height to ensure it fits under shelves
5. **"Floor area"** - User measures available floor space for new furniture

### 1.3 Where to Add Measurements

**Existing View Controllers**:
- ✅ `RoomViewerViewController.swift` - View room with placed furniture (PRIORITY)
- ✅ `RoomVisualizeVC.swift` - 3D room visualization
- ⚠️ `MyRoomsViewController.swift` - Could show room dimensions in list view
- ⚠️ `ScanFurnitureViewController.swift` - Could show furniture dimensions

### 1.4 Key Features
- **Point-to-Point Measurement**: Tap two points, see distance
- **Object Dimension Display**: Show width × length × height for selected furniture
- **Room Dimension Display**: Show room measurements (from RoomPlan metadata)
- **Measurement History**: Keep list of recent measurements
- **Units Toggle**: Metric (meters/cm) ↔ Imperial (feet/inches)
- **Export Measurements**: Share as text or screenshot

---

## 2. Measurement Types

### 2.1 Point-to-Point Distance
**Use Case**: "How far is this chair from that table?"

**Visual**:
```
   Start Point ●─────────────● End Point
              └─ 2.45 m ─┘
```

**Interaction**:
1. Tap "Measure" button
2. Tap first location
3. Tap second location
4. Distance shown in floating label

### 2.2 Furniture Dimensions
**Use Case**: "How big is this chair?"

**Visual**:
```
        ┌─────┐
        │     │ Height: 0.92 m
        │     │
        └─────┘
    Width: 0.65 m
    Depth: 0.58 m
```

**Interaction**:
1. Tap furniture item
2. Show bounding box with dimensions
3. Display width × depth × height

### 2.3 Room Dimensions
**Use Case**: "What are the exact room measurements?"

**Visual**:
```
    5.2 m
  ┌───────────┐
  │           │ 4.1 m
  │   Room    │
  │           │
  └───────────┘
  Height: 2.7 m
  Area: 21.3 m²
```

**Interaction**:
1. Tap "Room Info" button
2. Show overlay with dimensions from RoomPlan metadata
3. Display floor area calculation

### 2.4 Multiple Measurements
**Use Case**: "Compare several distances"

**Visual**:
```
  ●─1.2m─● Table
           │
         0.8m
           │
  ●─1.5m─● Chair
```

**Interaction**:
1. Create multiple measurements
2. Label each measurement
3. Show measurement list panel
4. Delete individual measurements

---

## 3. Technical Architecture

### 3.1 Core Components

```swift
// MARK: - Measurement Data Model
struct Measurement {
    let id: UUID
    let type: MeasurementType
    let startPoint: SIMD3<Float>
    let endPoint: SIMD3<Float>
    let distance: Float
    let label: String?
    let timestamp: Date
}

enum MeasurementType {
    case pointToPoint
    case objectDimensions
    case roomDimensions
}

// MARK: - Measurement Manager
class MeasurementManager {
    var measurements: [Measurement] = []
    var isActive: Bool = false
    var currentUnit: MeasurementUnit = .metric
    
    func addMeasurement(_ measurement: Measurement)
    func removeMeasurement(id: UUID)
    func clearAllMeasurements()
    func formatDistance(_ meters: Float) -> String
}

// MARK: - Measurement Visualizer (RealityKit)
class MeasurementVisualizer {
    func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>) -> ModelEntity
    func createLabel(text: String, at position: SIMD3<Float>) -> ModelEntity
    func createBoundingBox(for entity: ModelEntity) -> ModelEntity
}
```

### 3.2 Flow Diagram

```
User taps "Measure" button
    ↓
Measurement mode activated
    ↓
User taps first point (raycast to detect surface/object)
    ↓
Show start point indicator ●
    ↓
User moves finger (show live line + distance)
    ↓
User taps second point
    ↓
Calculate distance (Euclidean)
    ↓
Create permanent line + label (RealityKit entity)
    ↓
Add to measurements list
    ↓
Measurement mode stays active (repeat) or exit
```

---

## 4. UI/UX Design

### 4.1 Measurement Controls Panel

**Location**: Bottom of screen (above furniture picker if present)

```
┌────────────────────────────────────┐
│  [📏 Measure]  [📐 Dimensions]  [ℹ️ Info]  │
│                                    │
│  [Clear All]  [m ↔ ft]  [Export]  │
└────────────────────────────────────┘
```

**Buttons**:
- **📏 Measure**: Toggle point-to-point mode
- **📐 Dimensions**: Show furniture dimensions
- **ℹ️ Info**: Show room info panel
- **Clear All**: Remove all measurements
- **m ↔ ft**: Toggle units
- **Export**: Share screenshot + text list

### 4.2 Measurement Display Styles

**Label Style** (floating above line):
```
╔═══════════╗
║  2.45 m   ║
╚═══════════╝
```

**Properties**:
- Background: Semi-transparent white/dark (adapts to scene)
- Text: Bold, 16pt
- Border: 1pt stroke
- Shadow: Subtle drop shadow for depth

### 4.3 Visual Elements

**Point Indicator**:
- Sphere: 0.05m radius
- Color: System blue (bright, visible)
- Material: Unlit (always visible)

**Measurement Line**:
- Cylinder: 0.01m radius
- Color: System blue
- Material: Unlit
- Dashed style (optional)

**Bounding Box** (for furniture dimensions):
- Wireframe box around object
- Color: System green
- Line width: 2pt
- Corner spheres for anchors

### 4.4 Interaction States

**Idle** (default):
- No measurement mode active
- No visual overlays

**Measuring** (active):
- First point placed → blue sphere
- Moving finger → live line follows
- Second point placed → line + label created

**Selected** (tap existing measurement):
- Highlight measurement in yellow
- Show edit/delete buttons
- Allow repositioning endpoints

---

## 5. RealityKit Implementation

### 5.1 Create MeasurementManager

**File**: `Envision/Managers/MeasurementManager.swift`

```swift
import Foundation
import RealityKit

final class MeasurementManager {
    static let shared = MeasurementManager()
    
    enum MeasurementUnit {
        case metric  // meters/centimeters
        case imperial // feet/inches
    }
    
    private(set) var measurements: [Measurement] = []
    private(set) var isActive: Bool = false
    var currentUnit: MeasurementUnit = .metric {
        didSet {
            // Notify UI to refresh labels
            NotificationCenter.default.post(name: .measurementUnitChanged, object: nil)
        }
    }
    
    private init() {}
    
    // MARK: - Measurement CRUD
    
    func addMeasurement(_ measurement: Measurement) {
        measurements.append(measurement)
        NotificationCenter.default.post(name: .measurementAdded, object: measurement)
    }
    
    func removeMeasurement(id: UUID) {
        measurements.removeAll { $0.id == id }
        NotificationCenter.default.post(name: .measurementRemoved, object: id)
    }
    
    func clearAllMeasurements() {
        measurements.removeAll()
        NotificationCenter.default.post(name: .measurementsCleared, object: nil)
    }
    
    // MARK: - Activation
    
    func activateMeasurementMode() {
        isActive = true
    }
    
    func deactivateMeasurementMode() {
        isActive = false
    }
    
    // MARK: - Formatting
    
    func formatDistance(_ meters: Float) -> String {
        switch currentUnit {
        case .metric:
            if meters < 1.0 {
                return String(format: "%.0f cm", meters * 100)
            } else {
                return String(format: "%.2f m", meters)
            }
        case .imperial:
            let feet = meters * 3.28084
            let totalInches = feet * 12
            let feetPart = Int(totalInches / 12)
            let inchesPart = totalInches.truncatingRemainder(dividingBy: 12)
            return String(format: "%d' %.1f\"", feetPart, inchesPart)
        }
    }
    
    func formatArea(_ squareMeters: Float) -> String {
        switch currentUnit {
        case .metric:
            return String(format: "%.2f m²", squareMeters)
        case .imperial:
            let sqFeet = squareMeters * 10.7639
            return String(format: "%.2f ft²", sqFeet)
        }
    }
    
    // MARK: - Export
    
    func exportMeasurementsAsText() -> String {
        var text = "EnVision Measurements\n"
        text += "Date: \(Date().formatted())\n\n"
        
        for (index, measurement) in measurements.enumerated() {
            text += "\(index + 1). "
            text += "\(measurement.label ?? "Measurement"): "
            text += formatDistance(measurement.distance)
            text += "\n"
        }
        
        return text
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let measurementAdded = Notification.Name("measurementAdded")
    static let measurementRemoved = Notification.Name("measurementRemoved")
    static let measurementsCleared = Notification.Name("measurementsCleared")
    static let measurementUnitChanged = Notification.Name("measurementUnitChanged")
}

// MARK: - Measurement Model
struct Measurement {
    let id: UUID
    let type: MeasurementType
    let startPoint: SIMD3<Float>
    let endPoint: SIMD3<Float>
    var distance: Float {
        return simd_distance(startPoint, endPoint)
    }
    var label: String?
    let timestamp: Date
    
    init(type: MeasurementType, startPoint: SIMD3<Float>, endPoint: SIMD3<Float>, label: String? = nil) {
        self.id = UUID()
        self.type = type
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.label = label
        self.timestamp = Date()
    }
}

enum MeasurementType {
    case pointToPoint
    case objectDimensions
    case roomDimensions
}
```

### 5.2 Create MeasurementVisualizer

**File**: `Envision/Managers/MeasurementVisualizer.swift`

```swift
import Foundation
import RealityKit

final class MeasurementVisualizer {
    
    // MARK: - Create Point Indicator
    
    func createPointIndicator(at position: SIMD3<Float>) -> ModelEntity {
        let sphere = MeshResource.generateSphere(radius: 0.02) // 2cm sphere
        
        var material = UnlitMaterial()
        material.color = .init(tint: .systemBlue)
        
        let entity = ModelEntity(mesh: sphere, materials: [material])
        entity.position = position
        entity.name = "measurementPoint"
        
        return entity
    }
    
    // MARK: - Create Line Between Points
    
    func createLine(from start: SIMD3<Float>, to end: SIMD3<Float>) -> ModelEntity {
        let distance = simd_distance(start, end)
        
        // Create cylinder as line
        let cylinder = MeshResource.generateCylinder(height: distance, radius: 0.005) // 0.5cm thick
        
        var material = UnlitMaterial()
        material.color = .init(tint: .systemBlue)
        
        let entity = ModelEntity(mesh: cylinder, materials: [material])
        
        // Position at midpoint
        let midpoint = (start + end) / 2
        entity.position = midpoint
        
        // Rotate to align with start-end vector
        let direction = end - start
        let up = SIMD3<Float>(0, 1, 0)
        
        // Calculate rotation to align Y-axis with direction
        let rotationAxis = simd_cross(up, simd_normalize(direction))
        let rotationAngle = acos(simd_dot(up, simd_normalize(direction)))
        
        if simd_length(rotationAxis) > 0.001 {
            entity.orientation = simd_quatf(angle: rotationAngle, axis: simd_normalize(rotationAxis))
        }
        
        entity.name = "measurementLine"
        
        return entity
    }
    
    // MARK: - Create Text Label
    
    func createLabel(text: String, at position: SIMD3<Float>, billboarding: Bool = true) -> ModelEntity {
        // Create text mesh
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.05), // 5cm font size
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        
        var material = UnlitMaterial()
        material.color = .init(tint: .white)
        
        let textEntity = ModelEntity(mesh: textMesh, materials: [material])
        textEntity.position = position + SIMD3<Float>(0, 0.1, 0) // Offset above line
        
        // Add background panel
        let panelWidth: Float = 0.3
        let panelHeight: Float = 0.08
        let panel = MeshResource.generatePlane(width: panelWidth, height: panelHeight)
        
        var panelMaterial = UnlitMaterial()
        panelMaterial.color = .init(tint: UIColor.black.withAlphaComponent(0.7))
        
        let panelEntity = ModelEntity(mesh: panel, materials: [panelMaterial])
        panelEntity.position = SIMD3<Float>(0, 0, -0.002) // Behind text
        
        // Group text and panel
        let labelGroup = ModelEntity()
        labelGroup.addChild(panelEntity)
        labelGroup.addChild(textEntity)
        labelGroup.position = position
        labelGroup.name = "measurementLabel"
        
        // Optional: Make label face camera (billboarding)
        if billboarding {
            // Will need to update orientation each frame (see below)
        }
        
        return labelGroup
    }
    
    // MARK: - Create Bounding Box (for furniture dimensions)
    
    func createBoundingBox(for entity: ModelEntity) -> ModelEntity {
        let bounds = entity.visualBounds(relativeTo: nil)
        let size = bounds.extents
        
        // Create wireframe box
        let boxGroup = ModelEntity()
        boxGroup.name = "boundingBox"
        
        // Create 12 edges of the box
        let edges: [(SIMD3<Float>, SIMD3<Float>)] = [
            // Bottom face
            (SIMD3(-size.x/2, -size.y/2, -size.z/2), SIMD3(size.x/2, -size.y/2, -size.z/2)),
            (SIMD3(size.x/2, -size.y/2, -size.z/2), SIMD3(size.x/2, -size.y/2, size.z/2)),
            (SIMD3(size.x/2, -size.y/2, size.z/2), SIMD3(-size.x/2, -size.y/2, size.z/2)),
            (SIMD3(-size.x/2, -size.y/2, size.z/2), SIMD3(-size.x/2, -size.y/2, -size.z/2)),
            // Top face
            (SIMD3(-size.x/2, size.y/2, -size.z/2), SIMD3(size.x/2, size.y/2, -size.z/2)),
            (SIMD3(size.x/2, size.y/2, -size.z/2), SIMD3(size.x/2, size.y/2, size.z/2)),
            (SIMD3(size.x/2, size.y/2, size.z/2), SIMD3(-size.x/2, size.y/2, size.z/2)),
            (SIMD3(-size.x/2, size.y/2, size.z/2), SIMD3(-size.x/2, size.y/2, -size.z/2)),
            // Vertical edges
            (SIMD3(-size.x/2, -size.y/2, -size.z/2), SIMD3(-size.x/2, size.y/2, -size.z/2)),
            (SIMD3(size.x/2, -size.y/2, -size.z/2), SIMD3(size.x/2, size.y/2, -size.z/2)),
            (SIMD3(size.x/2, -size.y/2, size.z/2), SIMD3(size.x/2, size.y/2, size.z/2)),
            (SIMD3(-size.x/2, -size.y/2, size.z/2), SIMD3(-size.x/2, size.y/2, size.z/2))
        ]
        
        for (start, end) in edges {
            let line = createLine(from: start, to: end)
            line.model?.materials = [createGreenMaterial()]
            boxGroup.addChild(line)
        }
        
        boxGroup.position = bounds.center
        
        return boxGroup
    }
    
    private func createGreenMaterial() -> UnlitMaterial {
        var material = UnlitMaterial()
        material.color = .init(tint: .systemGreen)
        return material
    }
}
```

### 5.3 Update RoomViewerViewController

**File**: `Envision/Screens/MainTabs/Rooms/furniture+room/RoomViewerViewController.swift`

```swift
import UIKit
import RealityKit

// Add properties
private var measurementManager = MeasurementManager.shared
private var measurementVisualizer = MeasurementVisualizer()
private var measurementMode: MeasurementMode = .inactive
private var firstMeasurementPoint: SIMD3<Float>?
private var measurementControlPanel: MeasurementControlPanel!
private var liveMeasurementLine: ModelEntity?
private var measurementEntities: [UUID: [ModelEntity]] = [:] // Track entities per measurement

enum MeasurementMode {
    case inactive
    case pointToPoint
    case objectDimensions
}

// MARK: - Setup Measurement UI

override func viewDidLoad() {
    super.viewDidLoad()
    // ... existing setup code ...
    
    setupMeasurementControls()
    setupMeasurementGestures()
    observeMeasurementNotifications()
}

private func setupMeasurementControls() {
    measurementControlPanel = MeasurementControlPanel()
    measurementControlPanel.translatesAutoresizingMaskIntoConstraints = false
    measurementControlPanel.delegate = self
    view.addSubview(measurementControlPanel)
    
    NSLayoutConstraint.activate([
        measurementControlPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        measurementControlPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        measurementControlPanel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        measurementControlPanel.heightAnchor.constraint(equalToConstant: 100)
    ])
}

// MARK: - Measurement Gestures

private func setupMeasurementGestures() {
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMeasurementTap(_:)))
    arView.addGestureRecognizer(tapGesture)
}

@objc private func handleMeasurementTap(_ gesture: UITapGestureRecognizer) {
    guard measurementMode != .inactive else { return }
    
    let location = gesture.location(in: arView)
    
    switch measurementMode {
    case .pointToPoint:
        handlePointToPointTap(at: location)
    case .objectDimensions:
        handleObjectDimensionsTap(at: location)
    case .inactive:
        break
    }
}

private func handlePointToPointTap(at location: CGPoint) {
    // Raycast to find 3D position
    guard let raycastResult = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first else {
        print("⚠️ No surface found at tap location")
        return
    }
    
    let worldPosition = SIMD3<Float>(
        raycastResult.worldTransform.columns.3.x,
        raycastResult.worldTransform.columns.3.y,
        raycastResult.worldTransform.columns.3.z
    )
    
    if firstMeasurementPoint == nil {
        // First point
        firstMeasurementPoint = worldPosition
        
        // Create point indicator
        let pointEntity = measurementVisualizer.createPointIndicator(at: worldPosition)
        arView.scene.addAnchor(pointEntity)
        
        print("📍 First measurement point placed")
    } else {
        // Second point - complete measurement
        guard let startPoint = firstMeasurementPoint else { return }
        
        // Create measurement
        let measurement = Measurement(
            type: .pointToPoint,
            startPoint: startPoint,
            endPoint: worldPosition,
            label: "Distance"
        )
        
        // Create visual elements
        let lineEntity = measurementVisualizer.createLine(from: startPoint, to: worldPosition)
        let midpoint = (startPoint + worldPosition) / 2
        let labelText = measurementManager.formatDistance(measurement.distance)
        let labelEntity = measurementVisualizer.createLabel(text: labelText, at: midpoint)
        let endPointEntity = measurementVisualizer.createPointIndicator(at: worldPosition)
        
        // Add to scene
        arView.scene.addAnchor(lineEntity)
        arView.scene.addAnchor(labelEntity)
        arView.scene.addAnchor(endPointEntity)
        
        // Store entities
        measurementEntities[measurement.id] = [lineEntity, labelEntity, endPointEntity]
        
        // Add to manager
        measurementManager.addMeasurement(measurement)
        
        // Reset for next measurement
        firstMeasurementPoint = nil
        removeLiveMeasurementLine()
        
        print("✅ Measurement complete: \(labelText)")
    }
}

private func handleObjectDimensionsTap(at location: CGPoint) {
    // Cast ray to find furniture entity
    guard let entity = arView.entity(at: location) as? ModelEntity else {
        print("⚠️ No object found at tap location")
        return
    }
    
    // Get bounding box
    let boundingBox = measurementVisualizer.createBoundingBox(for: entity)
    arView.scene.addAnchor(boundingBox)
    
    // Get dimensions
    let bounds = entity.visualBounds(relativeTo: nil)
    let size = bounds.extents
    
    // Create dimension labels
    let width = MeasurementManager.shared.formatDistance(size.x)
    let height = MeasurementManager.shared.formatDistance(size.y)
    let depth = MeasurementManager.shared.formatDistance(size.z)
    
    let dimensionText = "W: \(width) × H: \(height) × D: \(depth)"
    let labelEntity = measurementVisualizer.createLabel(text: dimensionText, at: bounds.center + SIMD3(0, size.y/2 + 0.1, 0))
    arView.scene.addAnchor(labelEntity)
    
    print("📐 Object dimensions: \(dimensionText)")
}

// MARK: - Live Measurement Line (while dragging)

override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesMoved(touches, with: event)
    
    guard measurementMode == .pointToPoint,
          let firstPoint = firstMeasurementPoint,
          let touch = touches.first else {
        return
    }
    
    let location = touch.location(in: arView)
    
    guard let raycastResult = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .any).first else {
        return
    }
    
    let currentPosition = SIMD3<Float>(
        raycastResult.worldTransform.columns.3.x,
        raycastResult.worldTransform.columns.3.y,
        raycastResult.worldTransform.columns.3.z
    )
    
    // Update or create live line
    if let liveLine = liveMeasurementLine {
        liveLine.removeFromParent()
    }
    
    let lineEntity = measurementVisualizer.createLine(from: firstPoint, to: currentPosition)
    arView.scene.addAnchor(lineEntity)
    liveMeasurementLine = lineEntity
    
    // Update live distance label
    let distance = simd_distance(firstPoint, currentPosition)
    let labelText = measurementManager.formatDistance(distance)
    print("📏 Live measurement: \(labelText)")
}

private func removeLiveMeasurementLine() {
    liveMeasurementLine?.removeFromParent()
    liveMeasurementLine = nil
}

// MARK: - Notification Observers

private func observeMeasurementNotifications() {
    NotificationCenter.default.addObserver(self, selector: #selector(handleMeasurementsCleared), name: .measurementsCleared, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleMeasurementRemoved(_:)), name: .measurementRemoved, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleUnitChanged), name: .measurementUnitChanged, object: nil)
}

@objc private func handleMeasurementsCleared() {
    // Remove all measurement entities from scene
    for (_, entities) in measurementEntities {
        entities.forEach { $0.removeFromParent() }
    }
    measurementEntities.removeAll()
    
    // Remove bounding boxes
    arView.scene.anchors.forEach { anchor in
        if let entity = anchor as? ModelEntity, entity.name == "boundingBox" {
            entity.removeFromParent()
        }
    }
    
    print("🗑️ All measurements cleared")
}

@objc private func handleMeasurementRemoved(_ notification: Notification) {
    guard let id = notification.object as? UUID else { return }
    
    // Remove entities for this measurement
    measurementEntities[id]?.forEach { $0.removeFromParent() }
    measurementEntities.removeValue(forKey: id)
    
    print("🗑️ Measurement removed: \(id)")
}

@objc private func handleUnitChanged() {
    // Refresh all measurement labels
    for (id, entities) in measurementEntities {
        guard let measurement = measurementManager.measurements.first(where: { $0.id == id }) else { continue }
        
        // Find and update label entity
        if let labelEntity = entities.first(where: { $0.name == "measurementLabel" }) {
            labelEntity.removeFromParent()
            
            let midpoint = (measurement.startPoint + measurement.endPoint) / 2
            let newLabelText = measurementManager.formatDistance(measurement.distance)
            let newLabel = measurementVisualizer.createLabel(text: newLabelText, at: midpoint)
            arView.scene.addAnchor(newLabel)
            
            // Update stored entity
            if let index = entities.firstIndex(where: { $0.name == "measurementLabel" }) {
                measurementEntities[id]?[index] = newLabel
            }
        }
    }
}
```

---

## 6. ARKit Implementation (Alternative)

If not using RealityKit, use ARKit with SceneKit for measurement visualization:

**File**: `Envision/Managers/ARMeasurementHelper.swift`

```swift
import ARKit
import SceneKit

class ARMeasurementHelper {
    
    func createLineNode(from start: SCNVector3, to end: SCNVector3) -> SCNNode {
        let lineGeometry = SCNCylinder(radius: 0.002, height: CGFloat(distance(start, end)))
        lineGeometry.firstMaterial?.diffuse.contents = UIColor.systemBlue
        
        let lineNode = SCNNode(geometry: lineGeometry)
        lineNode.position = midpoint(start, end)
        
        // Rotate to align with direction
        lineNode.look(at: end, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        
        return lineNode
    }
    
    func createTextNode(text: String, at position: SCNVector3) -> SCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 1.0)
        textGeometry.font = UIFont.systemFont(ofSize: 10)
        textGeometry.firstMaterial?.diffuse.contents = UIColor.white
        
        let textNode = SCNNode(geometry: textGeometry)
        textNode.position = position
        textNode.scale = SCNVector3(0.005, 0.005, 0.005)
        
        // Billboard constraint (always face camera)
        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = [.Y]
        textNode.constraints = [constraint]
        
        return textNode
    }
    
    private func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    private func midpoint(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
        return SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
    }
}
```

---

## 7. Measurement Precision

### 7.1 Accuracy Factors

**LiDAR-based measurements** (iPhone 12 Pro+):
- Typical accuracy: ±1-2cm at 5m distance
- Best case: ±0.5cm at 1m distance

**Visual SLAM** (non-LiDAR devices):
- Typical accuracy: ±5-10cm
- Depends on lighting, texture, movement

### 7.2 Improve Accuracy

```swift
// Use LiDAR when available
func performHighAccuracyRaycast(from point: CGPoint) -> SIMD3<Float>? {
    // Prefer LiDAR depth data
    if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
        // Use scene reconstruction raycast
        if let result = arView.raycast(from: point, allowing: .estimatedPlane, alignment: .any).first {
            return SIMD3<Float>(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
        }
    }
    
    // Fallback to visual SLAM
    if let result = arView.hitTest(point, types: [.featurePoint, .estimatedHorizontalPlane]).first {
        return SIMD3<Float>(
            result.worldTransform.columns.3.x,
            result.worldTransform.columns.3.y,
            result.worldTransform.columns.3.z
        )
    }
    
    return nil
}
```

### 7.3 Confidence Indicators

```swift
func getMeasurementConfidence(measurement: Measurement) -> String {
    let distance = measurement.distance
    
    if distance < 1.0 {
        return "High confidence (±0.5cm)"
    } else if distance < 5.0 {
        return "Medium confidence (±2cm)"
    } else {
        return "Low confidence (±5cm)"
    }
}
```

---

## 8. Code Implementation

### 8.1 Create MeasurementControlPanel (UI)

**File**: `Envision/Components/MeasurementControlPanel.swift`

```swift
import UIKit

protocol MeasurementControlPanelDelegate: AnyObject {
    func didTapMeasureButton()
    func didTapDimensionsButton()
    func didTapInfoButton()
    func didTapClearAllButton()
    func didTapToggleUnits()
    func didTapExportButton()
}

final class MeasurementControlPanel: UIView {
    
    weak var delegate: MeasurementControlPanelDelegate?
    
    // MARK: - UI Elements
    
    private let stackView = UIStackView()
    private let measureButton = UIButton(type: .system)
    private let dimensionsButton = UIButton(type: .system)
    private let infoButton = UIButton(type: .system)
    private let clearAllButton = UIButton(type: .system)
    private let toggleUnitsButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        
        // Stack view
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        
        // Top row
        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.spacing = 8
        topRow.distribution = .fillEqually
        
        configureButton(measureButton, title: "Measure", icon: "ruler", action: #selector(measureTapped))
        configureButton(dimensionsButton, title: "Dimensions", icon: "square.3.layers.3d", action: #selector(dimensionsTapped))
        configureButton(infoButton, title: "Info", icon: "info.circle", action: #selector(infoTapped))
        
        topRow.addArrangedSubview(measureButton)
        topRow.addArrangedSubview(dimensionsButton)
        topRow.addArrangedSubview(infoButton)
        
        // Bottom row
        let bottomRow = UIStackView()
        bottomRow.axis = .horizontal
        bottomRow.spacing = 8
        bottomRow.distribution = .fillEqually
        
        configureButton(clearAllButton, title: "Clear All", icon: "trash", action: #selector(clearAllTapped))
        configureButton(toggleUnitsButton, title: "m ↔ ft", icon: "arrow.left.arrow.right", action: #selector(toggleUnitsTapped))
        configureButton(exportButton, title: "Export", icon: "square.and.arrow.up", action: #selector(exportTapped))
        
        bottomRow.addArrangedSubview(clearAllButton)
        bottomRow.addArrangedSubview(toggleUnitsButton)
        bottomRow.addArrangedSubview(exportButton)
        
        stackView.addArrangedSubview(topRow)
        stackView.addArrangedSubview(bottomRow)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    private func configureButton(_ button: UIButton, title: String, icon: String, action: Selector) {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.image = UIImage(systemName: icon)
        config.imagePlacement = .top
        config.imagePadding = 4
        config.title = title
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 12, weight: .medium)
            return outgoing
        }
        
        button.configuration = config
        button.addTarget(self, action: action, for: .touchUpInside)
    }
    
    // MARK: - Actions
    
    @objc private func measureTapped() {
        delegate?.didTapMeasureButton()
        highlightButton(measureButton)
    }
    
    @objc private func dimensionsTapped() {
        delegate?.didTapDimensionsButton()
        highlightButton(dimensionsButton)
    }
    
    @objc private func infoTapped() {
        delegate?.didTapInfoButton()
    }
    
    @objc private func clearAllTapped() {
        delegate?.didTapClearAllButton()
    }
    
    @objc private func toggleUnitsTapped() {
        delegate?.didTapToggleUnits()
        
        // Update button label
        let currentUnit = MeasurementManager.shared.currentUnit
        let newTitle = currentUnit == .metric ? "ft ↔ m" : "m ↔ ft"
        toggleUnitsButton.configuration?.title = newTitle
    }
    
    @objc private func exportTapped() {
        delegate?.didTapExportButton()
    }
    
    private func highlightButton(_ button: UIButton) {
        // Visual feedback for active measurement mode
        UIView.animate(withDuration: 0.2) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                button.transform = .identity
            }
        }
    }
}
```

### 8.2 Implement Delegate in RoomViewerViewController

```swift
extension RoomViewerViewController: MeasurementControlPanelDelegate {
    
    func didTapMeasureButton() {
        measurementMode = .pointToPoint
        measurementManager.activateMeasurementMode()
        print("📏 Measurement mode activated")
        
        // Show instruction overlay
        showMeasurementInstruction("Tap two points to measure distance")
    }
    
    func didTapDimensionsButton() {
        measurementMode = .objectDimensions
        measurementManager.activateMeasurementMode()
        print("📐 Object dimensions mode activated")
        
        showMeasurementInstruction("Tap on furniture to see dimensions")
    }
    
    func didTapInfoButton() {
        measurementMode = .inactive
        measurementManager.deactivateMeasurementMode()
        
        // Show room info panel
        showRoomInfoPanel()
    }
    
    func didTapClearAllButton() {
        let alert = UIAlertController(title: "Clear All Measurements", message: "This will remove all measurement lines and labels.", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            MeasurementManager.shared.clearAllMeasurements()
        })
        
        present(alert, animated: true)
    }
    
    func didTapToggleUnits() {
        let currentUnit = MeasurementManager.shared.currentUnit
        MeasurementManager.shared.currentUnit = (currentUnit == .metric) ? .imperial : .metric
        
        print("🔄 Units toggled to: \(MeasurementManager.shared.currentUnit)")
    }
    
    func didTapExportButton() {
        let text = MeasurementManager.shared.exportMeasurementsAsText()
        
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activityVC, animated: true)
    }
    
    private func showMeasurementInstruction(_ text: String) {
        // Show temporary toast/banner with instruction
        let label = UILabel()
        label.text = text
        label.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.9)
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            label.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.alpha = 0
        
        UIView.animate(withDuration: 0.3) {
            label.alpha = 1
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0) {
                label.alpha = 0
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }
    
    private func showRoomInfoPanel() {
        // Show panel with room dimensions from metadata
        guard let roomMetadata = currentRoomMetadata else {
            print("⚠️ No room metadata available")
            return
        }
        
        let alert = UIAlertController(title: roomName, message: nil, preferredStyle: .alert)
        
        var infoText = ""
        
        if let dimensions = roomMetadata.dimensions {
            if let width = dimensions["width"] {
                infoText += "Width: \(MeasurementManager.shared.formatDistance(Float(width)))\n"
            }
            if let length = dimensions["length"] {
                infoText += "Length: \(MeasurementManager.shared.formatDistance(Float(length)))\n"
            }
            if let height = dimensions["height"] {
                infoText += "Height: \(MeasurementManager.shared.formatDistance(Float(height)))\n"
            }
            
            // Calculate area
            if let width = dimensions["width"], let length = dimensions["length"] {
                let area = Float(width * length)
                infoText += "Floor Area: \(MeasurementManager.shared.formatArea(area))"
            }
        } else {
            infoText = "No dimensions available for this room."
        }
        
        alert.message = infoText
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
}
```

---

## 9. Testing Plan

### 9.1 Unit Tests

```swift
import XCTest
@testable import Envision

class MeasurementTests: XCTestCase {
    
    func testDistanceCalculation() {
        let start = SIMD3<Float>(0, 0, 0)
        let end = SIMD3<Float>(1, 0, 0)
        
        let measurement = Measurement(type: .pointToPoint, startPoint: start, endPoint: end)
        
        XCTAssertEqual(measurement.distance, 1.0, accuracy: 0.001)
    }
    
    func testUnitConversion() {
        let manager = MeasurementManager.shared
        
        // Test metric
        manager.currentUnit = .metric
        XCTAssertEqual(manager.formatDistance(1.5), "1.50 m")
        XCTAssertEqual(manager.formatDistance(0.75), "75 cm")
        
        // Test imperial
        manager.currentUnit = .imperial
        let result = manager.formatDistance(1.0) // 1m = 3.28 feet = 3' 3.4"
        XCTAssertTrue(result.contains("3'"))
    }
    
    func testAreaCalculation() {
        let manager = MeasurementManager.shared
        
        manager.currentUnit = .metric
        XCTAssertEqual(manager.formatArea(20.0), "20.00 m²")
        
        manager.currentUnit = .imperial
        let result = manager.formatArea(20.0) // 20 m² ≈ 215 ft²
        XCTAssertTrue(result.contains("ft²"))
    }
}
```

### 9.2 Integration Tests

**Test Scenarios**:
1. Create point-to-point measurement → Verify line + label appear
2. Toggle units → Verify labels update
3. Clear all → Verify all entities removed
4. Measure object dimensions → Verify bounding box shows
5. Export measurements → Verify text contains all measurements

### 9.3 Manual Testing Checklist

- [ ] Place first point → Point indicator appears
- [ ] Drag to second point → Live line follows finger
- [ ] Release → Line + label persist
- [ ] Create multiple measurements → All visible simultaneously
- [ ] Toggle m ↔ ft → Labels update instantly
- [ ] Clear all → All measurements disappear
- [ ] Tap furniture → Bounding box shows
- [ ] Export → Share sheet appears with text
- [ ] Rotate view → Labels remain visible (billboarding works)
- [ ] Switch rooms → Old measurements don't carry over

---

## 10. Enhancement Ideas

### 10.1 Advanced Features

**1. Snap to Grid**:
```swift
func snapToGrid(_ position: SIMD3<Float>, gridSize: Float = 0.1) -> SIMD3<Float> {
    return SIMD3<Float>(
        round(position.x / gridSize) * gridSize,
        round(position.y / gridSize) * gridSize,
        round(position.z / gridSize) * gridSize
    )
}
```

**2. Angle Measurement**:
```swift
struct AngleMeasurement {
    let point1: SIMD3<Float>
    let vertex: SIMD3<Float>
    let point2: SIMD3<Float>
    
    var angle: Float {
        let v1 = point1 - vertex
        let v2 = point2 - vertex
        let dot = simd_dot(simd_normalize(v1), simd_normalize(v2))
        return acos(dot) * (180.0 / .pi) // Degrees
    }
}
```

**3. Area Measurement** (polygon):
```swift
func calculateArea(points: [SIMD3<Float>]) -> Float {
    // Shoelace formula for polygon area
    var area: Float = 0
    for i in 0..<points.count {
        let j = (i + 1) % points.count
        area += points[i].x * points[j].z
        area -= points[j].x * points[i].z
    }
    return abs(area) / 2.0
}
```

**4. Volume Measurement** (bounding box):
```swift
func calculateVolume(entity: ModelEntity) -> Float {
    let bounds = entity.visualBounds(relativeTo: nil)
    let size = bounds.extents
    return size.x * size.y * size.z
}
```

**5. Persistent Measurements** (save to room metadata):
```swift
extension RoomMetadata {
    var measurements: [Measurement]?
}

// Save
roomMetadata.measurements = MeasurementManager.shared.measurements

// Load
if let savedMeasurements = roomMetadata.measurements {
    savedMeasurements.forEach { recreateMeasurementVisuals($0) }
}
```

### 10.2 UI Enhancements

**1. Measurement History Panel**:
```
┌────────────────────────────┐
│ Measurements (3)           │
│ ────────────────────────   │
│ 1. Distance: 2.45 m        │
│ 2. Chair width: 0.65 m     │
│ 3. Table to wall: 1.20 m   │
└────────────────────────────┘
```

**2. Visual Feedback**:
- Haptic feedback on tap (UIImpactFeedbackGenerator)
- Sound effect on measurement complete
- Pulse animation for point indicators

**3. Accessibility**:
- VoiceOver support for measurements
- High contrast mode for lines/labels
- Dynamic Type for labels

### 10.3 Performance Optimization

**1. Entity Pooling**:
```swift
class MeasurementEntityPool {
    private var linePool: [ModelEntity] = []
    private var labelPool: [ModelEntity] = []
    
    func getLine() -> ModelEntity {
        return linePool.popLast() ?? createNewLine()
    }
    
    func returnLine(_ entity: ModelEntity) {
        entity.isEnabled = false
        linePool.append(entity)
    }
}
```

**2. LOD (Level of Detail)**:
```swift
func updateMeasurementVisuals(cameraPosition: SIMD3<Float>) {
    for (id, entities) in measurementEntities {
        let distance = simd_distance(cameraPosition, entities[0].position)
        
        if distance > 10.0 {
            // Far away - hide labels, show simplified lines
            entities.forEach { $0.isEnabled = false }
        } else {
            // Close - show full detail
            entities.forEach { $0.isEnabled = true }
        }
    }
}
```

---

## Appendix: Quick Start Guide

### For Developers

**Step 1**: Copy files to project
- `MeasurementManager.swift` → `Envision/Managers/`
- `MeasurementVisualizer.swift` → `Envision/Managers/`
- `MeasurementControlPanel.swift` → `Envision/Components/`

**Step 2**: Update `RoomViewerViewController.swift`
- Add properties + setup methods
- Implement delegate
- Add gesture handlers

**Step 3**: Test
- Build and run
- Navigate to room viewer
- Tap "Measure" → Tap two points
- Verify line + label appear

**Step 4**: Customize
- Adjust colors in visualizer
- Change label font size
- Add more measurement types

---

**Document Version**: 1.0  
**Last Updated**: January 21, 2026  
**Estimated Implementation Time**: 3-5 days  
**Priority**: Medium-High  

---

*End of AR Measurement Tool Implementation Plan*
