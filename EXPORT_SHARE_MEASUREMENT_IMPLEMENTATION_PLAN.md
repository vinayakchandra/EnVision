# EnVision - Export/Share & Measurement Features
## Comprehensive Implementation Documentation

**Document Version:** 1.1  
**Last Updated:** February 7, 2026  
**Status:** Implementation Ready

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Current Screen Layout](#2-current-screen-layout)
3. [Feature 1: Export/Share Room Designs](#3-feature-1-exportshare-room-designs)
4. [Feature 2: AR Measurement Display for Furniture](#4-feature-2-ar-measurement-display-for-furniture)
5. [Feature 3: Room Model Review with Multi-Furniture Measurements](#5-feature-3-room-model-review-with-multi-furniture-measurements)
6. [Technical Architecture](#6-technical-architecture)
7. [UI/UX Design Specifications](#7-uiux-design-specifications)
8. [Implementation Timeline](#8-implementation-timeline)
9. [Testing Strategy](#9-testing-strategy)
10. [Appendix: Code Templates](#10-appendix-code-templates)

---

## 1. Executive Summary

### 1.1 Project Overview

EnVision is an iOS AR furniture visualization app that enables users to:
- Scan rooms using RoomPlan
- Place and visualize furniture in 3D
- Customize room colors and elements
- Create furniture models via Object Capture

This document outlines the implementation plan for three interconnected features:
1. **Export/Share** - Export room designs as images, 3D files, or PDF reports
2. **AR Measurement** - Display real-time measurements for furniture in AR view
3. **Multi-Furniture Measurement** - Measure distances between multiple furniture items during room review

### 1.2 Goals & Objectives

| Goal | Description | Success Metric |
|------|-------------|----------------|
| **User Sharing** | Enable users to share room designs | 90% export success rate |
| **Precision** | Accurate measurements in AR | ±2cm accuracy |
| **Usability** | Intuitive measurement tools | <3 taps to measure |
| **Performance** | Smooth AR experience | 60 FPS maintained |

### 1.3 Existing Codebase Analysis

**Current Architecture:**
```
Envision/
├── Components/           # Reusable UI (CustomTextField, PrimaryButton)
├── Extensions/           # Helpers (AppColors, AppFonts, SaveManager)
├── Managers/             # Business logic (RoomColorManager, TourManager)
├── Screens/
│   └── MainTabs/
│       ├── Rooms/
│       │   └── furniture+room/
│       │       ├── RoomViewerViewController.swift    # Parent container
│       │       ├── RoomVisualizeVC.swift            # 3D visualization
│       │       ├── RoomEditVC.swift                 # Color editing
│       │       ├── FurnitureControlPanel.swift      # Movement controls
│       │       └── FurniturePicker.swift            # Model selection
│       ├── furniture/    # Furniture management
│       └── profile/      # User settings
└── Tips/                 # Onboarding tips
```

**Key Existing Components:**
- `RoomVisualizeVC` - Already has basic measurement mode (`isMeasuringMode`)
- `FurnitureControlPanel` - Joystick-based furniture positioning
- `SaveManager` - File management and thumbnail generation
- `RoomColorManager` - Persistent color settings

---

## 2. Current Screen Layout

### 2.1 RoomVisualizeVC - Current UI Structure

The Visualize screen is the main room viewing interface with the following layout:

```
┌─────────────────────────────────────────────────────────────────┐
│                        NAVIGATION BAR                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  < Back        Visualize              [📏] [➕]         │   │
│  │                                       ruler  add        │   │
│  │                                       blue   green      │   │
│  └─────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                                                                 │
│                        AR VIEW                                  │
│                    (Full Screen)                                │
│                                                                 │
│                   ┌───────────────┐                            │
│                   │               │                            │
│                   │   3D Room     │                            │
│                   │   Model       │                            │
│                   │               │                            │
│                   └───────────────┘                            │
│                                                                 │
│                                                                 │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐   │
│  │            FURNITURE CONTROL PANEL                       │   │
│  │   (Appears when furniture is selected)                   │   │
│  │                                                          │   │
│  │   [Height Slider]  [Rotation Slider]  [Joystick]        │   │
│  │   [Scale +/-]                                            │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Current Navigation Bar Buttons

**Current Code (`setupNavigation()`):**
```swift
navigationItem.rightBarButtonItems = [addButton, rulerButton]
// Order: [0] addButton (rightmost), [1] rulerButton (second)
```

| Position | Button | Icon | Color | Action |
|----------|--------|------|-------|--------|
| Rightmost | Add Furniture | `plus` | Green | Opens FurniturePicker |
| Second | Ruler/Measure | `ruler` | Blue (Orange when active) | Toggle measurement mode |

### 2.3 Proposed Navigation Bar with Share Button

**NEW Layout - Add Share Button:**
```
┌─────────────────────────────────────────────────────────────────┐
│  < Back        Visualize           [📏] [📤] [➕]              │
│                                    ruler share add              │
│                                    blue  blue  green            │
└─────────────────────────────────────────────────────────────────┘
```

**Updated Button Order:**
```swift
navigationItem.rightBarButtonItems = [addButton, shareButton, rulerButton]
// Order: [0] addButton (rightmost), [1] shareButton, [2] rulerButton (leftmost)
```

| Position | Button | Icon | Color | Action |
|----------|--------|------|-------|--------|
| Rightmost | Add Furniture | `plus` | Green | Opens FurniturePicker |
| Middle | Share/Export | `square.and.arrow.up` | Blue | Opens Share Options |
| Left | Ruler/Measure | `ruler` | Blue | Toggle measurement mode |

---

## 3. Feature 1: Export/Share Room Designs

### 3.1 Feature Description

Allow users to export their designed rooms in multiple formats:
- **Image (PNG/JPEG)** - High-quality screenshot of current view
- **3D Model (USDZ)** - Complete room with placed furniture

### 3.2 User Stories

| ID | As a... | I want to... | So that... |
|----|---------|--------------|------------|
| US-1.1 | User | Share a screenshot of my room | I can show friends my design |
| US-1.2 | User | Export the 3D model | I can view it on other devices |
| US-1.3 | User | Choose export quality | I can balance size vs quality |

### 3.3 UI/UX Design

#### 3.3.1 Entry Point - Share Button in Navigation Bar

**Location:** Navigation bar in `RoomVisualizeVC`, positioned between ruler and add buttons

**Implementation:**
```swift
// In RoomVisualizeVC.swift - setupNavigation()
private func setupNavigation() {
    // Ruler button (leftmost)
    let rulerButton = UIBarButtonItem(
        image: UIImage(systemName: "ruler"),
        style: .plain,
        target: self,
        action: #selector(rulerTapped)
    )
    rulerButton.tintColor = .systemBlue
    
    // NEW: Share button (middle)
    let shareButton = UIBarButtonItem(
        image: UIImage(systemName: "square.and.arrow.up"),
        style: .plain,
        target: self,
        action: #selector(shareTapped)
    )
    shareButton.tintColor = .systemBlue
    
    // Add furniture button (rightmost)
    let addButton = UIBarButtonItem(
        image: UIImage(systemName: "plus"),
        style: .plain,
        target: self,
        action: #selector(addFurnitureTapped)
    )
    addButton.tintColor = .systemGreen
    
    // Order: rightmost first in array
    navigationItem.rightBarButtonItems = [addButton, shareButton, rulerButton]
}

@objc private func shareTapped() {
    let shareVC = ShareOptionsViewController()
    shareVC.delegate = self
    shareVC.modalPresentationStyle = .overCurrentContext
    shareVC.modalTransitionStyle = .crossDissolve
    present(shareVC, animated: true)
}
```

#### 3.3.2 Share Options Bottom Sheet

When user taps share button, a bottom sheet appears:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    (Tap to dismiss)                             │
│                                                                 │
│  ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │              ━━━━ (drag handle)                         │   │
│  │                                                          │   │
│  │              Export Room Design                          │   │
│  │              ─────────────────                           │   │
│  │                                                          │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │  📷  Image                                          │ │   │
│  │  │      High-quality PNG snapshot                      │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  │                                                          │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │  📦  3D Model (USDZ)                                │ │   │
│  │  │      Room with all placed furniture                 │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  │                                                          │   │
│  │                    [ Cancel ]                            │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**Design Specifications:**
- Dimmed background: `UIColor.black.withAlphaComponent(0.4)`
- Card background: `AppColors.background` (supports dark mode)
- Card corners: 20pt radius (top corners only)
- Drag handle: 36pt width, 4pt height, rounded, `UIColor.systemGray3`
- Option buttons: 70pt height, filled style with `AppColors.accent.withAlphaComponent(0.1)`
- Icons: SF Symbols, 24pt, `AppColors.accent`
- Title: `AppFonts.semibold(18)`, centered
- Button text: `AppFonts.medium(16)` for title, `AppFonts.regular(14)` for subtitle
- Spacing: 12pt between buttons, 20pt padding

#### 3.3.3 Export Flow Diagram

```
┌──────────────────┐
│ User taps Share  │
│ button (📤)      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ ShareOptionsVC   │
│ appears          │
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌───────┐ ┌───────┐
│ Image │ │ USDZ  │
└───┬───┘ └───┬───┘
    │         │
    ▼         ▼
┌───────┐ ┌───────┐
│Capture│ │Export │
│ARView │ │Scene  │
└───┬───┘ └───┬───┘
    │         │
    └────┬────┘
         │
         ▼
┌──────────────────┐
│ Loading Indicator│
│ with progress    │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ UIActivityVC     │
│ (System Share)   │
└──────────────────┘
```

#### 3.3.4 Loading State

During export, show loading overlay:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                                                                 │
│                    ┌─────────────────────┐                     │
│                    │                     │                     │
│                    │    ⏳ Exporting...  │                     │
│                    │    ████████░░░░ 67% │                     │
│                    │                     │                     │
│                    │     [Cancel]        │                     │
│                    │                     │                     │
│                    └─────────────────────┘                     │
│                                                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 Technical Architecture

#### 3.4.1 New Files to Create

```
Managers/
    ExportManager.swift              # Core export logic

Screens/MainTabs/Rooms/furniture+room/
    Export/
        ShareOptionsViewController.swift    # Bottom sheet
        ExportLoadingView.swift             # Loading overlay
```

#### 3.4.2 ExportManager Class Design

```swift
// Managers/ExportManager.swift

import UIKit
import RealityKit
import SceneKit
import PDFKit

/// Supported export formats
enum ExportFormat {
    case image(quality: ImageQuality)
    case usdz
    case pdf
    
    enum ImageQuality {
        case standard  // 1x scale
        case high      // 2x scale
        case maximum   // 3x scale
    }
}

/// Export result containing file URL or data
enum ExportResult {
    case image(UIImage)
    case file(URL)
    case data(Data)
}

/// Export configuration options
struct ExportConfiguration {
    var includeMeasurements: Bool = true
    var includeFurnitureLabels: Bool = true
    var includeWatermark: Bool = false
    var imageQuality: ExportFormat.ImageQuality = .high
}

/// Central manager for all export operations
final class ExportManager {
    
    static let shared = ExportManager()
    private init() {}
    
    // MARK: - Public Interface
    
    /// Capture current AR view as image
    func captureSnapshot(
        from arView: ARView,
        configuration: ExportConfiguration,
        completion: @escaping (Result<UIImage, ExportError>) -> Void
    )
    
    /// Export complete scene as USDZ file
    func exportAsUSDZ(
        scene: Entity,
        fileName: String,
        completion: @escaping (Result<URL, ExportError>) -> Void
    )
    
    /// Generate PDF report with room information
    func generatePDFReport(
        roomData: RoomExportData,
        snapshot: UIImage?,
        completion: @escaping (Result<Data, ExportError>) -> Void
    )
    
    /// Present system share sheet
    func presentShareSheet(
        from viewController: UIViewController,
        items: [Any],
        sourceView: UIView?
    )
}

/// Room data for PDF export
struct RoomExportData {
    let name: String
    let dimensions: RoomDimensions
    let furniture: [FurnitureExportItem]
    let createdDate: Date
    let colorScheme: [String: UIColor]
}

struct RoomDimensions {
    let width: Float   // meters
    let length: Float  // meters
    let height: Float  // meters
    
    var formattedMetric: String {
        String(format: "%.2fm × %.2fm × %.2fm", width, length, height)
    }
    
    var formattedImperial: String {
        let wFt = width * 3.28084
        let lFt = length * 3.28084
        let hFt = height * 3.28084
        return String(format: "%.1fft × %.1fft × %.1fft", wFt, lFt, hFt)
    }
}

struct FurnitureExportItem {
    let name: String
    let position: SIMD3<Float>
    let dimensions: SIMD3<Float>
    let category: String
}
```

#### 3.4.3 Data Flow Diagram

```
┌──────────────┐     ┌───────────────────┐     ┌──────────────────┐
│ User taps    │────▶│ ShareOptionsVC    │────▶│ ExportManager    │
│ Share button │     │ presents options  │     │ processes export │
└──────────────┘     └───────────────────┘     └────────┬─────────┘
                                                        │
        ┌───────────────────────────────────────────────┼───────────┐
        │                       │                       │           │
        ▼                       ▼                       ▼           │
┌───────────────┐     ┌─────────────────┐     ┌─────────────────┐  │
│ Image Export  │     │ USDZ Export     │     │ PDF Export      │  │
│ ARView.snap() │     │ scene.write()   │     │ PDFGenerator    │  │
└───────┬───────┘     └────────┬────────┘     └────────┬────────┘  │
        │                      │                       │           │
        └──────────────────────┼───────────────────────┘           │
                               ▼                                    │
                    ┌───────────────────┐                          │
                    │ UIActivityVC      │◀─────────────────────────┘
                    │ Share Sheet       │
                    └───────────────────┘
```

### 3.5 Implementation Steps

#### Step 1: Create ExportManager (2 hours)
1. Create `Managers/ExportManager.swift`
2. Implement `captureSnapshot()` using `ARView.snapshot()`
3. Implement `exportAsUSDZ()` using `Entity.write(to:)`
4. Implement `presentShareSheet()` wrapper

#### Step 2: Create Share Options UI (3 hours)
1. Create `ShareOptionsViewController.swift` as bottom sheet
2. Implement three option buttons with icons
3. Add delegate pattern for option selection
4. Style according to `AppColors` theme

#### Step 3: Implement PDF Generator (4 hours)
1. Create `PDFReportGenerator.swift`
2. Design PDF layout with:
   - Header with room name and date
   - Room snapshot image
   - Dimensions table
   - Furniture list with positions
   - Footer with EnVision branding

#### Step 4: Integrate with RoomVisualizeVC (2 hours)
1. Add share button to navigation bar
2. Connect share flow to ExportManager
3. Handle loading states during export
4. Add success/error feedback

#### Step 5: Testing & Polish (2 hours)
1. Test all export formats
2. Verify share sheet compatibility
3. Add haptic feedback
4. Handle edge cases (no furniture, large files)

### 3.6 Error Handling

```swift
enum ExportError: LocalizedError {
    case snapshotFailed
    case usdzExportFailed(underlying: Error)
    case pdfGenerationFailed
    case insufficientStorage
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .snapshotFailed:
            return "Failed to capture room image"
        case .usdzExportFailed(let error):
            return "Export failed: \(error.localizedDescription)"
        case .pdfGenerationFailed:
            return "Could not generate PDF report"
        case .insufficientStorage:
            return "Not enough storage space"
        case .cancelled:
            return "Export cancelled"
        }
    }
}
```

---

## 4. Feature 2: AR Measurement Display for Furniture

### 3.1 Feature Description

Display real-time measurements for individual furniture items in AR view:
- **Bounding box** wireframe around selected furniture
- **Dimension labels** showing width, height, depth
- **Unit toggle** between metric (m/cm) and imperial (ft/in)

### 3.2 User Stories

| ID | As a... | I want to... | So that... |
|----|---------|--------------|------------|
| US-2.1 | User | See furniture dimensions | I know if it fits my space |
| US-2.2 | User | Toggle measurement units | I can use my preferred system |
| US-2.3 | User | Tap furniture to measure | I can check specific items |
| US-2.4 | User | See measurements clearly | Labels are readable in AR |

### 3.3 UI/UX Design

#### 3.3.1 Measurement Visualization

```
                    ┌─────────────┐
                    │  0.45m (H)  │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
       /│                  │                 /│
      / │                  │                / │
     /  │                  │               /  │
    ┌───┼──────────────────┼──────────────┐   │
    │   │      SOFA        │              │   │
    │   │                  ▼              │   │
    │   │◀────── 1.80m (W) ──────────────▶│   │
    │   └─────────────────────────────────│───┘
    │  /                                  │  /
    │ /◀─────── 0.85m (D) ───────────────▶│ /
    │/                                    │/
    └─────────────────────────────────────┘
```

**Visual Specifications:**
- **Bounding box edges:** Dashed lines, `AppColors.accent`, 2pt stroke
- **Corner markers:** Small spheres (4mm radius), `AppColors.accent`
- **Dimension labels:** Pill-shaped background, white text on accent color
- **Label font:** `AppFonts.bold(12)`
- **Label positioning:** Centered on each axis, offset 5cm from edge

#### 3.3.2 Measurement Toggle Button

Located in navigation bar, uses SF Symbol `ruler`:
- **Default state:** Blue tint, hollow icon
- **Active state:** Orange tint, filled icon (`ruler.fill`)

#### 3.3.3 Unit Selector

```
┌─────────────────────────────────┐
│  ┌───────────┬───────────┐     │
│  │  Metric   │  Imperial │     │
│  │   m/cm    │   ft/in   │     │
│  └───────────┴───────────┘     │
└─────────────────────────────────┘
```

Position: Bottom of screen, above safe area

### 3.4 Technical Architecture

#### 3.4.1 New Files to Create

```
Components/
    Measurement/
        BoundingBoxEntity.swift      # 3D bounding box wireframe
        DimensionLabelEntity.swift   # Billboard text labels
        MeasurementOverlayView.swift # 2D UI overlay

Managers/
    MeasurementManager.swift         # Measurement calculations
```

#### 3.4.2 Core Classes

```swift
// Managers/MeasurementManager.swift

import RealityKit
import Combine

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
}

/// Manages all measurement operations in AR
final class MeasurementManager: ObservableObject {
    
    static let shared = MeasurementManager()
    
    // MARK: - Published State
    @Published var isEnabled: Bool = false
    @Published var currentUnit: MeasurementUnit = .metric
    @Published var selectedEntity: ModelEntity?
    
    // MARK: - Active Measurements
    private var activeBoundingBoxes: [Entity] = []
    private var activeDimensionLabels: [Entity] = []
    
    // MARK: - Configuration
    struct Config {
        static let boundingBoxColor: UIColor = AppColors.accent
        static let labelBackgroundColor: UIColor = AppColors.accent
        static let labelTextColor: UIColor = .white
        static let edgeWidth: Float = 0.003  // 3mm
        static let cornerRadius: Float = 0.004  // 4mm
        static let labelOffset: Float = 0.05  // 5cm from edge
    }
    
    // MARK: - Public Methods
    
    /// Calculate bounding box for entity
    func getBoundingBox(for entity: ModelEntity) -> BoundingBox
    
    /// Add measurement visualization to entity
    func showMeasurements(for entity: ModelEntity, in scene: Scene)
    
    /// Remove all measurements from scene
    func clearMeasurements(from scene: Scene)
    
    /// Convert raw dimension to formatted string
    func formatDimension(_ value: Float) -> String
    
    /// Calculate distance between two points
    func distance(from: SIMD3<Float>, to: SIMD3<Float>) -> Float
}

/// Represents a 3D bounding box
struct BoundingBox {
    let min: SIMD3<Float>
    let max: SIMD3<Float>
    
    var width: Float { max.x - min.x }
    var height: Float { max.y - min.y }
    var depth: Float { max.z - min.z }
    var center: SIMD3<Float> { (min + max) / 2 }
    
    /// All 8 corners of the box
    var corners: [SIMD3<Float>] {
        [
            SIMD3(min.x, min.y, min.z),
            SIMD3(max.x, min.y, min.z),
            SIMD3(max.x, min.y, max.z),
            SIMD3(min.x, min.y, max.z),
            SIMD3(min.x, max.y, min.z),
            SIMD3(max.x, max.y, min.z),
            SIMD3(max.x, max.y, max.z),
            SIMD3(min.x, max.y, max.z)
        ]
    }
    
    /// All 12 edges as pairs of corner indices
    static let edgeIndices: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 0),  // Bottom
        (4, 5), (5, 6), (6, 7), (7, 4),  // Top
        (0, 4), (1, 5), (2, 6), (3, 7)   // Vertical
    ]
}
```

#### 3.4.3 BoundingBoxEntity Implementation

```swift
// Components/Measurement/BoundingBoxEntity.swift

import RealityKit
import UIKit

/// Creates a 3D wireframe bounding box visualization
final class BoundingBoxEntity: Entity {
    
    private var edgeEntities: [ModelEntity] = []
    private var cornerEntities: [ModelEntity] = []
    
    required init() {
        super.init()
    }
    
    convenience init(boundingBox: BoundingBox, color: UIColor = AppColors.accent) {
        self.init()
        createEdges(boundingBox: boundingBox, color: color)
        createCorners(boundingBox: boundingBox, color: color)
    }
    
    private func createEdges(boundingBox: BoundingBox, color: UIColor) {
        let corners = boundingBox.corners
        let material = SimpleMaterial(color: color, isMetallic: false)
        
        for (startIdx, endIdx) in BoundingBox.edgeIndices {
            let start = corners[startIdx]
            let end = corners[endIdx]
            let edge = createEdge(from: start, to: end, material: material)
            addChild(edge)
            edgeEntities.append(edge)
        }
    }
    
    private func createEdge(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        material: Material
    ) -> ModelEntity {
        let length = simd_distance(start, end)
        let midpoint = (start + end) / 2
        
        // Create thin box as edge
        let mesh = MeshResource.generateBox(
            size: [MeasurementManager.Config.edgeWidth,
                   MeasurementManager.Config.edgeWidth,
                   length]
        )
        
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = midpoint
        
        // Rotate to align with edge direction
        let direction = normalize(end - start)
        entity.look(at: end, from: midpoint, relativeTo: nil)
        
        return entity
    }
    
    private func createCorners(boundingBox: BoundingBox, color: UIColor) {
        let material = SimpleMaterial(color: color, isMetallic: false)
        let mesh = MeshResource.generateSphere(radius: MeasurementManager.Config.cornerRadius)
        
        for corner in boundingBox.corners {
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = corner
            addChild(entity)
            cornerEntities.append(entity)
        }
    }
}
```

#### 3.4.4 DimensionLabelEntity Implementation

```swift
// Components/Measurement/DimensionLabelEntity.swift

import RealityKit
import UIKit

/// Creates a billboard text label for dimensions
final class DimensionLabelEntity: Entity, HasModel {
    
    enum Axis {
        case width, height, depth
        
        var symbol: String {
            switch self {
            case .width: return "W"
            case .height: return "H"
            case .depth: return "D"
            }
        }
    }
    
    required init() {
        super.init()
    }
    
    convenience init(
        text: String,
        axis: Axis,
        position: SIMD3<Float>,
        backgroundColor: UIColor = AppColors.accent
    ) {
        self.init()
        
        // Create text mesh
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.03, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        let material = SimpleMaterial(
            color: .white,
            isMetallic: false
        )
        
        self.model = ModelComponent(mesh: textMesh, materials: [material])
        self.position = position
        
        // Billboard constraint - always face camera
        // Note: In RealityKit, this is achieved through orientation updates
    }
    
    /// Update label to always face camera
    func updateOrientation(cameraTransform: Transform) {
        // Calculate direction to camera
        let cameraPosition = cameraTransform.translation
        let direction = normalize(cameraPosition - self.position)
        
        // Create rotation to face camera
        self.look(at: cameraPosition, from: self.position, relativeTo: nil)
    }
}
```

### 3.5 Integration with Existing Code

#### 3.5.1 Modifications to RoomVisualizeVC.swift

The existing `RoomVisualizeVC` already has a basic measurement mode. We need to enhance it:

**Current Implementation (Lines 15-17):**
```swift
private var isMeasuringMode = false
private var measurementPoints: [SIMD3<Float>] = []
private var measurementLabel: UILabel?
```

**Enhanced Implementation:**
```swift
// Add these properties
private let measurementManager = MeasurementManager.shared
private var measurementOverlay: MeasurementOverlayView?
private var unitSelector: UISegmentedControl?

// Modify rulerTapped() to show furniture bounding boxes
@objc private func rulerTapped() {
    measurementManager.isEnabled.toggle()
    
    if measurementManager.isEnabled {
        showMeasurementUI()
        showFurnitureMeasurements()
    } else {
        hideMeasurementUI()
        measurementManager.clearMeasurements(from: arView.scene)
    }
}

private func showFurnitureMeasurements() {
    // Show measurements for all placed furniture
    for furniture in placedFurniture {
        measurementManager.showMeasurements(for: furniture, in: arView.scene)
    }
    
    // Also show room model measurements if available
    if let room = displayedModel {
        measurementManager.showMeasurements(for: room, in: arView.scene)
    }
}
```

### 3.6 Implementation Steps

#### Step 1: Create MeasurementManager (3 hours)
1. Create `Managers/MeasurementManager.swift`
2. Implement bounding box calculation
3. Implement distance calculations
4. Add unit conversion logic

#### Step 2: Create Visualization Entities (4 hours)
1. Create `BoundingBoxEntity.swift`
2. Create `DimensionLabelEntity.swift`
3. Test rendering in isolation

#### Step 3: Create UI Overlay (2 hours)
1. Create `MeasurementOverlayView.swift` with unit selector
2. Add toggle feedback animations
3. Style according to design spec

#### Step 4: Integrate with RoomVisualizeVC (3 hours)
1. Connect MeasurementManager to existing ruler button
2. Add furniture tap detection for individual measurements
3. Update measurements when camera moves (for billboard labels)

#### Step 5: Testing & Calibration (2 hours)
1. Test measurement accuracy with known dimensions
2. Adjust scale factors if needed
3. Test with various furniture sizes

---

## 5. Feature 3: Room Model Review with Multi-Furniture Measurements

### 4.1 Feature Description

Comprehensive measurement system during room review that supports:
- **Distance between furniture** - Measure spacing between items
- **Furniture to wall distance** - Clearance measurements
- **Multiple selection** - Compare several items at once
- **Collision detection** - Warn when furniture overlaps

### 4.2 User Stories

| ID | As a... | I want to... | So that... |
|----|---------|--------------|------------|
| US-3.1 | User | Measure distance between furniture | I can ensure proper spacing |
| US-3.2 | User | See furniture-to-wall clearance | I know if items fit |
| US-3.3 | User | Select multiple items | I can compare dimensions |
| US-3.4 | User | Get overlap warnings | I avoid collision placement |

### 4.3 UI/UX Design

#### 4.3.1 Measurement Toolbar

Position: Bottom of screen, floating above safe area

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ┌────┐  ┌────┐  ┌────┐  ┌────┐  ┌─────────────────┐          │
│  │ 📏 │  │ 📦 │  │ ↔️ │  │ ⊞ │  │  m   │   ft    │          │
│  └────┘  └────┘  └────┘  └────┘  └─────────────────┘          │
│   All    Single  Distance Room    Unit Selector               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Icons (SF Symbols):
- All: ruler (show all measurements)
- Single: cube (measure one item)
- Distance: arrow.left.and.right (measure between items)
- Room: square.dashed (room dimensions)
```

**Design Specifications:**
- Toolbar background: `AppColors.background` with 12pt corner radius
- Shadow: Black 10% opacity, 8pt blur, 4pt y-offset
- Button size: 44x44pt (Apple HIG minimum)
- Active state: `AppColors.accent` tint
- Inactive state: `secondaryLabel` tint

#### 4.3.2 Distance Measurement Line

```
         ┌─────────────────────┐
         │    2.35m (7.7ft)    │
         └──────────┬──────────┘
                    │
    ┌───────────────●───────────────●───────────────┐
    │               ·               ·               │
    │    SOFA       ·───────────────·    TABLE     │
    │               ·               ·               │
    └───────────────●───────────────●───────────────┘
                    │
              Dashed line connecting
              closest points
```

**Visual Specifications:**
- Line style: Dashed, 4pt dash, 2pt gap
- Line color: `AppColors.accent`
- Label: Centered on line, pill background
- End markers: Circles, 6mm diameter

#### 4.3.3 Multi-Selection Mode

When multiple furniture items are selected:

```
┌─────────────────────────────────────────────────────────────────┐
│  Selected: 3 items                                    [Clear]   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Item              W        H        D                  │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  Sofa              1.80m    0.85m    0.90m             │   │
│  │  Coffee Table      1.20m    0.45m    0.60m             │   │
│  │  Armchair          0.95m    1.00m    0.90m             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Distances:                                                     │
│  • Sofa ↔ Coffee Table: 0.45m                                  │
│  • Sofa ↔ Armchair: 1.20m                                      │
│  • Coffee Table ↔ Armchair: 0.80m                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 4.3.4 Collision Warning

When furniture items overlap:

```
┌─────────────────────────────────────────────────────────────────┐
│  ⚠️  Warning: Furniture Overlap Detected                        │
│                                                                 │
│  The following items are overlapping:                           │
│  • Sofa and Coffee Table                                        │
│                                                                 │
│  Overlap volume: 0.12 m³                                        │
│                                                                 │
│          [ Ignore ]        [ Auto-Adjust ]                      │
└─────────────────────────────────────────────────────────────────┘
```

### 4.4 Technical Architecture

#### 4.4.1 New Files to Create

```
Screens/MainTabs/Rooms/furniture+room/
    Measurement/
        MeasurementToolbar.swift         # Bottom toolbar UI
        DistanceLineEntity.swift         # 3D distance visualization
        FurnitureMeasurementPanel.swift  # Info panel for selected items
        CollisionDetector.swift          # Overlap detection

Managers/
    FurniturePlacementManager.swift      # Furniture state management
```

#### 4.4.2 FurniturePlacementManager

```swift
// Managers/FurniturePlacementManager.swift

import RealityKit
import Combine

/// Represents a placed furniture item with metadata
struct PlacedFurniture: Identifiable {
    let id: UUID
    let name: String
    let entity: ModelEntity
    let originalURL: URL
    var isSelected: Bool = false
    
    var boundingBox: BoundingBox {
        let bounds = entity.visualBounds(relativeTo: nil)
        return BoundingBox(min: bounds.min, max: bounds.max)
    }
    
    var dimensions: SIMD3<Float> {
        let box = boundingBox
        return SIMD3(box.width, box.height, box.depth)
    }
    
    var worldPosition: SIMD3<Float> {
        entity.position(relativeTo: nil)
    }
}

/// Manages furniture placement and measurements
final class FurniturePlacementManager: ObservableObject {
    
    // MARK: - State
    @Published private(set) var placedFurniture: [PlacedFurniture] = []
    @Published private(set) var selectedFurniture: [PlacedFurniture] = []
    @Published private(set) var collisions: [(PlacedFurniture, PlacedFurniture)] = []
    
    // MARK: - Visualization
    private var distanceLines: [DistanceLineEntity] = []
    private var boundingBoxes: [BoundingBoxEntity] = []
    private weak var scene: Scene?
    
    // MARK: - Configuration
    var currentUnit: MeasurementUnit = .metric
    
    // MARK: - Initialization
    init(scene: Scene) {
        self.scene = scene
    }
    
    // MARK: - Furniture Management
    
    func addFurniture(_ entity: ModelEntity, name: String, url: URL) -> UUID {
        let id = UUID()
        let furniture = PlacedFurniture(
            id: id,
            name: name,
            entity: entity,
            originalURL: url
        )
        placedFurniture.append(furniture)
        checkCollisions()
        return id
    }
    
    func removeFurniture(id: UUID) {
        if let index = placedFurniture.firstIndex(where: { $0.id == id }) {
            placedFurniture[index].entity.removeFromParent()
            placedFurniture.remove(at: index)
            selectedFurniture.removeAll { $0.id == id }
            checkCollisions()
        }
    }
    
    // MARK: - Selection
    
    func selectFurniture(id: UUID) {
        guard let index = placedFurniture.firstIndex(where: { $0.id == id }) else { return }
        placedFurniture[index].isSelected = true
        
        if !selectedFurniture.contains(where: { $0.id == id }) {
            selectedFurniture.append(placedFurniture[index])
        }
        
        updateVisualizations()
    }
    
    func deselectFurniture(id: UUID) {
        if let index = placedFurniture.firstIndex(where: { $0.id == id }) {
            placedFurniture[index].isSelected = false
        }
        selectedFurniture.removeAll { $0.id == id }
        updateVisualizations()
    }
    
    func clearSelection() {
        for i in 0..<placedFurniture.count {
            placedFurniture[i].isSelected = false
        }
        selectedFurniture.removeAll()
        updateVisualizations()
    }
    
    // MARK: - Measurements
    
    func showAllMeasurements() {
        clearVisualizations()
        
        for furniture in placedFurniture {
            let boundingBox = BoundingBoxEntity(boundingBox: furniture.boundingBox)
            boundingBox.position = furniture.worldPosition
            scene?.anchors.first?.addChild(boundingBox)
            boundingBoxes.append(boundingBox)
        }
        
        showAllDistances()
    }
    
    func showMeasurements(for furniture: PlacedFurniture) {
        clearVisualizations()
        
        let boundingBox = BoundingBoxEntity(boundingBox: furniture.boundingBox)
        boundingBox.position = furniture.worldPosition
        scene?.anchors.first?.addChild(boundingBox)
        boundingBoxes.append(boundingBox)
    }
    
    func showDistanceBetween(_ first: PlacedFurniture, _ second: PlacedFurniture) {
        let line = DistanceLineEntity(
            from: first.worldPosition,
            to: second.worldPosition,
            unit: currentUnit
        )
        scene?.anchors.first?.addChild(line)
        distanceLines.append(line)
    }
    
    func showAllDistances() {
        guard placedFurniture.count > 1 else { return }
        
        for i in 0..<placedFurniture.count {
            for j in (i+1)..<placedFurniture.count {
                showDistanceBetween(placedFurniture[i], placedFurniture[j])
            }
        }
    }
    
    // MARK: - Collision Detection
    
    func checkCollisions() {
        collisions.removeAll()
        
        for i in 0..<placedFurniture.count {
            for j in (i+1)..<placedFurniture.count {
                if boundingBoxesIntersect(placedFurniture[i], placedFurniture[j]) {
                    collisions.append((placedFurniture[i], placedFurniture[j]))
                }
            }
        }
    }
    
    private func boundingBoxesIntersect(
        _ a: PlacedFurniture,
        _ b: PlacedFurniture
    ) -> Bool {
        let boxA = a.boundingBox
        let boxB = b.boundingBox
        let posA = a.worldPosition
        let posB = b.worldPosition
        
        // Transform bounding boxes to world space
        let minA = posA + boxA.min
        let maxA = posA + boxA.max
        let minB = posB + boxB.min
        let maxB = posB + boxB.max
        
        // AABB intersection test
        return !(maxA.x < minB.x || minA.x > maxB.x ||
                 maxA.y < minB.y || minA.y > maxB.y ||
                 maxA.z < minB.z || minA.z > maxB.z)
    }
    
    // MARK: - Visualization Management
    
    func clearVisualizations() {
        distanceLines.forEach { $0.removeFromParent() }
        distanceLines.removeAll()
        
        boundingBoxes.forEach { $0.removeFromParent() }
        boundingBoxes.removeAll()
    }
    
    private func updateVisualizations() {
        clearVisualizations()
        
        // Show bounding boxes for selected items
        for furniture in selectedFurniture {
            let box = BoundingBoxEntity(boundingBox: furniture.boundingBox)
            box.position = furniture.worldPosition
            scene?.anchors.first?.addChild(box)
            boundingBoxes.append(box)
        }
        
        // Show distances between selected items
        if selectedFurniture.count > 1 {
            for i in 0..<selectedFurniture.count {
                for j in (i+1)..<selectedFurniture.count {
                    showDistanceBetween(selectedFurniture[i], selectedFurniture[j])
                }
            }
        }
    }
    
    // MARK: - Unit Conversion
    
    func updateUnit(_ unit: MeasurementUnit) {
        currentUnit = unit
        
        // Refresh all distance lines with new unit
        for line in distanceLines {
            line.updateLabel(unit: unit)
        }
    }
}
```

#### 4.4.3 MeasurementToolbar Implementation

```swift
// Screens/MainTabs/Rooms/furniture+room/Measurement/MeasurementToolbar.swift

import UIKit

protocol MeasurementToolbarDelegate: AnyObject {
    func toolbar(_ toolbar: MeasurementToolbar, didSelectMode mode: MeasurementToolbar.Mode)
    func toolbar(_ toolbar: MeasurementToolbar, didChangeUnit unit: MeasurementUnit)
    func toolbarDidToggle(_ toolbar: MeasurementToolbar, isEnabled: Bool)
}

final class MeasurementToolbar: UIView {
    
    // MARK: - Types
    
    enum Mode: Int, CaseIterable {
        case all = 0
        case single
        case distance
        case room
        
        var icon: String {
            switch self {
            case .all: return "ruler"
            case .single: return "cube"
            case .distance: return "arrow.left.and.right"
            case .room: return "square.dashed"
            }
        }
        
        var title: String {
            switch self {
            case .all: return "All"
            case .single: return "Single"
            case .distance: return "Distance"
            case .room: return "Room"
            }
        }
    }
    
    // MARK: - Properties
    
    weak var delegate: MeasurementToolbarDelegate?
    
    private(set) var currentMode: Mode = .single
    private(set) var currentUnit: MeasurementUnit = .metric
    private(set) var isEnabled: Bool = false
    
    // MARK: - UI Elements
    
    private lazy var containerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var modeButtons: [UIButton] = Mode.allCases.map { mode in
        createModeButton(for: mode)
    }
    
    private lazy var unitSegment: UISegmentedControl = {
        let segment = UISegmentedControl(items: ["m", "ft"])
        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(unitChanged), for: .valueChanged)
        segment.translatesAutoresizingMaskIntoConstraints = false
        return segment
    }()
    
    private lazy var toggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "power"), for: .normal)
        button.tintColor = .secondaryLabel
        button.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = AppColors.background
        layer.cornerRadius = 12
        
        // Shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)
        
        addSubview(containerStack)
        
        // Add mode buttons
        modeButtons.forEach { containerStack.addArrangedSubview($0) }
        
        // Add separator
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 30).isActive = true
        containerStack.addArrangedSubview(separator)
        
        // Add unit selector
        containerStack.addArrangedSubview(unitSegment)
        
        NSLayoutConstraint.activate([
            containerStack.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            containerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            containerStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        
        updateButtonStates()
    }
    
    private func createModeButton(for mode: Mode) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: mode.icon), for: .normal)
        button.tintColor = .secondaryLabel
        button.tag = mode.rawValue
        button.addTarget(self, action: #selector(modeTapped(_:)), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return button
    }
    
    // MARK: - Actions
    
    @objc private func modeTapped(_ sender: UIButton) {
        guard let mode = Mode(rawValue: sender.tag) else { return }
        currentMode = mode
        updateButtonStates()
        delegate?.toolbar(self, didSelectMode: mode)
    }
    
    @objc private func unitChanged() {
        currentUnit = unitSegment.selectedSegmentIndex == 0 ? .metric : .imperial
        delegate?.toolbar(self, didChangeUnit: currentUnit)
    }
    
    @objc private func toggleTapped() {
        isEnabled.toggle()
        toggleButton.tintColor = isEnabled ? AppColors.accent : .secondaryLabel
        delegate?.toolbarDidToggle(self, isEnabled: isEnabled)
    }
    
    // MARK: - State Management
    
    private func updateButtonStates() {
        for (index, button) in modeButtons.enumerated() {
            let isSelected = index == currentMode.rawValue
            button.tintColor = isSelected ? AppColors.accent : .secondaryLabel
            
            // Scale animation
            UIView.animate(withDuration: 0.2) {
                button.transform = isSelected ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
            }
        }
    }
    
    // MARK: - Public Methods
    
    func setMode(_ mode: Mode, animated: Bool = true) {
        currentMode = mode
        updateButtonStates()
    }
    
    func setUnit(_ unit: MeasurementUnit) {
        currentUnit = unit
        unitSegment.selectedSegmentIndex = unit == .metric ? 0 : 1
    }
}
```

#### 4.4.4 DistanceLineEntity Implementation

```swift
// Screens/MainTabs/Rooms/furniture+room/Measurement/DistanceLineEntity.swift

