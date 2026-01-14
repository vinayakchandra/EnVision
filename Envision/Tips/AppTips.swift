//
//  AppTips.swift
//  Envision
//
//  Created for EnVision Tips & Tour System
//  Version: 1.0
//

import Foundation
import TipKit
import SwiftUI

// MARK: - Welcome & Onboarding Tips

@available(iOS 17.0, *)
struct WelcomeTip: Tip {
    var title: Text {
        Text("Welcome to EnVision! 🎉")
    }
    
    var message: Text? {
        Text("Let's take a quick tour to show you how to scan rooms and furniture, then visualize them in AR.")
    }
    
    var image: Image? {
        Image(systemName: "hand.wave.fill")
    }
    
    var actions: [Action] {
        [
            Action(id: "start-tour", title: "Start Tour"),
            Action(id: "skip", title: "Skip for now")
        ]
    }
}

// MARK: - My Rooms Tips

@available(iOS 17.0, *)
struct MyRoomsIntroTip: Tip {
    
    @Parameter
    static var hasRooms: Bool = false
    
    var title: Text {
        Text("📐 Scan Your First Room")
    }
    
    var message: Text? {
        Text("Tap the green camera button to start scanning any room using your iPhone's LiDAR sensor. We'll create a precise 3D model!")
    }
    
    var image: Image? {
        Image(systemName: "camera.viewfinder")
    }
    
    var actions: [Action] {
        [
            Action(id: "scan", title: "Scan Now"),
            Action(id: "later", title: "Maybe Later")
        ]
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasRooms) { $0 == false }
        ]
    }
}

@available(iOS 17.0, *)
struct RoomImportTip: Tip {
    
    @Parameter
    static var hasScannedRoom: Bool = false
    
    var title: Text {
        Text("📥 Already Have 3D Models?")
    }
    
    var message: Text? {
        Text("Tap the blue import button to bring in existing USDZ room models from your Files app.")
    }
    
    var image: Image? {
        Image(systemName: "square.and.arrow.down")
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasScannedRoom) { $0 == true }
        ]
    }
}

@available(iOS 17.0, *)
struct RoomActionsMenuTip: Tip {
    
    @Parameter
    static var roomCount: Int = 0
    
    var title: Text {
        Text("⚡ More Options")
    }
    
    var message: Text? {
        Text("Tap the three-dot menu for bulk actions like selecting multiple rooms or visualizing furniture in AR.")
    }
    
    var image: Image? {
        Image(systemName: "ellipsis.circle")
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$roomCount) { $0 >= 1 }
        ]
    }
}

@available(iOS 17.0, *)
struct RoomCategoriesTip: Tip {
    
    @Parameter
    static var roomCount: Int = 0
    
    var title: Text {
        Text("🏷️ Organize Your Spaces")
    }
    
    var message: Text? {
        Text("Use category chips to filter rooms by type. Long-press any room to edit its category and add custom tags.")
    }
    
    var image: Image? {
        Image(systemName: "tag.fill")
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$roomCount) { $0 >= 2 }
        ]
    }
}

// MARK: - Room Scanning Tips

@available(iOS 17.0, *)
struct RoomScanningTip: Tip {
    var title: Text {
        Text("🐢 Scan Slowly for Best Results")
    }
    
    var message: Text? {
        Text("Move your device slowly and smoothly around the room. The slower you move, the more accurate your 3D model will be. Aim for good lighting too!")
    }
    
    var image: Image? {
        Image(systemName: "tortoise.fill")
    }
}

@available(iOS 17.0, *)
struct RoomCompleteTip: Tip {
    var title: Text {
        Text("✅ Complete Coverage")
    }
    
    var message: Text? {
        Text("Make sure to scan all corners, walls, and furniture. Walk around the entire perimeter at least once. The 'Save' button will appear when enough data is captured.")
    }
    
    var image: Image? {
        Image(systemName: "checkmark.circle.fill")
    }
}

@available(iOS 17.0, *)
struct RoomPreviewTip: Tip {
    var title: Text {
        Text("👀 Review Before Saving")
    }
    
    var message: Text? {
        Text("Give your room a descriptive name and select the right category. You can always edit these details later!")
    }
    
    var image: Image? {
        Image(systemName: "pencil.circle")
    }
}

// MARK: - My Furniture Tips

@available(iOS 17.0, *)
struct FurnitureIntroTip: Tip {
    
