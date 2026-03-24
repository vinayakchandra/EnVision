# EnVision - Complete Technical Documentation

> **A comprehensive technical guide to the EnVision iOS application architecture, workflows, and implementation details.**

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [App Architecture](#2-app-architecture)
3. [App Launch Flow](#3-app-launch-flow)
4. [Tab 1: My Rooms](#4-tab-1-my-rooms)
5. [Tab 2: My Furniture](#5-tab-2-my-furniture)
6. [Tab 3: Profile](#6-tab-3-profile)
7. [Onboarding Flow](#7-onboarding-flow)
8. [Data Models](#8-data-models)
9. [Extensions & Utilities](#9-extensions--utilities)
10. [Components](#10-components)
11. [3D/AR Features](#11-3dar-features)
12. [File Structure Reference](#12-file-structure-reference)

---

## 1. Project Overview

**EnVision** is an iOS application that leverages Apple's RoomPlan and Object Capture technologies to:
- Scan rooms and create 3D models
- Capture furniture as 3D objects
- Visualize and edit 3D models with custom colors
- Measure dimensions in 3D space
- Manage user profiles and preferences

### Tech Stack
| Technology | Usage |
|------------|-------|
| **UIKit** | Primary UI framework |
| **RoomPlan** | Room scanning with LiDAR |
| **ARKit** | Augmented reality features |
| **RealityKit** | 3D model rendering |
| **Object Capture** | Photogrammetry for furniture |
| **QuickLook** | 3D model preview |
| **UserDefaults** | Local data persistence |

### Requirements
- iOS 16.0+
- Xcode 15.0+
- iPhone with LiDAR sensor (for scanning features)
- A12 Bionic chip or later

---

## 2. App Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         AppDelegate                              │
│                              │                                   │
│                              ▼                                   │
│                        SceneDelegate                             │
│                              │                                   │
│                              ▼                                   │
│                     SplashViewController                         │
│                              │                                   │
│                              ▼                                   │
│                    OnboardingController                          │
│                              │                                   │
│                              ▼                                   │
│                    LoginViewController                           │
│                              │                                   │
│                              ▼                                   │
│                    MainTabBarController                          │
│                    ┌─────────┼─────────┐                        │
│                    ▼         ▼         ▼                        │
│              MyRooms    MyFurniture  Profile                    │
└─────────────────────────────────────────────────────────────────┘
```

### Design Patterns Used
- **Singleton**: `UserManager`, `SaveManager`, `MetadataManager`
- **Delegation**: Collection views, document pickers, AR sessions
- **Extensions**: Organized helper methods in separate files
- **MVC**: View Controllers with model separation

---

## 3. App Launch Flow

### 3.1 AppDelegate.swift
**Location**: `Envision/AppDelegate.swift`

```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_:didFinishLaunchingWithOptions:) -> Bool
    func application(_:configurationForConnecting:options:) -> UISceneConfiguration
}
```

| Method | Purpose |
|--------|---------|
| `application(_:didFinishLaunchingWithOptions:)` | App initialization, returns `true` |
| `application(_:configurationForConnecting:options:)` | Returns scene configuration for multi-window support |

### 3.2 SceneDelegate.swift
**Location**: `Envision/SceneDelegate.swift`

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_:willConnectTo:options:)      // Initial setup
    func switchToMainApp()                     // Navigate to main tabs
    func switchToLogin()                       // Navigate to login
}
```

| Method | Purpose | Called When |
|--------|---------|-------------|
| `scene(_:willConnectTo:options:)` | Sets up window with `SplashViewController`, applies saved theme | App launches |
| `switchToMainApp()` | Replaces root with `MainTabBarController` | After successful login |
| `switchToLogin()` | Replaces root with `LoginViewController` | After logout |

**Theme Handling:**
```swift
// Reads saved theme preference
if let saved = UserDefaults.standard.object(forKey: "selectedTheme") as? Int {
    switch saved {
    case 0: style = .light
    case 1: style = .dark
    default: style = .unspecified  // System
    }
}
```

### 3.3 MainTabBarController.swift
**Location**: `Envision/MainTabBarController.swift`

```swift
final class MainTabBarController: UITabBarController {
    override func viewDidLoad()
    private func setupTabs()
    private func setupLiquidGlassEffect()
}
```

**Tab Configuration:**
| Tab | View Controller | Icon (Normal) | Icon (Selected) |
|-----|-----------------|---------------|-----------------|
| My Rooms | `MyRoomsViewController` | `house` | `house.fill` |
| My Furniture | `ScanFurnitureViewController` | `sofa.viewfinder` | `custom.sofafill.viewfinder` |
| Profile | `ProfileViewController` | `person` | `person.fill` |

**Liquid Glass Effect:**
- Transparent background with blur effect
- Rounded corners (30pt radius)
- Subtle shadow for depth

---

## 4. Tab 1: My Rooms

### 4.1 Overview
The My Rooms tab displays scanned and imported room models in a grid layout with filtering, search, and management capabilities.

### 4.2 File Structure
```
Screens/MainTabs/Rooms/
├── MyRoomsViewController.swift        # Main controller (726 lines)
├── MyRoomsViewController+helpers.swift # Extensions (382 lines)
├── RoomCell.swift                     # Collection view cell
├── RoomCategory.swift                 # Category/Type enums
├── RoomModel.swift                    # Data model
├── MetadataManager.swift              # Metadata persistence
├── furniture+room/                    # Room viewing/editing
│   ├── RoomViewerViewController.swift
│   ├── RoomVisualizeVC.swift
│   ├── RoomEditVC.swift
│   ├── FurniturePicker.swift
│   ├── FurnitureControlPanel.swift
│   └── OrbitJoystick.swift
└── RoomPlanScan/
    ├── RoomPlanScannerViewController.swift
    └── RoomPreviewViewController.swift
```

### 4.3 MyRoomsViewController.swift

#### Properties
```swift
final class MyRoomsViewController: UIViewController {
    // MARK: - UI
    var collectionView: UICollectionView!
    private var loadingOverlay: UIVisualEffectView!
    private var activityIndicator: UIActivityIndicatorView!
    private var loadingLabel: UILabel!
    private let searchController = UISearchController()
    private var refreshControl: UIRefreshControl!
    var previewURL: URL!
    private var emptyStateView: UIView!
    
    // MARK: - Data
    var roomFiles: [URL] = []
    var selectedCategory: RoomCategory?
    var selectedRoomType: RoomType?
    let thumbnailCache = NSCache<NSURL, UIImage>()
    var isSelectionMode = false
}
```

#### Key Methods

| Method | Line | Purpose |
|--------|------|---------|
| `viewDidLoad()` | ~56 | Initialize UI, clean metadata, load files |
| `setupUI()` | ~63 | Call all setup methods |
| `setupNavigationBar()` | ~74 | Create scan/import buttons, menu |
| `setupSearch()` | ~97 | Configure search controller |
| `setupCollectionView()` | ~106 | Create compositional layout |
| `setupEmptyState()` | ~538 | Create empty state UI |
| `loadRoomFiles()` | ~342 | Load USDZ files from documents |
| `importRoomFiles(_:)` | ~366 | Handle imported files |
| `scanTapped()` | ~229 | Navigate to RoomPlan scanner |
| `chipTapped(_:)` | ~236 | Handle filter chip selection |
| `enableMultipleSelection()` | ~255 | Enter multi-select mode |
| `deleteSelectedRooms()` | ~285 | Batch delete selected |
| `generateThumbnail(for:completion:)` | ~480 | Create/cache thumbnails |
| `fileSizeString(for:)` | ~506 | Format file size |
| `fileDateString(for:)` | ~516 | Format creation date |

#### UI Layout
```
┌─────────────────────────────────────────────────────────────────┐
│ Navigation Bar                                                   │
│ [☰ Menu]                              [Import ↓] [Scan 📷]      │
├─────────────────────────────────────────────────────────────────┤
│ 🔍 Search room models...                                        │
├─────────────────────────────────────────────────────────────────┤
│ Section 0: Filter Chips (horizontal scroll)                     │
│ [All (5)] [Parametric (3)] [Textured (2)] [Living Room] ...    │
├─────────────────────────────────────────────────────────────────┤
│ Section 1: Room Grid                                            │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ [Thumbnail Image]                    [Parametric] [Bedroom] │ │
│ │                                                              │ │
│ │ Room Name (without extension)                                │ │
│ │ 2.4 MB                                                       │ │
│ │ Jan 1, 2026                                                  │ │
│ └─────────────────────────────────────────────────────────────┘ │
│ (repeats for each room...)                                      │
└─────────────────────────────────────────────────────────────────┘
```

#### Collection View Layout
```swift
// Compositional layout with 2 sections
private func setupCollectionView() {
    let layout = UICollectionViewCompositionalLayout { section, _ in
        section == 0 ? self.makeChipsSection() : self.makeRoomsSection()
    }
}

// Chips: Horizontal scroll, estimated width
private func makeChipsSection() -> NSCollectionLayoutSection {
    // orthogonalScrollingBehavior = .continuous
    // Height: 32pt, Spacing: 8pt
}

// Rooms: Full width cards, 200pt height
private func makeRoomsSection() -> NSCollectionLayoutSection {
    // 1 column on iPhone, 4 columns on iPad
    // Height: 200pt
}
```

### 4.4 MyRoomsViewController+helpers.swift

#### Protocol Conformances
```swift
extension MyRoomsViewController: UIDocumentPickerDelegate
extension MyRoomsViewController: UICollectionViewDataSource, UICollectionViewDelegate
extension MyRoomsViewController: UISearchResultsUpdating
extension MyRoomsViewController: QLPreviewControllerDataSource
extension MyRoomsViewController: UICollectionViewDataSourcePrefetching
```

#### Key Methods

| Method | Purpose |
|--------|---------|
| `documentPicker(_:didPickDocumentsAt:)` | Handle imported files |
| `numberOfSections(in:)` | Returns 2 (chips + rooms) |
| `collectionView(_:numberOfItemsInSection:)` | Chips count or filtered files count |
| `collectionView(_:cellForItemAt:)` | Configure ChipCell or RoomCell |
| `collectionView(_:didSelectItemAt:)` | Open room viewer or handle selection |
| `collectionView(_:contextMenuConfigurationForItemAt:)` | Long-press menu |
| `collectionView(_:prefetchItemsAt:)` | Prefetch thumbnails for performance |
| `quickLook(url:)` | Show QuickLook preview |
| `showEditCategoryDialog(for:currentMetadata:)` | Category picker |
| `showEditRoomTypeDialog(for:currentMetadata:)` | Room type picker |
| `showRenameDialog(for:)` | Rename room |
| `shareRoom(url:)` | Share via activity sheet |
| `confirmDelete(url:)` | Delete with confirmation |

#### Context Menu Actions
```swift
UIMenu(children: [
    UIAction(title: "View in AR", image: "arkit") { self?.quickLook(url: url) },
    UIAction(title: "Edit Category", image: "tag") { ... },
    UIAction(title: "Edit Room Type", image: "cube") { ... },
    UIAction(title: "Rename", image: "pencil") { ... },
    UIAction(title: "Share", image: "square.and.arrow.up") { ... },
    UIAction(title: "Delete", image: "trash", attributes: .destructive) { ... }
])
```

### 4.5 RoomCell.swift

#### Properties
```swift
final class RoomCell: UICollectionViewCell {
    static let reuseID = "RoomCell"
    
    private let thumbnailView: UIImageView
    private let titleLabel: UILabel
    private let sizeLabel: UILabel
    private let dateLabel: UILabel
    private let container: UIView
    private let selectionCircle: UIImageView
    private let categoryBadge: UIView
    private let roomTypeBadge: UIView
}
```

#### Configure Method
```swift
func configure(
    fileName: String,           // Displays without extension
    size: String,               // e.g., "2.4 MB"
    dateText: String,           // e.g., "Jan 1, 2026"
    thumbnail: UIImage?,
    category: RoomCategory?,    // Shows badge if set
    roomType: RoomType?         // Shows badge if set
)
```

### 4.6 RoomCategory.swift

```swift
enum RoomCategory: String, Codable, CaseIterable {
    case livingRoom = "Living Room"   // 🛋️ Orange
    case bedroom = "Bedroom"          // 🛏️ Purple
    case studyRoom = "Study Room"     // 📚 Blue
    case office = "Office"            // 💼 Green
    case other = "Other"              // ❓ Gray
    
    var sfSymbol: String { ... }
    var color: UIColor { ... }
    var displayName: String { rawValue }
}

enum RoomType: String, Codable, CaseIterable {
    case parametric = "Parametric"    // RoomPlan API, Teal
    case textured = "Textured"        // Object Capture, Pink
    
    var sfSymbol: String { ... }
    var color: UIColor { ... }
    var description: String { ... }
}
```

### 4.7 MetadataManager.swift

```swift
class MetadataManager {
    static let shared = MetadataManager()
    
    // Core Methods
    func loadMetadata() -> RoomsMetadata
    func saveMetadata(_ metadata: RoomsMetadata)
    func getMetadata(for filename: String) -> RoomMetadata?
    func updateMetadata(for filename: String, metadata: RoomMetadata)
    func deleteMetadata(for filename: String)
    func renameMetadata(from oldFilename: String, to newFilename: String)
    func cleanupOrphanedMetadata()
}
```

**Storage Location**: `Documents/roomPlan/rooms_metadata.json`

### 4.8 Room Scanning Flow

```
┌──────────────────────┐
│ MyRoomsViewController │
│                      │
│    [Scan Button]     │
└──────────┬───────────┘
           │ scanTapped()
           ▼
┌──────────────────────────────┐
│ RoomPlanScannerViewController │
│                              │
│ ┌──────────────────────────┐ │
│ │    RoomCaptureView       │ │
│ │    (Apple's UI)          │ │
│ └──────────────────────────┘ │
│                              │
│        [Save Button]         │
└──────────────┬───────────────┘
               │ saveTapped()
               ▼
┌──────────────────────────┐
│ RoomPreviewViewController │
│                          │
│  - Preview captured room │
│  - Enter room name       │
│  - Select category       │
│  - Export as USDZ        │
└──────────────┬───────────┘
               │ Save & Export
               ▼
┌──────────────────────┐
│ MyRoomsViewController │
│                      │
│  loadRoomFiles()     │
│  (refreshes grid)    │
└──────────────────────┘
```

### 4.9 Room Viewing Flow

```
┌──────────────────────┐
│ MyRoomsViewController │
│                      │
│  [Tap on Room Cell]  │
└──────────┬───────────┘
           │ didSelectItemAt
           ▼
┌─────────────────────────────┐
│   RoomViewerViewController   │
│                             │
│ [Visualize]     [Edit]      │  ← Segmented Control
│                             │
└──────────┬──────────────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌──────────┐  ┌──────────┐
│Visualize │  │  Edit    │
│   VC     │  │   VC     │
└──────────┘  └──────────┘
```

### 4.10 RoomVisualizeVC.swift

#### Properties
```swift
final class RoomVisualizeVC: UIViewController {
    private let roomURL: URL
    private var roomModel: ModelEntity?
    private var displayedModel: ModelEntity?
    private var placedFurniture: [ModelEntity] = []
    
    // Measurement
    private var isMeasuringMode = false
    private var measurementPoints: [SIMD3<Float>] = []
    private var measurementLabel: UILabel?
    private var measurementLine: ModelEntity?
    
    // Camera
    private let orbitCamera = PerspectiveCamera()
    private var cameraPitch: Float = .pi / 6
    private var cameraYaw: Float = .pi / 4
    private var cameraDistance: Float = 1.5
    
    private let arView: ARView  // Non-AR mode
}
```

#### Key Features
1. **3D Orbit Camera**: Pan and pinch to rotate/zoom
2. **Ruler Tool**: Tap two points to measure distance
3. **Add Furniture**: Place furniture models in the room
4. **Control Panel**: Adjust furniture scale, rotation, position

#### Measurement Flow
```
[Tap Ruler Button] → isMeasuringMode = true
        │
        ▼
[Show Instructions Toast]
        │
        ▼
[Tap First Point] → Add orange sphere marker
        │
        ▼
[Tap Second Point] → Add second marker
        │                    │
        ▼                    ▼
[Draw Line Between]   [Calculate Distance]
        │                    │
        ▼                    ▼
[Show Distance Label: "📏 1.5 m (4.9 ft)"]
```

### 4.11 RoomEditVC.swift

#### Key Features
1. **Color Picker**: Change colors of walls, floors, doors, windows, etc.
2. **Labels Toggle**: Show/hide entity labels
3. **Add Furniture**: Same as Visualize mode
4. **Floating Menu**: Quick access to all editing tools

#### Color Targets
```swift
enum ColorTarget {
    case walls
    case doors
    case tables
    case floors
    case windows
    case storage
    case selected
}
```

---

## 5. Tab 2: My Furniture

### 5.1 Overview
The My Furniture tab manages 3D furniture models captured via Object Capture or imported as USDZ files.

### 5.2 File Structure
```
Screens/MainTabs/furniture/
├── ScanFurnitureViewController.swift   # Main controller (1092 lines)
├── FurnitureCell.swift                 # Collection view cell
├── FurnitureCategory.swift             # Category enum
├── CreateModel/
│   ├── CreateModelViewController.swift
│   └── CreateModelViewController2.swift
├── ModelsFromFiles/
│   ├── USDZCell.swift
│   └── ViewModelsViewController.swift
├── Object Capture/
│   ├── ObjectScanViewController.swift
│   ├── ObjectCapturePreviewController.swift
│   ├── ARMeshExporter.swift
│   ├── ArrowGuideView.swift
│   ├── FeedbackBubble.swift
│   ├── InstructionOverlay.swift
│   └── ProgressRingView.swift
└── roomPlanColor/
    ├── VisualizeRoomViewController.swift
    ├── RoomARWithFurnitureViewController.swift
    └── RoomARView 1.swift / 2.swift
```

### 5.3 ScanFurnitureViewController.swift

#### Properties
```swift
final class ScanFurnitureViewController: UIViewController {
    // MARK: - UI
    private var collectionView: UICollectionView!
    private var loadingOverlay: UIVisualEffectView!
    private var emptyStateView: UIView!
    private let searchController = UISearchController()
    private var refreshControl: UIRefreshControl!
    
    // MARK: - Data
    private var furnitureFiles: [URL] = []
    private var filteredFiles: [URL] = []
    private var selectedCategory: FurnitureCategory? = nil
    private let thumbnailCache: NSCache<NSURL, UIImage> = .init()
    private var previewURL: URL?
}
```

#### Key Methods

| Method | Line | Purpose |
|--------|------|---------|
| `viewDidLoad()` | ~104 | Initialize UI |
| `setupNavigationBar()` | ~139 | Scan menu, import button |
| `setupCollectionView()` | ~337 | Compositional layout |
| `setupEmptyState()` | ~488 | Empty state UI |
| `loadFurnitureFiles(from:)` | ~544 | Load USDZ from documents |
| `generateThumbnail(for:completion:)` | ~592 | Create/cache thumbnails |
| `automaticCaptureTapped()` | ~618 | Open ObjectScanViewController |
| `createFromPhotosTapped()` | ~623 | Open CreateModelViewController |
| `importUSDZTapped()` | ~628 | Open document picker |
| `getCategoryForURL(_:)` | ~66 | Get/infer category |
| `inferCategory(from:)` | ~75 | Keyword-based inference |
| `chipTapped(at:)` | ~786 | Category filter |
| `showQuickLook(url:)` | ~833 | Open QL preview |
| `renameModel(at:url:)` | ~841 | Edit dialog |
| `deleteModel(at:url:)` | ~936 | Delete confirmation |

#### UI Layout
```
┌─────────────────────────────────────────────────────────────────┐
│ Navigation Bar                                                   │
│ [☰ Menu]                              [Import ↓] [Scan ▾]       │
├─────────────────────────────────────────────────────────────────┤
│ 🔍 Search models...                                             │
├─────────────────────────────────────────────────────────────────┤
│ Section 0: Category Chips                                        │
│ [All (8)] [Chairs] [Tables] [Storage] [Beds] [Lighting] ...    │
├─────────────────────────────────────────────────────────────────┤
│ Section 1: Furniture Grid (2 columns)                           │
│ ┌───────────────┐ ┌───────────────┐                             │
│ │ [Thumbnail]   │ │ [Thumbnail]   │                             │
│ │               │ │               │                             │
│ │ Chair Model   │ │ Table Model   │                             │
│ │ 1.2 MB        │ │ 3.4 MB        │                             │
│ │ Jan 1, 2026   │ │ Dec 28, 2025  │                             │
│ └───────────────┘ └───────────────┘                             │
└─────────────────────────────────────────────────────────────────┘
```

#### Scan Menu Options
```swift
let scanMenu = UIMenu(children: [
    UIAction(title: "Automatic Object Capture", 
             image: "camera.metering.center.weighted") { 
        self.automaticCaptureTapped()  // → ObjectScanViewController
    },
    UIAction(title: "Create From Photos", 
             image: "photo.on.rectangle.angled") { 
        self.createFromPhotosTapped()  // → CreateModelViewController
    }
])
```

### 5.4 FurnitureCell.swift

```swift
final class FurnitureCell: UICollectionViewCell {
    static let reuseIdentifier = "FurnitureCell"
    
    private let container: UIView
    private let thumbnailImageView: UIImageView
    private let nameLabel: UILabel
    private let sizeLabel: UILabel
    private let dateLabel: UILabel
    private let selectionOverlay: UIView
    private let checkmarkImageView: UIImageView
    private let placeholderIcon: UIImageView
    
    func configure(name: String, sizeText: String, dateText: String, thumbnail: UIImage?)
}
```

### 5.5 FurnitureCategory.swift

```swift
enum FurnitureCategory: String, Codable, CaseIterable {
    case seating = "Chairs"        // 🪑 Blue
    case tables = "Tables"         // 🪑 Orange
    case storage = "Storage"       // 🗄️ Purple
    case beds = "Beds"             // 🛏️ Indigo
    case lighting = "Lighting"     // 💡 Yellow
    case decor = "Decor"           // 🖼️ Pink
    case kitchen = "Kitchen"       // 🍳 Teal
    case outdoor = "Outdoor"       // 🌳 Green
    case office = "Office"         // 💻 Brown
    case electronics = "Electronics" // 📺 Cyan
    case other = "Other"           // 📦 Gray
    
    var sfSymbol: String { ... }
    var icon: String { sfSymbol }
    var color: UIColor { ... }
    var displayName: String { rawValue }
}
```

#### Category Inference
```swift
private func inferCategory(from name: String) -> FurnitureCategory {
    let lowercased = name.lowercased()
    
    if lowercased.contains("chair") || lowercased.contains("sofa") { return .seating }
    if lowercased.contains("table") || lowercased.contains("desk") { return .tables }
    if lowercased.contains("cabinet") || lowercased.contains("shelf") { return .storage }
    if lowercased.contains("bed") { return .beds }
    if lowercased.contains("lamp") || lowercased.contains("light") { return .lighting }
    // ... more patterns
    
    return .other
}
```

### 5.6 Object Capture Flow

```
┌────────────────────────────┐
│ ScanFurnitureViewController │
│                            │
│  [Scan ▾] → "Automatic"    │
└─────────────┬──────────────┘
              │
              ▼
┌─────────────────────────────────┐
│    ObjectScanViewController      │
│                                 │
│ ┌─────────────────────────────┐ │
│ │     Camera Preview          │ │
│ │                             │ │
│ │   📸 Auto-capture timer     │ │
│ │                             │ │
│ └─────────────────────────────┘ │
│                                 │
│ Photos: [42]  "Keep going..."   │
│                                 │
│      [Finish Capture]           │
└─────────────┬───────────────────┘
              │ stopCapture()
              ▼
┌─────────────────────────────────────┐
│ ObjectCapturePreviewController       │
│                                     │
│  Processing photos...               │
│  ████████████░░░░ 75%               │
│                                     │
│  → PhotogrammetrySession            │
│  → Generate 3D model                │
│  → Export as USDZ                   │
└─────────────┬───────────────────────┘
              │
              ▼
┌────────────────────────────┐
│ ScanFurnitureViewController │
│                            │
│  loadFurnitureFiles()      │
│  (refreshes grid)          │
└────────────────────────────┘
```

---

## 6. Tab 3: Profile

### 6.1 Overview
The Profile tab manages user settings, preferences, and account information.

### 6.2 File Structure
```
Screens/MainTabs/profile/
├── ProfileViewController.swift
├── ProfileCell.swift
├── EditProfileViewController.swift
└── SubScreens/
    ├── AppearanceViewController.swift
    ├── NotificationsViewController.swift
    ├── PrivacyControlsViewController.swift
    ├── PermissionsViewController.swift
    ├── EmailPasswordViewController.swift
    ├── AppInfoViewController.swift
    ├── TermsViewController.swift
    └── PrivacyPolicyViewController.swift
```

### 6.3 ProfileViewController.swift

#### UI Layout
```
┌─────────────────────────────────────────────┐
│ Profile                                     │
├─────────────────────────────────────────────┤
│           ┌───────────┐                     │
│           │  Avatar   │                     │
│           └───────────┘                     │
│              Shaurya                        │
│         shaurya@gmail.com                   │
│         [Edit Profile]                      │
├─────────────────────────────────────────────┤
│ ACCOUNT                                     │
│   👤 My Profile                         ▶   │
│   ✉️ Email & Password                   ▶   │
├─────────────────────────────────────────────┤
│ PREFERENCES                                 │
│   🎨 Appearance                         ▶   │
│   🔔 Notifications                      ▶   │
├─────────────────────────────────────────────┤
│ PRIVACY & SECURITY                          │
│   🔒 Privacy Controls                   ▶   │
│   ✋ Permissions                        ▶   │
├─────────────────────────────────────────────┤
│ ABOUT                                       │
│   ℹ️ App Info                           ▶   │
│   📄 Terms of Service                   ▶   │
│   🛡️ Privacy Policy                    ▶   │
├─────────────────────────────────────────────┤
│   🚪 Sign Out (red)                         │
├─────────────────────────────────────────────┤
│            Version 1.0 (1)                  │
└─────────────────────────────────────────────┘
```

#### Sections Enum
```swift
private enum Section: Int, CaseIterable {
    case account
    case preferences
    case privacy
    case about
    case logout
}
```

#### Navigation Mapping

| Section | Item | Destination |
|---------|------|-------------|
| Account | My Profile | `EditProfileViewController` (modal) |
| Account | Email & Password | `EmailPasswordViewController` |
| Preferences | Appearance | `AppearanceViewController` |
| Preferences | Notifications | `NotificationsViewController` |
| Privacy | Privacy Controls | `PrivacyControlsViewController` |
| Privacy | Permissions | `PermissionsViewController` |
| About | App Info | `AppInfoViewController` |
| About | Terms of Service | `TermsViewController` |
| About | Privacy Policy | `PrivacyPolicyViewController` |
| Logout | Sign Out | `handleLogout()` |

#### Logout Flow
```swift
private func handleLogout() {
    // Show confirmation alert
    // On confirm: performLogout()
}

private func performLogout() {
    // Clear user data
    // Navigate to login via SceneDelegate
    if let sceneDelegate = scene.delegate as? SceneDelegate {
        sceneDelegate.switchToLogin()
    }
}
```

---

## 7. Onboarding Flow

### 7.1 File Structure
```
Screens/Onboarding/
├── SplashViewController.swift
├── OnboardingController.swift
├── OnboardingPage.swift
├── LoginViewController.swift
├── SignupViewController.swift
├── ForgotPasswordViewController.swift
├── ModernTextField.swift
└── SocialButton.swift
```

### 7.2 Complete Flow

```
┌──────────────────────┐
│  SplashViewController │
│                      │
│  ┌────────────────┐  │
│  │    EnVision    │  │
│  │     Logo       │  │
│  │   (animated)   │  │
│  └────────────────┘  │
│                      │
│  "See it in your     │
│   space, before      │
│   you buy it."       │
└──────────┬───────────┘
           │ goNext() after animation
           ▼
┌─────────────────────────────────┐
│     OnboardingController         │
│                                 │
│  ┌───────────────────────────┐  │
│  │      Page 1: Scan         │  │
│  │   🔲 "Scan Your Room"     │  │
│  │   Turn your space into    │  │
│  │   a 3D model using AR.    │  │
│  └───────────────────────────┘  │
│                                 │
│           ● ○ ○                 │
│                                 │
│  [Skip]            [Continue]   │
└─────────────┬───────────────────┘
              │ (swipe or tap Continue)
              ▼
┌─────────────────────────────────┐
│  Page 2: Capture                │
│  📷 "Capture Any Furniture"     │
│  Transform real items into      │
│  3D models.                     │
│                                 │
│           ○ ● ○                 │
└─────────────┬───────────────────┘
              │
              ▼
┌─────────────────────────────────┐
│  Page 3: Visualize              │
│  🔮 "Visualize with Confidence" │
│  See how items fit before       │
│  you buy.                       │
│                                 │
│           ○ ○ ●                 │
│                                 │
│  [Skip]         [Get Started]   │
└─────────────┬───────────────────┘
              │ goToLogin()
              ▼
┌─────────────────────────────────┐
│      LoginViewController         │
│                                 │
│      ┌─────────────────┐        │
│      │    EnVision     │        │
│      └─────────────────┘        │
│                                 │
│  [Email Field]                  │
│  [Password Field]               │
│                                 │
│  [Continue Button]              │
│                                 │
│  Forgot password? Create Account│
│                                 │
│  [Sign in with Apple]           │
│  [Sign in with Google]          │
└──────────┬──────────────────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌──────────┐ ┌──────────────────┐
│ Signup   │ │ ForgotPassword   │
│VC        │ │ VC               │
└────┬─────┘ └──────────────────┘
     │
     ▼
┌──────────────────────┐
│ MainTabBarController  │
│ (via SceneDelegate)   │
└──────────────────────┘
```

### 7.3 SplashViewController.swift

```swift
class SplashViewController: UIViewController {
    private let iconView: UIImageView      // App logo
    private let titleLabel: UILabel        // "EnVision"
    private let subLabel: UILabel          // Tagline
    
    override func viewDidAppear(_ animated: Bool) {
        animateLogo()
    }
    
    private func animateLogo() {
        // Spring animation: scale 0.92 → 1.02 → 1.0
        // Duration: 1.2s
        // On completion: goNext()
    }
    
    private func goNext() {
        // Present OnboardingController with crossDissolve
    }
}
```

### 7.4 LoginViewController.swift

#### Key Methods

| Method | Purpose |
|--------|---------|
| `handleLogin()` | Validate & login via UserManager |
| `goToSignup()` | Push SignupViewController |
| `goToForgotPassword()` | Push ForgotPasswordViewController |
| `showError(_:)` | Display error label |

#### Login Flow
```swift
@objc private func handleLogin() {
    let email = emailField.textField.text ?? ""
    let password = passwordField.textField.text ?? ""
    
    guard !email.isEmpty, !password.isEmpty else { 
        showError("All fields are required.") 
        return 
    }
    guard email.isValidEmail else { 
        showError("Invalid email format.") 
        return 
    }
    
    UserManager.shared.login(email: email, password: password) { result in
        switch result {
        case .success:
            sceneDelegate.switchToMainApp()
        case .failure(let error):
            self.showError(error.localizedDescription)
        }
    }
}
```

---

## 8. Data Models

### 8.1 RoomMetadata

```swift
struct RoomMetadata: Codable {
    var category: RoomCategory?
    var roomType: RoomType?
    var createdAt: Date
    var dimensions: RoomDimensions?
    var tags: [String]
    var notes: String?
}

struct RoomDimensions: Codable {
    let width: Double
    let height: Double
    let length: Double
}

struct RoomsMetadata: Codable {
    var version: String
    var rooms: [String: RoomMetadata]  // filename -> metadata
}
```

### 8.2 FurnitureMetadata

```swift
struct FurnitureMetadata: Codable {
    var category: FurnitureCategory?
    var furnitureType: FurnitureType?
    var createdAt: Date
    var tags: [String]
    var notes: String?
}
```

### 8.3 UserModel

```swift
struct UserModel: Codable {
    var id: String
    var name: String
    var email: String
    var bio: String?
    var profileImagePath: String?
    var preferences: UserPreferences?
}

struct UserPreferences: Codable {
    var theme: Int           // 0: Light, 1: Dark, 2: System
    var notifications: Bool
    var haptics: Bool
}
```

### 8.4 RoomModel

```swift
struct RoomModel {
    let id: UUID
    var name: String
    var createdAt: Date
    var thumbnail: UIImage?
    var sizeDescription: String
    var capturedRoom: CapturedRoom  // From RoomPlan
}
```

---

## 9. Extensions & Utilities

### 9.1 File Structure
```
Extensions/
├── Entity+Visit.swift
├── Extensions.swift
├── SaveManager.swift
├── UIColor+Hex.swift
├── UIFont+AppFonts.swift
├── UIViewController+Transition.swift
├── UserManager.swift
└── UserModel.swift
```

### 9.2 Entity+Visit.swift

```swift
extension Entity {
    /// Recursively visits all child entities
    func visit(_ closure: (Entity) -> Void) {
        closure(self)
        for child in children {
            child.visit(closure)
        }
    }
}
```

### 9.3 Extensions.swift

```swift
// String validation
extension String {
    var isValidEmail: Bool {
        // Regex validation
    }
    
    var isStrongPassword: Bool {
        // 8+ chars, 1 uppercase, 1 number
    }
}

// UIView helpers
extension UIView {
    func applyGradientBackground(colors: [UIColor])
}
```

### 9.4 UIColor+Hex.swift

```swift
extension UIColor {
    convenience init(hex: String) {
        // Parse hex string to RGB
    }
    
    func toHex() -> String {
        // Convert to hex string
    }
}

struct AppColors {
    static let accent = UIColor(hex: "#4A9085")
    static let primary = UIColor(hex: "#2C3E50")
    static let secondary = UIColor(hex: "#7F8C8D")
    static let background = UIColor(hex: "#F5F6FA")
    static let error = UIColor(hex: "#E74C3C")
    static let success = UIColor(hex: "#27AE60")
}
```

### 9.5 UIFont+AppFonts.swift

```swift
struct AppFonts {
    static func regular(_ size: CGFloat) -> UIFont
    static func medium(_ size: CGFloat) -> UIFont
    static func semibold(_ size: CGFloat) -> UIFont
    static func bold(_ size: CGFloat) -> UIFont
}
```

### 9.6 SaveManager.swift

```swift
final class SaveManager {
    static let shared = SaveManager()
    
    enum ModelType: String {
        case room = "roomPlan"
        case furniture = "furniture"
    }
    
    // Core Methods
    func saveModel(from sourceURL: URL, type: ModelType, 
                   customName: String?, completion: @escaping (URL?) -> Void)
    func getSavedModels(type: ModelType) -> [URL]
    func deleteModel(at url: URL, completion: @escaping (Bool) -> Void)
    func getThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void)
    func getMetadata(for url: URL) -> ModelMetadata?
    func getStorageInfo(type: ModelType) -> (count: Int, totalSize: Int64)
}
```

### 9.7 UserManager.swift

```swift
final class UserManager {
    static let shared = UserManager()
    
    var currentUser: UserModel?
    
    // Authentication
    func login(email: String, password: String, 
               completion: @escaping (Result<UserModel, Error>) -> Void)
    func signup(name: String, email: String, password: String, 
                completion: @escaping (Result<UserModel, Error>) -> Void)
    func logout()
    
    // Profile
    func updateProfile(name: String?, email: String?, bio: String?)
    func updatePreferences(_ preferences: UserPreferences)
    func saveProfileImage(_ image: UIImage)
    func loadProfileImage() -> UIImage?
}
```

---

## 10. Components

### 10.1 File Structure
```
Components/
├── CustomTextField.swift
├── PrimaryButton.swift
└── PrimaryButton1.swift
```

### 10.2 CustomTextField.swift

```swift
final class CustomTextField: UITextField {
    // Styled text field with padding
    // Rounded corners, border
    // Placeholder styling
}
```

### 10.3 PrimaryButton.swift

```swift
final class PrimaryButton: UIButton {
    init(title: String) {
        // Green background (#4A9085)
        // White text
        // Rounded corners
    }
}
```

### 10.4 PrimaryButton1.swift

```swift
final class PrimaryButton1: UIButton {
    init(title: String) {
        // Uses UIButton.Configuration (modern API)
        // Filled style
        // cornerStyle: .large
    }
}
```

### 10.5 ModernTextField.swift

```swift
final class ModernTextField: UIView {
    let textField = UITextField()
    private let floatingLabel = UILabel()
    private let eyeButton = UIButton()
    
    init(placeholder: String, secure: Bool = false)
    
    // Features:
    // - Floating label animation
    // - Show/hide password toggle
    // - Focus state styling
}
```

### 10.6 SocialButton.swift

```swift
final class SocialButton: UIButton {
    init(title: String, image: UIImage?) {
        // Horizontal stack: icon + label
        // Light background with border
        // Shadow effect
    }
}
```

---

## 11. 3D/AR Features

### 11.1 RoomPlan Integration

**RoomPlanScannerViewController.swift**
```swift
final class RoomPlanScannerViewController: UIViewController, 
                                           RoomCaptureSessionDelegate {
    private let captureSession = RoomCaptureSession()
    private lazy var captureView = RoomCaptureView()
    private var capturedRoom: CapturedRoom?
    
    // Delegate methods
    func captureSession(_ session: RoomCaptureSession, 
                        didUpdate room: CapturedRoom)
    func captureSession(_ session: RoomCaptureSession, 
                        didEndWith room: CapturedRoom, error: Error?)
}
```

### 11.2 Object Capture Integration

**ObjectScanViewController.swift**
```swift
final class ObjectScanViewController: UIViewController {
    // Camera
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    
    // Auto-capture timer
    private var captureTimer: Timer?
    private var images: [URL] = []
    
    // Methods
    func startCapturing()      // Begin auto-capture
    func stopCapture()         // Finish and process
    func capturePhoto()        // Single photo capture
}
```

**ObjectCapturePreviewController.swift**
```swift
// Uses PhotogrammetrySession to create 3D model
// Processes captured photos
// Exports USDZ file
```

### 11.3 3D Visualization

**RoomVisualizeVC.swift Features:**
- Non-AR 3D view with orbit camera
- Pan gesture: Rotate camera
- Pinch gesture: Zoom in/out
- Ruler tool: Measure distances
- Furniture placement

**RoomEditVC.swift Features:**
- All visualization features
- Color picker for room elements
- Labels toggle
- Floating action menu

### 11.4 AR Preview

Uses `QLPreviewController` for:
- Full AR experience
- Scale, rotate, move models
- Share screenshots
- USDZ native preview

---

## 12. File Structure Reference

```
EnVision/
├── README.md
├── IMPROVEMENTS.md
├── TECHNICAL_DOCUMENTATION.md (this file)
│
├── Envision/
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── MainTabBarController.swift
│   ├── ViewController.swift
│   ├── Info.plist
│   │
│   ├── 3D_Models/
│   │   ├── chair.usdz
│   │   ├── hall.usdz
│   │   ├── ios_room.usdz
│   │   ├── ios_room1.usdz
│   │   └── table.usdz
│   │
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/
│   │   ├── envision.imageset/
│   │   ├── google_icon.imageset/
│   │   ├── sofa.viewfinder.symbolset/
│   │   └── custom.sofafill.viewfinder.symbolset/
│   │
│   ├── Base.lproj/
│   │   └── LaunchScreen.storyboard
│   │
│   ├── Components/
│   │   ├── CustomTextField.swift
│   │   ├── PrimaryButton.swift
│   │   └── PrimaryButton1.swift
│   │
│   ├── Extensions/
│   │   ├── Entity+Visit.swift
│   │   ├── Extensions.swift
│   │   ├── SaveManager.swift
│   │   ├── UIColor+Hex.swift
│   │   ├── UIFont+AppFonts.swift
│   │   ├── UIViewController+Transition.swift
│   │   ├── UserManager.swift
│   │   └── UserModel.swift
│   │
│   └── Screens/
│       ├── MainTabs/
│       │   ├── furniture/
│       │   │   ├── FurnitureCategory.swift
│       │   │   ├── FurnitureCell.swift
│       │   │   ├── ScanFurnitureViewController.swift
│       │   │   ├── CreateModel/
│       │   │   ├── ModelsFromFiles/
│       │   │   ├── Object Capture/
│       │   │   └── roomPlanColor/
│       │   │
│       │   ├── profile/
│       │   │   ├── ProfileViewController.swift
│       │   │   ├── ProfileCell.swift
│       │   │   ├── EditProfileViewController.swift
│       │   │   └── SubScreens/
│       │   │
│       │   └── Rooms/
│       │       ├── MyRoomsViewController.swift
│       │       ├── MyRoomsViewController+helpers.swift
│       │       ├── RoomCell.swift
│       │       ├── RoomCategory.swift
│       │       ├── RoomModel.swift
│       │       ├── MetadataManager.swift
│       │       ├── furniture+room/
│       │       └── RoomPlanScan/
│       │
│       └── Onboarding/
│           ├── SplashViewController.swift
│           ├── OnboardingController.swift
│           ├── OnboardingPage.swift
│           ├── LoginViewController.swift
│           ├── SignupViewController.swift
│           ├── ForgotPasswordViewController.swift
│           ├── ModernTextField.swift
│           └── SocialButton.swift
│
└── Envision.xcodeproj/
    └── project.pbxproj
```

---

## Summary

EnVision is a well-architected iOS app with:

1. **Clear Separation**: Each feature in its own folder
2. **Singleton Managers**: Centralized data management
3. **Protocol Extensions**: Clean delegate implementations
4. **Modern UI**: Compositional layouts, context menus, SF Symbols
5. **AR/3D Integration**: RoomPlan, Object Capture, RealityKit
6. **Consistent Styling**: Centralized colors and fonts

---

*Last Updated: January 2, 2026*