import RealityKit
import UIKit

/// Creates a 3D distance visualization between two points
final class DistanceLineEntity: Entity {
    
    private var lineEntity: ModelEntity?
    private var labelEntity: DimensionLabelEntity?
    private var startMarker: ModelEntity?
    private var endMarker: ModelEntity?
    
    private let startPoint: SIMD3<Float>
    private let endPoint: SIMD3<Float>
    private var unit: MeasurementUnit
    
    required init() {
        self.startPoint = .zero
        self.endPoint = .zero
        self.unit = .metric
        super.init()
    }
    
    convenience init(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        unit: MeasurementUnit,
        color: UIColor = AppColors.accent
    ) {
        self.init()
        self.startPoint = start
        self.endPoint = end
        self.unit = unit
        
        createLine(color: color)
        createMarkers(color: color)
        createLabel()
    }
    
    private func createLine(color: UIColor) {
        let distance = simd_distance(startPoint, endPoint)
        let midpoint = (startPoint + endPoint) / 2
        
        // Create cylinder as line
        let mesh = MeshResource.generateCylinder(height: distance, radius: 0.002)
        let material = SimpleMaterial(color: color, isMetallic: false)
        
        let line = ModelEntity(mesh: mesh, materials: [material])
        line.position = midpoint
        
        // Rotate to align with direction
        let direction = normalize(endPoint - startPoint)
        let up = SIMD3<Float>(0, 1, 0)
        let rotation = simd_quatf(from: up, to: direction)
        line.orientation = rotation
        
        addChild(line)
        lineEntity = line
    }
    