    @Parameter
    static var hasFurniture: Bool = false
    
    var title: Text {
        Text("🪑 Capture Any Furniture")
    }
    
    var message: Text? {
        Text("Tap the green camera to scan furniture in two ways: Automatic capture (walk around) or manual photo import. Let's try it!")
    }
    
    var image: Image? {
        Image(systemName: "camera.metering.center.weighted")
    }
    
    var actions: [Action] {
        [
            Action(id: "scan", title: "Scan Furniture"),
            Action(id: "later", title: "Later")
        ]
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasFurniture) { $0 == false }
        ]
    }
}

@available(iOS 17.0, *)
struct FurnitureCaptureMethodsTip: Tip {
    var title: Text {
        Text("📸 Two Capture Methods")
    }
    
    var message: Text? {
        Text("**Automatic**: Walk around the object while the app auto-captures photos.\n**From Photos**: Import 20+ photos you've already taken.")
    }
    
    var image: Image? {
        Image(systemName: "photo.stack")
    }
}

@available(iOS 17.0, *)
struct FurnitureCategoriesTip: Tip {
    
    @Parameter
    static var furnitureCount: Int = 0
    
    var title: Text {
        Text("📂 Smart Categories")
    }
    
    var message: Text? {
        Text("Filter furniture by category: Chairs, Tables, Beds, and more. Categories make it easy to find specific items later!")
    }
    
    var image: Image? {
        Image(systemName: "square.grid.2x2")
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$furnitureCount) { $0 >= 2 }
        ]
    }
}

// MARK: - Object Capture Tips

@available(iOS 17.0, *)
struct ObjectCaptureStartTip: Tip {
    var title: Text {
        Text("🔄 360° Coverage is Key")
    }
    
    var message: Text? {
        Text("Walk slowly in a complete circle around the furniture. Capture from multiple heights: low, medium, and high angles. More photos = better quality!")
    }
    
    var image: Image? {
        Image(systemName: "arrow.triangle.2.circlepath.camera")
    }
}

@available(iOS 17.0, *)
struct ObjectCapturePhotoCountTip: Tip {
    
    @Parameter
    static var photoCount: Int = 0
    
    var title: Text {
        Text("📊 Quality Indicator")
    }
    
    var message: Text? {
        Text("Watch the photo counter and quality bar at the top. Aim for 40+ photos for excellent results. The color changes from yellow → orange → green as quality improves.")
    }
    
    var image: Image? {
        Image(systemName: "chart.bar.fill")
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$photoCount) { $0 < 20 }
        ]
    }
}

@available(iOS 17.0, *)
struct ObjectCaptureLightingTip: Tip {
    var title: Text {
        Text("💡 Good Lighting = Great Models")
    }
    
    var message: Text? {
        Text("Scan in well-lit areas with even lighting. Use the flashlight toggle if needed, but natural light works best. Avoid harsh shadows!")
    }
    
    var image: Image? {
        Image(systemName: "sun.max.fill")
    }
}

@available(iOS 17.0, *)
struct ObjectCaptureProcessingTip: Tip {
    var title: Text {
        Text("⚙️ Processing Your Model")
    }
    
    var message: Text? {
        Text("Photogrammetry can take 30 seconds to 2 minutes depending on photo count and device performance. Grab a coffee! ☕")
    }
    
    var image: Image? {
        Image(systemName: "gearshape.2.fill")
    }
}

// MARK: - AR Visualization Tips

@available(iOS 17.0, *)
struct ARPlacementTip: Tip {
    var title: Text {
        Text("🎯 Place in Real Space")
    }
    
    var message: Text? {
        Text("Move your device slowly to detect surfaces. Once you see the grid overlay, tap to place your furniture. Pinch to scale, rotate with two fingers!")
    }
    
    var image: Image? {
        Image(systemName: "viewfinder")
    }
}

@available(iOS 17.0, *)
struct ARControlsTip: Tip {
    var title: Text {
        Text("🕹️ Master AR Controls")
    }
    
    var message: Text? {
        Text("**Joystick**: Move furniture left/right/forward/back\n**Height Slider**: Adjust vertical position\n**Rotation Slider**: Turn the object\n**+/- Buttons**: Scale up or down")
    }
    
    var image: Image? {
        Image(systemName: "gamecontroller.fill")
    }
}

@available(iOS 17.0, *)
struct RoomVisualizationTip: Tip {
    
    @Parameter
    static var hasRoomAndFurniture: Bool = false
    