    private func createMarkers(color: UIColor) {
        let mesh = MeshResource.generateSphere(radius: 0.006)
        let material = SimpleMaterial(color: color, isMetallic: false)
        
        let start = ModelEntity(mesh: mesh, materials: [material])
        start.position = startPoint
        addChild(start)
        startMarker = start
        
        let end = ModelEntity(mesh: mesh, materials: [material])
        end.position = endPoint
        addChild(end)
        endMarker = end
    }
    
    private func createLabel() {
        let distance = simd_distance(startPoint, endPoint)
        let formattedDistance = formatDistance(distance)
        let midpoint = (startPoint + endPoint) / 2
        let labelPosition = midpoint + SIMD3(0, 0.05, 0) // Offset above line
        
        let label = DimensionLabelEntity(
            text: formattedDistance,
            axis: .width,
            position: labelPosition
        )
        addChild(label)
        labelEntity = label
    }
    
    private func formatDistance(_ meters: Float) -> String {
        switch unit {
        case .metric:
            if meters >= 1 {
                return String(format: "%.2fm", meters)
            } else {
                return String(format: "%.0fcm", meters * 100)
            }
        case .imperial:
            let feet = meters * 3.28084
            if feet >= 1 {
                return String(format: "%.1fft", feet)
            } else {
                let inches = meters * 39.3701
                return String(format: "%.1fin", inches)
            }
        }
    }
    
    func updateLabel(unit: MeasurementUnit) {
        self.unit = unit
        labelEntity?.removeFromParent()
        createLabel()
    }
}
```

### 4.5 Integration with RoomVisualizeVC

```swift
// Add to RoomVisualizeVC.swift

// MARK: - Properties (add these)
private var measurementToolbar: MeasurementToolbar?
private var furnitureManager: FurniturePlacementManager?
private var measurementPanel: FurnitureMeasurementPanel?

// MARK: - Setup (add toolbar)
private func setupMeasurementToolbar() {
    let toolbar = MeasurementToolbar()
    toolbar.delegate = self
    toolbar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(toolbar)
    
    NSLayoutConstraint.activate([
        toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
        toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        toolbar.heightAnchor.constraint(equalToConstant: 56)
    ])
    
    measurementToolbar = toolbar
}

// MARK: - Tap Handling for Selection
private func setupFurnitureTapGesture() {
    let tap = UITapGestureRecognizer(target: self, action: #selector(handleFurnitureTap(_:)))
    arView.addGestureRecognizer(tap)
}

@objc private func handleFurnitureTap(_ gesture: UITapGestureRecognizer) {
    let location = gesture.location(in: arView)
    
    guard let entity = arView.entity(at: location),
          let modelEntity = entity as? ModelEntity,
          let furniture = furnitureManager?.placedFurniture.first(where: { $0.entity == modelEntity }) else {
        return
    }
    
    handleFurnitureSelection(furniture)
}

private func handleFurnitureSelection(_ furniture: PlacedFurniture) {
    guard let toolbar = measurementToolbar else { return }
    
    switch toolbar.currentMode {
    case .single:
        furnitureManager?.clearSelection()
        furnitureManager?.selectFurniture(id: furniture.id)
        
    case .distance:
        if (furnitureManager?.selectedFurniture.count ?? 0) < 2 {
            furnitureManager?.selectFurniture(id: furniture.id)
        } else {
            furnitureManager?.clearSelection()
            furnitureManager?.selectFurniture(id: furniture.id)
        }
        
    case .all:
        // Show all measurements, toggle individual selection
        if furnitureManager?.selectedFurniture.contains(where: { $0.id == furniture.id }) == true {
            furnitureManager?.deselectFurniture(id: furniture.id)
        } else {
            furnitureManager?.selectFurniture(id: furniture.id)
        }
        
    case .room:
        // Room mode doesn't use selection
        break
    }
    
    updateMeasurementPanel()
}

// MARK: - MeasurementToolbarDelegate
extension RoomVisualizeVC: MeasurementToolbarDelegate {
    
    func toolbar(_ toolbar: MeasurementToolbar, didSelectMode mode: MeasurementToolbar.Mode) {
        furnitureManager?.clearVisualizations()
        furnitureManager?.clearSelection()
        
        switch mode {
        case .all:
            furnitureManager?.showAllMeasurements()
        case .single:
            // Wait for tap
            break
        case .distance:
            // Wait for two taps
            break
        case .room:
            showRoomDimensions()
        }
    }
    
    func toolbar(_ toolbar: MeasurementToolbar, didChangeUnit unit: MeasurementUnit) {
        furnitureManager?.updateUnit(unit)
        MeasurementManager.shared.currentUnit = unit
    }
    
    func toolbarDidToggle(_ toolbar: MeasurementToolbar, isEnabled: Bool) {
        if isEnabled {
            setupMeasurementToolbar()
            toolbar(toolbar, didSelectMode: toolbar.currentMode)
        } else {
            furnitureManager?.clearVisualizations()
            measurementToolbar?.removeFromSuperview()
            measurementToolbar = nil
        }
    }
}
```

### 4.6 Implementation Steps

#### Step 1: Create FurniturePlacementManager (4 hours)
1. Create class with furniture tracking
2. Implement selection system
3. Add collision detection
4. Connect to existing `placedFurniture` array

#### Step 2: Create MeasurementToolbar (3 hours)
1. Build toolbar UI component
2. Implement mode switching
3. Add unit selector
4. Style according to design spec

#### Step 3: Create DistanceLineEntity (2 hours)
1. Build 3D line visualization
2. Add endpoint markers
3. Add floating label
4. Implement unit switching

#### Step 4: Create Measurement Panel (3 hours)
1. Build info panel UI
2. Display selected items table
3. Show distances between items
4. Add collision warnings

#### Step 5: Integration (3 hours)
1. Connect all components to RoomVisualizeVC
2. Add tap gesture handling
3. Test multi-selection
4. Handle edge cases

#### Step 6: Polish & Testing (2 hours)
1. Add animations
2. Test performance with many items
3. Verify measurement accuracy
4. Add haptic feedback

---

## 6. Technical Architecture

### 5.1 Complete File Structure

```
Envision/
├── Components/
│   ├── Measurement/
│   │   ├── BoundingBoxEntity.swift         # 3D wireframe box
│   │   ├── DimensionLabelEntity.swift      # Billboard text
│   │   └── MeasurementOverlayView.swift    # 2D UI overlay
│   └── ... (existing)
│
├── Managers/
│   ├── ExportManager.swift                 # Export logic
│   ├── MeasurementManager.swift            # Measurement calculations
│   ├── FurniturePlacementManager.swift     # Furniture state
│   └── ... (existing)
│
├── Models/
│   ├── BoundingBox.swift                   # Box geometry model
│   ├── RoomExportData.swift                # Export data model
│   ├── PlacedFurniture.swift               # Furniture model
│   └── MeasurementUnit.swift               # Unit enum
│
├── Screens/
│   └── MainTabs/
│       └── Rooms/
│           ├── Export/
│           │   ├── ShareOptionsViewController.swift
│           │   ├── ExportPreviewViewController.swift
│           │   └── PDFReportGenerator.swift
│           │
│           └── furniture+room/
│               ├── Measurement/
│               │   ├── MeasurementToolbar.swift
│               │   ├── DistanceLineEntity.swift
│               │   ├── FurnitureMeasurementPanel.swift
│               │   └── CollisionDetector.swift
│               └── ... (existing)
│
└── Extensions/
    └── Entity+Measurement.swift            # Bounding box helpers
```

### 5.2 Dependency Graph

```
                    ┌─────────────────┐
                    │ RoomVisualizeVC │
                    └────────┬────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
┌─────────────────┐  ┌───────────────┐  ┌───────────────────┐
│ ExportManager   │  │ Measurement   │  │ FurniturePlacement│
│                 │  │ Manager       │  │ Manager           │
└────────┬────────┘  └───────┬───────┘  └─────────┬─────────┘
         │                   │                    │
         │           ┌───────┴───────┐           │
         │           │               │           │
         ▼           ▼               ▼           ▼
┌──────────────┐ ┌──────────┐ ┌───────────┐ ┌────────────┐
│ PDFGenerator │ │ Bounding │ │ Dimension │ │ Distance   │
│              │ │ BoxEntity│ │ Label     │ │ LineEntity │
└──────────────┘ └──────────┘ └───────────┘ └────────────┘
```

### 5.3 State Management

```swift
/// Central state for measurement features
final class MeasurementState: ObservableObject {
    
    // Singleton
    static let shared = MeasurementState()
    
    // Export State
    @Published var isExporting: Bool = false
    @Published var exportProgress: Float = 0
    @Published var lastExportError: ExportError?
    
    // Measurement State
    @Published var measurementMode: MeasurementToolbar.Mode = .single
    @Published var measurementUnit: MeasurementUnit = .metric
    @Published var isMeasurementEnabled: Bool = false
    
    // Selection State
    @Published var selectedFurnitureIDs: Set<UUID> = []
    
    // Persistence
    func savePreferences() {
        UserDefaults.standard.set(measurementUnit.rawValue, forKey: "preferredUnit")
    }
    
    func loadPreferences() {
        if let unitRaw = UserDefaults.standard.string(forKey: "preferredUnit"),
           let unit = MeasurementUnit(rawValue: unitRaw) {
            measurementUnit = unit
        }
    }
}
```

---

## 7. UI/UX Design Specifications

### 6.1 Color Palette

| Element | Color | Hex | Usage |
|---------|-------|-----|-------|
| Accent | `AppColors.accent` | #478F82 | Bounding boxes, selected states |
| Warning | System Orange | - | Collision warnings |
| Error | System Red | - | Export failures |
| Background | System Background | - | Panels, toolbars |
| Text Primary | `AppColors.textPrimary` | #2C3E50 | Labels, titles |
| Text Secondary | `AppColors.textSecondary` | #7F8C8D | Subtitles, hints |

### 6.2 Typography

| Element | Font | Size |
|---------|------|------|
| Panel Title | `AppFonts.semibold` | 18pt |
| Button Label | `AppFonts.medium` | 16pt |
| Dimension Label | `AppFonts.bold` | 12pt |
| Info Text | `AppFonts.regular` | 14pt |
| Caption | `AppFonts.regular` | 12pt |

### 6.3 Spacing & Sizing

| Element | Size |
|---------|------|
| Toolbar Height | 56pt |
| Button Minimum | 44×44pt |
| Corner Radius (Cards) | 12pt |
| Corner Radius (Buttons) | 8pt |
| Padding (Standard) | 16pt |
| Padding (Compact) | 8pt |
| Icon Size | 24pt |

### 6.4 Animations

| Interaction | Animation | Duration |
|-------------|-----------|----------|
| Button Press | Scale to 0.95 | 0.1s |
| Mode Change | Color fade + scale | 0.2s |
| Panel Appear | Slide up + fade | 0.3s |
| Measurement Show | Fade in | 0.25s |
| Label Update | Cross fade | 0.15s |

### 6.5 Haptic Feedback

| Event | Feedback Type |
|-------|---------------|
| Mode Selection | Light Impact |
| Furniture Selection | Medium Impact |
| Collision Warning | Warning Notification |
| Export Complete | Success Notification |
| Export Error | Error Notification |

---

## 8. Implementation Timeline

### 7.1 Phase Overview

| Phase | Duration | Features |
|-------|----------|----------|
| Phase 1 | 2 weeks | Export/Share |
| Phase 2 | 2 weeks | AR Measurements |
| Phase 3 | 2 weeks | Multi-Furniture |
| Phase 4 | 1 week | Testing & Polish |

### 7.2 Detailed Timeline

```
Week 1-2: Export/Share Feature
├── Day 1-2: ExportManager implementation
├── Day 3-4: ShareOptionsViewController
├── Day 5-6: PDFReportGenerator
├── Day 7-8: Integration with RoomVisualizeVC
└── Day 9-10: Testing and bug fixes

Week 3-4: AR Measurement Display
├── Day 1-2: MeasurementManager
├── Day 3-4: BoundingBoxEntity
├── Day 5-6: DimensionLabelEntity
├── Day 7-8: Integration and UI overlay
└── Day 9-10: Calibration and testing

Week 5-6: Multi-Furniture Measurements
├── Day 1-2: FurniturePlacementManager
├── Day 3-4: MeasurementToolbar
├── Day 5-6: DistanceLineEntity
├── Day 7-8: Selection system and panel
└── Day 9-10: Collision detection

Week 7: Final Polish
├── Day 1-2: Performance optimization
├── Day 3-4: UI polish and animations
└── Day 5: Final testing and documentation
```

### 7.3 Milestones

| Milestone | Date | Deliverable |
|-----------|------|-------------|
| M1 | Week 2 | Export feature complete |
| M2 | Week 4 | Single furniture measurement |
| M3 | Week 6 | Multi-furniture measurement |
| M4 | Week 7 | Feature complete release |

---

## 9. Testing Strategy

### 8.1 Unit Tests

```swift
// Tests/ExportManagerTests.swift
class ExportManagerTests: XCTestCase {
    
    func testImageCapture() async throws {
        // Given: An ARView with content
        // When: Capture snapshot
        // Then: Image is non-nil and correct size
    }
    
    func testUSDZExport() async throws {
        // Given: A scene with furniture
        // When: Export as USDZ
        // Then: File exists and is valid USDZ
    }
    
    func testPDFGeneration() {
        // Given: Room data
        // When: Generate PDF
        // Then: PDF contains all required sections
    }
}

// Tests/MeasurementManagerTests.swift
class MeasurementManagerTests: XCTestCase {
    
    func testBoundingBoxCalculation() {
        // Given: A ModelEntity with known dimensions
        // When: Calculate bounding box
        // Then: Dimensions match expected values
    }
    
    func testDistanceCalculation() {
        // Given: Two points
        // When: Calculate distance
        // Then: Distance is correct
    }
    
    func testUnitConversion() {
        // Given: A distance in meters
        // When: Convert to feet
        // Then: Conversion is accurate
    }
}
```

### 8.2 Integration Tests

| Test Case | Description | Expected Result |
|-----------|-------------|-----------------|
| Export Flow | Complete export from tap to share | Share sheet appears with content |
| Measurement Toggle | Enable/disable measurement mode | Visualizations appear/disappear |
| Multi-Select | Select 3 furniture items | All distances shown |
| Collision | Place overlapping furniture | Warning displayed |

### 8.3 Performance Tests

| Metric | Target | Test Method |
|--------|--------|-------------|
| FPS during measurement | ≥60 FPS | Measure frame rate |
| Export time (image) | <1 second | Time export |
| Export time (USDZ) | <5 seconds | Time export |
| Memory usage | <150MB | Profile memory |

### 8.4 Accessibility Tests

| Feature | Requirement |
|---------|-------------|
| Voice Over | All buttons labeled |
| Dynamic Type | Text scales correctly |
| Color Contrast | Meets WCAG AA |
| Reduce Motion | Animations respect setting |

---

## 10. Appendix: Code Templates

### 9.1 Complete ExportManager Template

```swift
// Managers/ExportManager.swift

import UIKit
import RealityKit
import SceneKit
import PDFKit

// MARK: - Export Types

enum ExportFormat {
    case image(quality: ImageQuality)
    case usdz
    case pdf
    
    enum ImageQuality: CGFloat {
        case standard = 1.0
        case high = 2.0
        case maximum = 3.0
    }
}

enum ExportError: LocalizedError {
    case snapshotFailed
    case usdzExportFailed(Error)
    case pdfGenerationFailed
    case fileWriteFailed(Error)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .snapshotFailed: return "Failed to capture image"
        case .usdzExportFailed(let e): return "Export failed: \(e.localizedDescription)"
        case .pdfGenerationFailed: return "PDF generation failed"
        case .fileWriteFailed(let e): return "Save failed: \(e.localizedDescription)"
        case .cancelled: return "Export cancelled"
        }
    }
}