    var title: Text {
        Text("🏠 Visualize Furniture in Rooms")
    }
    
    var message: Text? {
        Text("Go to My Rooms → Menu → 'Visualize furniture' to place your scanned furniture inside scanned rooms. See how it fits before buying!")
    }
    
    var image: Image? {
        Image(systemName: "house.and.flag.fill")
    }
    
    var actions: [Action] {
        [
            Action(id: "try-now", title: "Try It Now")
        ]
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasRoomAndFurniture) { $0 == true }
        ]
    }
}

// MARK: - Profile & Settings Tips

@available(iOS 17.0, *)
struct ProfileCustomizationTip: Tip {
    var title: Text {
        Text("⚙️ Customize Your Experience")
    }
    
    var message: Text? {
        Text("Head to your Profile to change themes (Light/Dark), manage notifications, and control privacy settings. Make EnVision truly yours!")
    }
    
    var image: Image? {
        Image(systemName: "person.crop.circle.badge.checkmark")
    }
}

@available(iOS 17.0, *)
struct ThemeTip: Tip {
    var title: Text {
        Text("🌓 Choose Your Theme")
    }
    
    var message: Text? {
        Text("Tap 'Appearance' to switch between Light, Dark, or System mode. The app will instantly update with smooth animations.")
    }
    
    var image: Image? {
        Image(systemName: "moon.stars.fill")
    }
}

// MARK: - Advanced Features Tips

@available(iOS 17.0, *)
struct GeometryPlaygroundTip: Tip {
    
    @Parameter
    static var furnitureCount: Int = 0
    
    var title: Text {
        Text("🎨 Geometry Playground")
    }
    
    var message: Text? {
        Text("Advanced users: Try the 'Room Geometry Playground' to visualize and color-code room elements (walls, floors, doors). Great for understanding room structure!")
    }
    
    var image: Image? {
        Image(systemName: "cube.transparent")
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$furnitureCount) { $0 >= 3 }
        ]
    }
}

@available(iOS 17.0, *)
struct ShareExportTip: Tip {
    var title: Text {
        Text("📤 Share Your Creations")
    }
    
    var message: Text? {
        Text("Long-press any room or furniture model to share it via Messages, AirDrop, or save to Files. Your 3D models are truly yours!")
    }
    
    var image: Image? {
        Image(systemName: "square.and.arrow.up")
    }
}

@available(iOS 17.0, *)
struct RulerMeasurementTip: Tip {
    var title: Text {
        Text("📏 Measure Distances")
    }
    
    var message: Text? {
        Text("Tap the ruler icon to measure distances in your 3D room. Tap two points to see the exact distance between them!")
    }
    
    var image: Image? {
        Image(systemName: "ruler")
    }
}

// MARK: - Tour Completion Tip

@available(iOS 17.0, *)
struct TourCompleteTip: Tip {
    var title: Text {
        Text("🎓 You're All Set!")
    }
    
    var message: Text? {
        Text("You've learned the basics of EnVision! Start scanning to build your 3D furniture library. Tips will continue to appear as you explore more features.")
    }
    
    var image: Image? {
        Image(systemName: "checkmark.seal.fill")
    }
    
    var actions: [Action] {
        [
            Action(id: "finish", title: "Start Using EnVision")
        ]
    }
}

// MARK: - Tip Categories for Tips Library

@available(iOS 17.0, *)
enum TipCategory: String, CaseIterable {
    case gettingStarted = "Getting Started"
    case roomScanning = "Room Scanning"
    case furnitureCapture = "Furniture Capture"
    case arVisualization = "AR Visualization"
    case advanced = "Advanced Features"
    
    var icon: String {
        switch self {
        case .gettingStarted: return "hand.wave.fill"
        case .roomScanning: return "house.fill"
        case .furnitureCapture: return "chair.fill"
        case .arVisualization: return "arkit"
        case .advanced: return "sparkles"
        }
    }
    
    var color: UIColor {
        switch self {
        case .gettingStarted: return .systemBlue
        case .roomScanning: return .systemGreen
        case .furnitureCapture: return .systemOrange
        case .arVisualization: return .systemPurple
        case .advanced: return .systemPink
        }
    }
}

// MARK: - Tips Library Data

@available(iOS 17.0, *)
struct TipInfo {
    let title: String
    let message: String
    let icon: String
    let category: TipCategory
}