struct ExportConfiguration {
    var includeMeasurements: Bool = true
    var includeFurnitureLabels: Bool = true
    var includeWatermark: Bool = false
    var imageQuality: ExportFormat.ImageQuality = .high
}

struct RoomExportData {
    let name: String
    let dimensions: RoomDimensions
    let furniture: [FurnitureExportItem]
    let createdDate: Date
}

struct RoomDimensions {
    let width: Float
    let length: Float
    let height: Float
}

struct FurnitureExportItem {
    let name: String
    let dimensions: String
    let position: String
}

// MARK: - ExportManager

final class ExportManager {
    
    static let shared = ExportManager()
    private init() {}
    
    // MARK: - Image Export
    
    func captureSnapshot(
        from arView: ARView,
        quality: ExportFormat.ImageQuality = .high,
        completion: @escaping (Result<UIImage, ExportError>) -> Void
    ) {
        arView.snapshot(saveToHDR: false) { image in
            guard let image = image else {
                completion(.failure(.snapshotFailed))
                return
            }
            
            // Scale if needed
            if quality != .standard {
                let scaledSize = CGSize(
                    width: image.size.width * quality.rawValue,
                    height: image.size.height * quality.rawValue
                )
                UIGraphicsBeginImageContextWithOptions(scaledSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: scaledSize))
                let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                completion(.success(scaledImage ?? image))
            } else {
                completion(.success(image))
            }
        }
    }
    
    // MARK: - USDZ Export
    
    func exportAsUSDZ(
        rootEntity: Entity,
        fileName: String,
        completion: @escaping (Result<URL, ExportError>) -> Void
    ) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("\(fileName).usdz")
        
        // Remove existing file
        try? FileManager.default.removeItem(at: fileURL)
        
        do {
            try rootEntity.exportAsUSDZ(to: fileURL)
            completion(.success(fileURL))
        } catch {
            completion(.failure(.usdzExportFailed(error)))
        }
    }
    
    // MARK: - PDF Export
    
    func generatePDF(
        roomData: RoomExportData,
        snapshot: UIImage?,
        completion: @escaping (Result<Data, ExportError>) -> Void
    ) {
        let pdfMetaData = [
            kCGPDFContextCreator: "EnVision",
            kCGPDFContextAuthor: "EnVision User",
            kCGPDFContextTitle: roomData.name
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yOffset: CGFloat = 50
            
            // Title
            let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let titleAttr: [NSAttributedString.Key: Any] = [.font: titleFont]
            roomData.name.draw(at: CGPoint(x: 50, y: yOffset), withAttributes: titleAttr)
            yOffset += 40
            
            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let dateString = "Generated: \(dateFormatter.string(from: roomData.createdDate))"
            let dateFont = UIFont.systemFont(ofSize: 12)
            dateString.draw(at: CGPoint(x: 50, y: yOffset), withAttributes: [.font: dateFont])
            yOffset += 30
            
            // Snapshot
            if let image = snapshot {
                let imageRect = CGRect(x: 50, y: yOffset, width: 512, height: 300)
                image.draw(in: imageRect)
                yOffset += 320
            }
            
            // Dimensions
            let dimTitle = "Room Dimensions"
            dimTitle.draw(at: CGPoint(x: 50, y: yOffset), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16)])
            yOffset += 25
            
            let dimText = String(format: "%.2fm × %.2fm × %.2fm",
                                 roomData.dimensions.width,
                                 roomData.dimensions.length,
                                 roomData.dimensions.height)
            dimText.draw(at: CGPoint(x: 50, y: yOffset), withAttributes: [.font: dateFont])
            yOffset += 30
            
            // Furniture List
            let furnTitle = "Furniture (\(roomData.furniture.count) items)"
            furnTitle.draw(at: CGPoint(x: 50, y: yOffset), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16)])
            yOffset += 25
            
            for item in roomData.furniture {
                let itemText = "• \(item.name) - \(item.dimensions)"
                itemText.draw(at: CGPoint(x: 60, y: yOffset), withAttributes: [.font: dateFont])
                yOffset += 20
            }
        }
        
        completion(.success(data))
    }
    
    // MARK: - Share
    
    func presentShareSheet(
        from viewController: UIViewController,
        items: [Any],
        sourceView: UIView? = nil
    ) {
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = sourceView ?? viewController.view
            popover.sourceRect = sourceView?.bounds ?? CGRect(x: viewController.view.bounds.midX,
                                                               y: viewController.view.bounds.midY,
                                                               width: 0, height: 0)
        }
        
        viewController.present(activityVC, animated: true)
    }
}

// MARK: - Entity Extension

extension Entity {
    func exportAsUSDZ(to url: URL) throws {
        // Implementation depends on RealityKit version
        // For iOS 15+, use the built-in export
        try self.write(to: url)
    }
}
```

### 9.2 Complete MeasurementManager Template

```swift
// Managers/MeasurementManager.swift

import RealityKit
import Combine
import UIKit

// MARK: - Measurement Unit

enum MeasurementUnit: String, CaseIterable {
    case metric
    case imperial
    
    var lengthSuffix: String {
        self == .metric ? "m" : "ft"
    }
    
    var smallLengthSuffix: String {
        self == .metric ? "cm" : "in"
    }
}

// MARK: - Bounding Box

struct BoundingBox {
    let min: SIMD3<Float>
    let max: SIMD3<Float>
    
    var width: Float { max.x - min.x }
    var height: Float { max.y - min.y }
    var depth: Float { max.z - min.z }
    var center: SIMD3<Float> { (min + max) / 2 }
    
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
    
    static let edgeIndices: [(Int, Int)] = [
        (0, 1), (1, 2), (2, 3), (3, 0), // Bottom
        (4, 5), (5, 6), (6, 7), (7, 4), // Top
        (0, 4), (1, 5), (2, 6), (3, 7)  // Vertical
    ]
}