@available(iOS 17.0, *)
struct TipsLibrary {
    static let allTips: [TipInfo] = [
        // Getting Started
        TipInfo(
            title: "Welcome to EnVision",
            message: "EnVision helps you scan rooms and furniture, then visualize them in AR to see how they fit in your space.",
            icon: "hand.wave.fill",
            category: .gettingStarted
        ),
        TipInfo(
            title: "LiDAR Scanning",
            message: "Your device's LiDAR sensor creates precise 3D models of rooms. iPhone 12 Pro and newer, or iPad Pro models support this feature.",
            icon: "sensor.fill",
            category: .gettingStarted
        ),
        
        // Room Scanning
        TipInfo(
            title: "Scan Your First Room",
            message: "Go to My Rooms tab and tap the camera icon. Walk slowly around the room while holding your device steady.",
            icon: "camera.viewfinder",
            category: .roomScanning
        ),
        TipInfo(
            title: "Scanning Best Practices",
            message: "Scan in good lighting, move slowly, and capture all walls and corners. The more complete your scan, the better your 3D model.",
            icon: "lightbulb.fill",
            category: .roomScanning
        ),
        TipInfo(
            title: "Room Categories",
            message: "Organize rooms by category (Living Room, Bedroom, etc.) to easily find them later. Long-press any room to change its category.",
            icon: "tag.fill",
            category: .roomScanning
        ),
        TipInfo(
            title: "Import USDZ Models",
            message: "Already have 3D room models? Tap the import button to bring in USDZ files from your device or cloud storage.",
            icon: "square.and.arrow.down",
            category: .roomScanning
        ),
        
        // Furniture Capture
        TipInfo(
            title: "Capture Furniture",
            message: "Use the camera in the My Furniture tab to capture any piece of furniture. Walk around the object for best results.",
            icon: "camera.metering.center.weighted",
            category: .furnitureCapture
        ),
        TipInfo(
            title: "Automatic vs Manual Capture",
            message: "Automatic mode captures photos as you walk around. Manual mode lets you import photos you've already taken.",
            icon: "photo.stack",
            category: .furnitureCapture
        ),
        TipInfo(
            title: "Photo Count Matters",
            message: "More photos = better 3D models. Aim for 40+ photos from different angles for optimal quality.",
            icon: "number.circle.fill",
            category: .furnitureCapture
        ),
        TipInfo(
            title: "Lighting Tips",
            message: "Capture in even, natural lighting. Avoid harsh shadows and reflective surfaces for best results.",
            icon: "sun.max.fill",
            category: .furnitureCapture
        ),
        
        // AR Visualization
        TipInfo(
            title: "Place Furniture in AR",
            message: "View any furniture in AR by tapping it and selecting 'View in AR'. Move your device to find a flat surface, then tap to place.",
            icon: "arkit",
            category: .arVisualization
        ),
        TipInfo(
            title: "AR Controls",
            message: "Use pinch to scale, two fingers to rotate, and drag to move furniture in AR mode.",
            icon: "hand.draw.fill",
            category: .arVisualization
        ),
        TipInfo(
            title: "Furniture in Rooms",
            message: "Place your captured furniture inside scanned rooms to see how it fits before buying!",
            icon: "house.and.flag.fill",
            category: .arVisualization
        ),
        TipInfo(
            title: "Measure Distances",
            message: "Use the ruler tool to measure distances between points in your 3D room model.",
            icon: "ruler",
            category: .arVisualization
        ),
        
        // Advanced Features
        TipInfo(
            title: "Geometry Playground",
            message: "Advanced visualization mode that color-codes room elements like walls, floors, and doors.",
            icon: "cube.transparent",
            category: .advanced
        ),
        TipInfo(
            title: "Customize Colors",
            message: "In room edit mode, change the colors of walls, floors, and other elements to visualize different designs.",
            icon: "paintpalette.fill",
            category: .advanced
        ),
        TipInfo(
            title: "Share Your Models",
            message: "Export and share your 3D models via AirDrop, Messages, or save to Files for use in other apps.",
            icon: "square.and.arrow.up",
            category: .advanced
        ),
        TipInfo(
            title: "Theme Options",
            message: "Switch between Light, Dark, or System theme in Profile > Appearance.",
            icon: "moon.stars.fill",
            category: .advanced
        )
    ]
    
    static func tips(for category: TipCategory) -> [TipInfo] {
        allTips.filter { $0.category == category }
    }
}