// MARK: - Measurement Manager

final class MeasurementManager: ObservableObject {
    
    static let shared = MeasurementManager()
    
    // MARK: - Published State
    @Published var isEnabled: Bool = false
    @Published var currentUnit: MeasurementUnit = .metric
    @Published var selectedEntity: ModelEntity?
    
    // MARK: - Active Visualizations
    private var boundingBoxes: [Entity] = []
    private var dimensionLabels: [Entity] = []
    
    // MARK: - Configuration
    struct Config {
        static let boxColor: UIColor = AppColors.accent
        static let labelColor: UIColor = AppColors.accent
        static let edgeRadius: Float = 0.002
        static let cornerRadius: Float = 0.004
        static let labelOffset: Float = 0.05
    }
    
    private init() {}
    
    // MARK: - Bounding Box
    
    func getBoundingBox(for entity: ModelEntity) -> BoundingBox {
        let bounds = entity.visualBounds(relativeTo: nil)
        return BoundingBox(min: bounds.min, max: bounds.max)
    }
    
    // MARK: - Measurements
    
    func showMeasurements(for entity: ModelEntity, in scene: Scene) {
        let box = getBoundingBox(for: entity)
        let position = entity.position(relativeTo: nil)
        
        // Create bounding box visualization
        let boxEntity = createBoundingBoxEntity(box: box)
        boxEntity.position = position
        scene.anchors.first?.addChild(boxEntity)
        boundingBoxes.append(boxEntity)
        
        // Create dimension labels
        createDimensionLabels(for: box, at: position, in: scene)
    }
    
    func clearMeasurements(from scene: Scene) {
        boundingBoxes.forEach { $0.removeFromParent() }
        boundingBoxes.removeAll()
        
        dimensionLabels.forEach { $0.removeFromParent() }
        dimensionLabels.removeAll()
    }
    
    // MARK: - Bounding Box Entity
    
    private func createBoundingBoxEntity(box: BoundingBox) -> Entity {
        let container = Entity()
        let material = SimpleMaterial(color: Config.boxColor, isMetallic: false)
        
        // Create edges
        for (startIdx, endIdx) in BoundingBox.edgeIndices {
            let start = box.corners[startIdx]
            let end = box.corners[endIdx]
            let edge = createEdge(from: start, to: end, material: material)
            container.addChild(edge)
        }
        
        // Create corner spheres
        let sphereMesh = MeshResource.generateSphere(radius: Config.cornerRadius)
        for corner in box.corners {
            let sphere = ModelEntity(mesh: sphereMesh, materials: [material])
            sphere.position = corner
            container.addChild(sphere)
        }
        
        return container
    }
    
    private func createEdge(from start: SIMD3<Float>, to end: SIMD3<Float>, material: Material) -> ModelEntity {
        let length = simd_distance(start, end)
        let midpoint = (start + end) / 2
        
        let mesh = MeshResource.generateBox(size: [Config.edgeRadius * 2, Config.edgeRadius * 2, length])
        let edge = ModelEntity(mesh: mesh, materials: [material])
        edge.position = midpoint
        
        // Rotate to align
        let direction = normalize(end - start)
        let up = SIMD3<Float>(0, 0, 1)
        if abs(dot(direction, up)) < 0.999 {
            edge.look(at: end, from: midpoint, relativeTo: nil)
        }
        
        return edge
    }
    
    // MARK: - Dimension Labels
    
    private func createDimensionLabels(for box: BoundingBox, at position: SIMD3<Float>, in scene: Scene) {
        // Width label (X axis)
        let widthPos = SIMD3(box.center.x, box.min.y - Config.labelOffset, box.max.z) + position
        let widthLabel = createLabel(text: formatDimension(box.width), at: widthPos)
        scene.anchors.first?.addChild(widthLabel)
        dimensionLabels.append(widthLabel)
        
        // Height label (Y axis)
        let heightPos = SIMD3(box.max.x + Config.labelOffset, box.center.y, box.max.z) + position
        let heightLabel = createLabel(text: formatDimension(box.height), at: heightPos)
        scene.anchors.first?.addChild(heightLabel)
        dimensionLabels.append(heightLabel)
        
        // Depth label (Z axis)
        let depthPos = SIMD3(box.max.x, box.min.y - Config.labelOffset, box.center.z) + position
        let depthLabel = createLabel(text: formatDimension(box.depth), at: depthPos)
        scene.anchors.first?.addChild(depthLabel)
        dimensionLabels.append(depthLabel)
    }
    
    private func createLabel(text: String, at position: SIMD3<Float>) -> Entity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.025, weight: .bold),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        
        let material = SimpleMaterial(color: .white, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        
        return entity
    }
    
    // MARK: - Formatting
    
    func formatDimension(_ value: Float) -> String {
        switch currentUnit {
        case .metric:
            if value >= 1 {
                return String(format: "%.2fm", value)
            } else {
                return String(format: "%.0fcm", value * 100)
            }
        case .imperial:
            let feet = value * 3.28084
            if feet >= 1 {
                return String(format: "%.1fft", feet)
            } else {
                return String(format: "%.1fin", value * 39.3701)
            }
        }
    }
    
    func distance(from a: SIMD3<Float>, to b: SIMD3<Float>) -> Float {
        simd_distance(a, b)
    }
}
```

---

## Document Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Feb 7, 2026 | Initial document |
| 1.1 | Feb 7, 2026 | Added Section 2 (Current Screen Layout) with detailed UI structure; Updated share button placement to navigation bar (between ruler and add buttons); Revised all section numbering |

---

**Document prepared for EnVision iOS Application**  
**© 2026 EnVision Team**
