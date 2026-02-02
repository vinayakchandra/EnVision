# EnVision - Complete Project Documentation
### Comprehensive Technical Reference
**Version**: 1.0  
**Last Updated**: January 30, 2026  
**Platform**: iOS 16.0+  
**Language**: Swift 5.9+  
**Architecture**: UIKit (100% Programmatic)

---

## 📋 Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture & Project Structure](#2-architecture--project-structure)
3. [App Entry Points](#3-app-entry-points)
4. [Main Tab Bar Controller](#4-main-tab-bar-controller)
5. [Tab 1: My Rooms Module](#5-tab-1-my-rooms-module)
6. [Tab 2: My Furniture Module](#6-tab-2-my-furniture-module)
7. [Tab 3: Profile Module](#7-tab-3-profile-module)
8. [Manager Classes](#8-manager-classes)
9. [Extension Files](#9-extension-files)
10. [Reusable Components](#10-reusable-components)
11. [Data Models](#11-data-models)
12. [Data Flow & Workflows](#12-data-flow--workflows)
13. [File Storage Structure](#13-file-storage-structure)
14. [Key Features Implementation](#14-key-features-implementation)

---

## 1. Project Overview

### 1.1 What is EnVision?

EnVision is an iOS AR/3D visualization application that enables users to:
- **Scan rooms** using Apple's RoomPlan API (LiDAR)
- **Scan furniture/objects** using Object Capture (Photogrammetry)
- **Visualize and edit** 3D models with color customization
- **Place virtual furniture** into scanned rooms
- **Manage a personal library** of 3D room and furniture models

### 1.2 Core Technologies Used

| Technology | Purpose |
|------------|---------|
| **RoomPlan** | 3D room scanning using LiDAR |
| **RealityKit** | 3D rendering and AR experiences |
| **ARKit** | Augmented reality foundation |
| **PhotogrammetrySession** | Object capture from photos |
| **QuickLook** | 3D model preview (USDZ) |
| **AVFoundation** | Camera capture for object scanning |

### 1.3 Project Statistics

- **Total Swift Files**: ~72 files
- **Total Lines of Code**: ~13,500 lines
- **UI Framework**: 100% programmatic UIKit (no Storyboards)
- **Architecture Pattern**: MVC with Singleton Managers

---

## 2. Architecture & Project Structure

```
EnVision/
├── AppDelegate.swift              # App lifecycle entry point
├── SceneDelegate.swift            # Window/scene management
├── MainTabBarController.swift     # Main tab bar (3 tabs)
├── ViewController.swift           # Unused placeholder
├── Info.plist                     # App configuration
│
├── 3D_Models/                     # Bundled sample USDZ models
│   ├── chair.usdz
│   ├── hall.usdz
│   ├── ios_room.usdz
│   ├── ios_room1.usdz
│   └── table.usdz
│
├── Assets.xcassets/               # Images, icons, colors
│   ├── AppIcon.appiconset/
│   ├── envision.imageset/
│   └── google_icon.imageset/
│
├── Base.lproj/
│   └── LaunchScreen.storyboard    # Only storyboard (launch screen)
│
├── Components/                    # Reusable UI components
│   ├── CustomTextField.swift
│   ├── PrimaryButton.swift
│   └── PrimaryButton1.swift
│
├── Extensions/                    # Swift extensions & utilities
│   ├── Entity+Visit.swift
│   ├── Extensions.swift
│   ├── SaveManager.swift
│   ├── UIColor+Hex.swift
│   ├── UIFont+AppFonts.swift
│   ├── UIViewController+Transition.swift
│   ├── UserManager.swift
│   └── UserModel.swift
│
├── Managers/                      # Singleton manager classes
│   ├── BackgroundModelProcessor.swift
│   ├── RoomColorManager.swift
│   └── TourManager.swift
│
├── Screens/
│   ├── Onboarding/               # Login/Signup flow
│   └── MainTabs/                 # Main app screens
│       ├── Rooms/                # Tab 1: My Rooms
│       ├── furniture/            # Tab 2: My Furniture
│       └── profile/              # Tab 3: Profile
│
└── Tips/                         # TipKit support (disabled)
    ├── AppTips.swift
    └── TipPresenter.swift
```

---

## 3. App Entry Points

### 3.1 AppDelegate.swift

**Location**: `/Envision/AppDelegate.swift`  
**Lines**: 38

**Purpose**: Application lifecycle management and configuration.

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `application(_:didFinishLaunchingWithOptions:)` | App startup initialization |
| `application(_:configurationForConnecting:options:)` | Scene configuration for multi-window |
| `application(_:didDiscardSceneSessions:)` | Cleanup when scenes are discarded |

**Current Implementation**: Minimal - just returns `true` on launch. Firebase integration placeholder exists.

---

### 3.2 SceneDelegate.swift

**Location**: `/Envision/SceneDelegate.swift`  
**Lines**: 108

**Purpose**: Window and scene lifecycle management, theme persistence.

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `scene(_:willConnectTo:options:)` | Creates main window, sets root view controller |
| `switchToMainApp()` | Transitions to MainTabBarController |
| `switchToLogin()` | Transitions to login flow |

#### Theme Management:
```swift
// Reads saved theme from UserDefaults
let saved = UserDefaults.standard.object(forKey: "selectedTheme") as? Int
// 0 = Light, 1 = Dark, default = System
```

**Current Root**: `MainTabBarController()` (bypasses login for development)

---

## 4. Main Tab Bar Controller

### 4.1 MainTabBarController.swift

**Location**: `/Envision/MainTabBarController.swift`  
**Lines**: 55

**Purpose**: Main navigation hub with 3 tabs.

#### Tab Configuration:

| Tab | View Controller | Icon | Title |
|-----|-----------------|------|-------|
| 1 | `MyRoomsViewController` | house/house.fill | "My Rooms" |
| 2 | `ScanFurnitureViewController` | sofa.viewfinder | "My Furniture" |
| 3 | `ProfileViewController` | person/person.fill | "Profile" |

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `setupTabs()` | Configures view controllers for each tab |
| `setupLiquidGlassEffect()` | Applies frosted glass tab bar styling |

#### Visual Styling:
- Rounded corners (30pt radius)
- Blur effect background
- Shadow for depth
- Accent color tint

---

## 5. Tab 1: My Rooms Module

### 5.1 Module Overview

**Location**: `/Envision/Screens/MainTabs/Rooms/`

This module handles:
- Displaying saved room scans
- Scanning new rooms with RoomPlan
- Importing USDZ files
- Viewing/editing rooms in 3D
- Category and metadata management

---

### 5.2 MyRoomsViewController.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/MyRoomsViewController.swift`  
**Lines**: 935

**Purpose**: Main room library grid with filtering, search, and multi-select.

#### Key Properties:

| Property | Type | Purpose |
|----------|------|---------|
| `collectionView` | UICollectionView | Displays rooms in grid |
| `roomFiles` | [URL] | All room USDZ file URLs |
| `selectedCategory` | RoomCategory? | Active category filter |
| `selectedRoomType` | RoomType? | Active type filter (Parametric/Textured) |
| `thumbnailCache` | NSCache | Cached thumbnails for performance |
| `isSelectionMode` | Bool | Multi-select mode state |

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `viewDidLoad()` | Sets up UI, loads files, registers notifications |
| `setupUI()` | Configures navigation, search, collection view |
| `loadRoomFiles()` | Loads all .usdz files from Documents/roomPlan/ |
| `generateThumbnail(for:completion:)` | Creates/loads thumbnails for rooms |
| `handleThumbnailUpdate(_:)` | Responds to thumbnail update notifications |
| `scanTapped()` | Opens RoomPlanScannerViewController |
| `importTapped()` | Opens document picker for USDZ import |
| `enableMultipleSelection()` | Toggles multi-select mode |
| `confirmDeleteAll()` | Deletes all rooms with confirmation |

#### Collection View Sections:
1. **Section 0**: Horizontal chip filters (categories)
2. **Section 1**: Room cards grid

#### Notification Observers:
- `RoomThumbnailDidUpdate` - Refreshes thumbnails when colors are saved

---

### 5.3 MyRoomsViewController+helpers.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/MyRoomsViewController+helpers.swift`  
**Lines**: 384

**Purpose**: Extension with UICollectionView delegates and helper methods.

#### Key Extensions:

| Extension | Purpose |
|-----------|---------|
| `UIDocumentPickerDelegate` | Handles imported USDZ files |
| `UICollectionViewDataSource` | Provides cell data |
| `UICollectionViewDelegate` | Handles selection/interaction |
| `UISearchResultsUpdating` | Search filtering |
| `QLPreviewControllerDataSource` | QuickLook preview |

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `collectionView(_:cellForItemAt:)` | Creates chip cells and room cells |
| `collectionView(_:didSelectItemAt:)` | Opens room in RoomViewerViewController |
| `contextMenuConfiguration...` | Long-press menu (View AR, Edit, Delete, etc.) |
| `showEditCategoryDialog(for:)` | Category picker sheet |
| `showEditRoomTypeDialog(for:)` | Room type picker sheet |
| `showRenameDialog(for:)` | Rename room alert |
| `confirmDelete(url:)` | Delete confirmation |
| `quickLook(url:)` | Opens QuickLook AR preview |

---

### 5.4 MetadataManager.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/MetadataManager.swift`  
**Lines**: 187

**Purpose**: Centralized room metadata persistence (JSON file).

#### Singleton Access:
```swift
MetadataManager.shared
```

#### Storage Location:
```
Documents/roomPlan/rooms_metadata.json
```

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `loadMetadata()` | Loads/returns RoomsMetadata from JSON |
| `saveMetadata(_:)` | Saves RoomsMetadata to JSON |
| `getMetadata(for:)` | Gets metadata for specific room filename |
| `updateMetadata(for:metadata:)` | Updates single room's metadata |
| `deleteMetadata(for:)` | Removes metadata entry |
| `renameMetadata(from:to:)` | Updates filename key |
| `cleanupOrphanedMetadata()` | Removes entries for deleted files |

---

### 5.5 RoomCategory.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/RoomCategory.swift`

**Purpose**: Room category and type enums with UI properties.

#### RoomCategory Enum:
```swift
enum RoomCategory: String, CaseIterable, Codable {
    case livingRoom, bedroom, kitchen, bathroom, 
         diningRoom, office, garage, basement, other
    
    var displayName: String { ... }
    var sfSymbol: String { ... }
    var color: UIColor { ... }
}
```

#### RoomType Enum:
```swift
enum RoomType: String, CaseIterable, Codable {
    case parametric  // Geometric walls/floors
    case textured    // Photorealistic textures
    
    var displayName: String { ... }
    var description: String { ... }
    var sfSymbol: String { ... }
    var color: UIColor { ... }
}
```

---

### 5.6 RoomCell.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/RoomCell.swift`

**Purpose**: Custom collection view cell for room cards.

#### UI Elements:
- Thumbnail image view (rounded corners)
- Room name label
- File size label
- Date label
- Category badge
- Room type badge
- Selection checkbox (multi-select mode)

---

### 5.7 RoomModel.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/RoomModel.swift`

**Purpose**: Data model for captured rooms.

```swift
struct RoomModel {
    let id: UUID
    let capturedRoom: CapturedRoom  // From RoomPlan
    let thumbnail: UIImage?
    let createdAt: Date
}
```

---

### 5.8 RoomPlanScan/ (Subfolder)

#### RoomPlanScannerViewController.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/RoomPlanScan/RoomPlanScannerViewController.swift`  
**Lines**: 113

**Purpose**: Live room scanning using Apple's RoomPlan API.

#### Key Components:
- `RoomCaptureSession` - Apple's room capture engine
- `RoomCaptureView` - Live AR scanning view
- `capturedRoom` - Resulting CapturedRoom data

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `setupCaptureView()` | Adds RoomCaptureView to hierarchy |
| `startRoomCapture()` | Begins RoomPlan session |
| `captureSession(_:didUpdate:)` | Receives room updates during scan |
| `captureSession(_:didEndWith:error:)` | Handles scan completion |
| `saveTapped()` | Creates RoomModel, pushes to preview |

---

#### RoomPreviewViewController.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/RoomPlanScan/RoomPreviewViewController.swift`  
**Lines**: 550

**Purpose**: Preview scanned room before saving, with export options.

#### Key Features:
- 3D thumbnail preview
- Room name input field
- Category selector
- Save to My Rooms button
- Export USDZ button
- View 3D Object button
- View in AR button

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `exportRoomToUSDZ()` | Converts CapturedRoom to USDZ |
| `configureContent()` | Displays room info (walls, doors, etc.) |
| `saveToMyRooms()` | Saves room with metadata |
| `generateThumbnail(from:)` | Creates preview thumbnail |

---

### 5.9 furniture+room/ (Subfolder)

#### RoomViewerViewController.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/furniture+room/RoomViewerViewController.swift`  
**Lines**: 76

**Purpose**: Container for Edit/Visualize mode switching.

#### Key Features:
- Segmented control: "Visualize" | "Edit"
- Child view controller management
- Forwards navigation bar items

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `modeChanged()` | Switches between modes |
| `showVisualize()` | Shows RoomVisualizeVC |
| `showEdit()` | Shows RoomEditVC |
| `switchTo(_:)` | Swaps child view controller |

---

#### RoomEditVC.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/furniture+room/RoomEditVC.swift`  
**Lines**: 771

**Purpose**: 3D room editor with color customization.

#### Key Features:
- Non-AR 3D viewer (RealityKit)
- Color picker for room elements
- Labels for room components
- Furniture placement
- Orbit camera with joystick
- Save colored room thumbnail

#### Key Properties:

| Property | Type | Purpose |
|----------|------|---------|
| `roomURL` | URL | Path to room USDZ file |
| `arView` | ARView | 3D rendering view |
| `displayedModel` | ModelEntity? | Current room model |
| `placedFurniture` | [ModelEntity] | Added furniture models |
| `enableColors` | Bool | Color mode toggle |
| `showLabels` | Bool | Labels visibility toggle |

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `loadRoom()` | Async loads USDZ model |
| `setupScene(with:)` | Places model in scene |
| `applyMaterialRules(to:)` | Applies saved/default colors |
| `setColor(for:color:)` | Changes color for element type |
| `presentColorPicker(for:)` | Opens color picker |
| `saveColoredThumbnail()` | Captures ARView snapshot |
| `addFurnitureTapped()` | Opens FurniturePicker |
| `insertFurniture(from:)` | Adds furniture to scene |
| `setupOrbitJoystick()` | Adds camera orbit control |

#### Color Targets:
```swift
enum ColorTarget {
    case walls, doors, tables, floors, windows, storage, selected
}
```

---

#### RoomVisualizeVC.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/furniture+room/RoomVisualizeVC.swift`  
**Lines**: 432

**Purpose**: 3D room visualization with measurement tools.

#### Key Features:
- Non-AR 3D viewer
- Measurement mode (ruler tool)
- Add furniture
- Applies saved colors from RoomColorManager
- Orbit camera controls

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `loadRoom()` | Loads room USDZ |
| `applySavedColors(to:)` | Applies colors from RoomColorManager |
| `rulerTapped()` | Toggles measurement mode |
| `showMeasurementInstructions()` | Displays measurement UI |
| `addFurnitureTapped()` | Opens furniture picker |

---

#### FurniturePicker.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/furniture+room/FurniturePicker.swift`  
**Lines**: 269

**Purpose**: Modal picker to select furniture from library.

#### Key Features:
- Grid of saved furniture models
- Thumbnail preview
- Callback when model selected

#### Callback:
```swift
var onModelSelected: ((URL) -> Void)?
```

---

#### FurnitureControlPanel.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/furniture+room/FurnitureControlPanel.swift`

**Purpose**: Transform controls for placed furniture.

#### Controls:
- Position X/Y/Z sliders
- Rotation slider
- Scale slider
- Delete button

---

#### OrbitJoystick.swift

**Location**: `/Envision/Screens/MainTabs/Rooms/furniture+room/OrbitJoystick.swift`

**Purpose**: Virtual joystick for camera orbit control.

#### Callback:
```swift
var onMove: ((Float, Float) -> Void)?  // (deltaX, deltaY)
```

---

## 6. Tab 2: My Furniture Module

### 6.1 Module Overview

**Location**: `/Envision/Screens/MainTabs/furniture/`

This module handles:
- Displaying saved furniture scans
- Scanning new objects with Object Capture
- Importing USDZ files
- Category management
- AR preview

---

### 6.2 ScanFurnitureViewController.swift

**Location**: `/Envision/Screens/MainTabs/furniture/ScanFurnitureViewController.swift`  
**Lines**: 1093

**Purpose**: Main furniture library grid with filtering and scanning options.

#### Key Properties:

| Property | Type | Purpose |
|----------|------|---------|
| `furnitureFiles` | [URL] | All furniture USDZ URLs |
| `selectedCategory` | FurnitureCategory? | Active filter |
| `thumbnailCache` | NSCache | Cached thumbnails |

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `loadFurnitureFiles(from:)` | Loads all .usdz from Documents/furniture/ |
| `automaticCaptureTapped()` | Opens ObjectScanViewController |
| `createFromPhotosTapped()` | Opens CreateModelViewController |
| `importModelTapped()` | Opens document picker |
| `getCategoryForURL(_:)` | Gets saved/inferred category |
| `inferCategory(from:)` | Guesses category from filename |

#### Menu Actions:
- **Automatic Object Capture**: Camera-based scanning
- **Create From Photos**: Import photo folder
- **Import USDZ**: File picker

---

### 6.3 FurnitureCategory.swift

**Location**: `/Envision/Screens/MainTabs/furniture/FurnitureCategory.swift`

**Purpose**: Furniture category enum with UI properties.

```swift
enum FurnitureCategory: String, CaseIterable {
    case seating, tables, storage, beds, lighting,
         decor, kitchen, outdoor, office, electronics, other
    
    var icon: String { ... }
    var color: UIColor { ... }
}
```

---

### 6.4 FurnitureCell.swift

**Location**: `/Envision/Screens/MainTabs/furniture/FurnitureCell.swift`

**Purpose**: Collection view cell for furniture items.

---

### 6.5 Object Capture/ (Subfolder)

#### ObjectScanViewController.swift

**Location**: `/Envision/Screens/MainTabs/furniture/Object Capture/ObjectScanViewController.swift`  
**Lines**: 414

**Purpose**: Automatic photo capture for object scanning.

#### Key Features:
- Camera preview with live capture
- Auto-capture timer (every 0.4s)
- Photo counter with quality indicator
- Flashlight toggle
- Guidance labels

#### Key Properties:

| Property | Type | Purpose |
|----------|------|---------|
| `session` | AVCaptureSession | Camera session |
| `photoOutput` | AVCapturePhotoOutput | Photo capture |
| `tempFolderURL` | URL | Temporary image storage |
| `images` | [URL] | Captured photo URLs |

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `setupCamera()` | Configures AVCaptureSession |
| `startAutoCapture()` | Begins 0.4s interval timer |
| `takePhoto()` | Captures single photo |
| `updateQualityIndicator()` | Updates UI based on photo count |
| `stopCapture()` | Ends capture, pushes to preview |
| `toggleFlashlight()` | Turns torch on/off |

#### Quality Thresholds:
- < 20 photos: "Keep capturing"
- 20-30 photos: "Minimum reached"
- 30-50 photos: "Good coverage"
- 50-80 photos: "Excellent!"
- 80+ photos: "Maximum coverage"

---

#### ObjectCapturePreviewController.swift

**Location**: `/Envision/Screens/MainTabs/furniture/Object Capture/ObjectCapturePreviewController.swift`  
**Lines**: 619

**Purpose**: Preview captured photos and generate 3D model.

#### Key Features:
- Photo gallery preview
- Quality level selector (Fast/Balanced/High)
- Processing progress bar
- Background processing support
- Export photos to Files

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `loadImages()` | Loads captured images from folder |
| `startProcessing()` | Begins photogrammetry processing |
| `setupBackgroundProcessingCallbacks()` | Connects to BackgroundModelProcessor |
| `handleProcessingComplete(savedURL:)` | Success handler |
| `handleError(message:)` | Error handler |
| `exportPhotos()` | Saves photos to Files app |
| `retakePhotos()` | Goes back to capture |

---

### 6.6 CreateModel/ (Subfolder)

#### CreateModelViewController.swift

**Location**: `/Envision/Screens/MainTabs/furniture/CreateModel/CreateModelViewController.swift`  
**Lines**: 313

**Purpose**: Create 3D model from imported photo folder.

#### Key Features:
- Import folder of images
- Photogrammetry processing
- Progress UI

---

### 6.7 ModelsFromFiles/ (Subfolder)

#### ViewModelsViewController.swift

**Location**: `/Envision/Screens/MainTabs/furniture/ModelsFromFiles/ViewModelsViewController.swift`  
**Lines**: 432

**Purpose**: Browse and import USDZ models from Files.

---

### 6.8 roomPlanColor/ (Subfolder)

*Legacy/experimental view controllers for room visualization with colors.*

| File | Purpose |
|------|---------|
| `RoomARView 1.swift` | Basic AR room view |
| `RoomARView 2.swift` | (Commented out) |
| `RoomARWithFurnitureViewController.swift` | Room with furniture placeholders |
| `VisualizeRoomViewController.swift` | Room geometry playground |

---

## 7. Tab 3: Profile Module

### 7.1 Module Overview

**Location**: `/Envision/Screens/MainTabs/profile/`

This module handles:
- User profile display/editing
- App settings and preferences
- Theme selection
- Privacy controls
- App information

---

### 7.2 ProfileViewController.swift

**Location**: `/Envision/Screens/MainTabs/profile/ProfileViewController.swift`  
**Lines**: 318

**Purpose**: Main profile screen with settings table.

#### Sections:

| Section | Items |
|---------|-------|
| **Account** | My Profile, Email & Password |
| **Preferences** | Appearance, Notifications |
| **Privacy & Security** | Privacy Controls, Permissions |
| **About** | Tips, App Tour, App Info, Terms, Privacy Policy |
| **Logout** | Sign Out |

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `setupProfileHeader()` | Creates profile image and info |
| `tableView(_:didSelectRowAt:)` | Handles menu item taps |
| `handleLogout()` | Signs out user |
| `reloadProfileHeader()` | Refreshes profile data |

---

### 7.3 EditProfileViewController.swift

**Location**: `/Envision/Screens/MainTabs/profile/EditProfileViewController.swift`

**Purpose**: Edit profile name, email, bio, and photo.

---

### 7.4 ProfileCell.swift

**Location**: `/Envision/Screens/MainTabs/profile/ProfileCell.swift`

**Purpose**: Custom table cell for settings items.

---

### 7.5 SubScreens/ (Subfolder)

| File | Purpose |
|------|---------|
| `AppearanceViewController.swift` | Theme selection (Light/Dark/System) |
| `NotificationsViewController.swift` | Notification preferences |
| `PermissionsViewController.swift` | Camera, microphone, location permissions |
| `PrivacyControlsViewController.swift` | Privacy settings |
| `PrivacyPolicyViewController.swift` | Privacy policy display |
| `TermsViewController.swift` | Terms of service |
| `EmailPasswordViewController.swift` | Email/password change |
| `AppInfoViewController.swift` | App version, build info |
| `TipsViewController.swift` | Tips and tutorials |
| `SecurityViewController.swift` | Security settings |

---

## 8. Manager Classes

### 8.1 BackgroundModelProcessor.swift

**Location**: `/Envision/Managers/BackgroundModelProcessor.swift`  
**Lines**: 435

**Purpose**: Background 3D model generation from photos.

#### Singleton Access:
```swift
BackgroundModelProcessor.shared
```

#### Key Properties:

| Property | Type | Purpose |
|----------|------|---------|
| `isProcessing` | Bool | Current processing state |
| `currentProgress` | Float | Processing progress (0-1) |
| `currentStatus` | String | Human-readable status |
| `onProgressUpdate` | Closure? | Progress callback |
| `onCompletion` | Closure? | Success callback |
| `onError` | Closure? | Error callback |

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `startProcessing(imagesFolder:detailLevel:completion:)` | Begins photogrammetry |
| `processPhotogrammetry(...)` | Core processing logic |
| `beginBackgroundTask()` | Registers UIBackgroundTask |
| `updateProgress(_:status:)` | Updates state and notifies |
| `saveGeneratedModel(_:completion:)` | Saves to Documents/furniture/ |
| `sendCompletionNotification(success:)` | Local notification |
| `cancelProcessing()` | Cancels current job |

#### ProcessingJob Model:
```swift
struct ProcessingJob: Codable, Identifiable {
    let id: UUID
    let imagesFolder: String
    let outputFileName: String
    let createdAt: Date
    var status: ProcessingStatus
    var progress: Float
    var errorMessage: String?
}
```

---

### 8.2 RoomColorManager.swift

**Location**: `/Envision/Managers/RoomColorManager.swift`  
**Lines**: 175

**Purpose**: Persists custom colors for room elements.

#### Singleton Access:
```swift
RoomColorManager.shared
```

#### Storage Location:
```
Documents/RoomColors/{roomName}_colors.json
```

#### Element Type Keys:
```swift
static let wallKey = "wall"
static let floorKey = "floor"
static let doorKey = "door"
static let windowKey = "window"
static let tableKey = "table"
static let chairKey = "chair"
static let storageKey = "storage"
```

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `saveColor(_:for:roomURL:)` | Saves color for element type |
| `getColor(for:roomURL:)` | Gets saved color |
| `getAllColors(for:)` | Gets all colors for room |
| `clearColors(for:)` | Removes all saved colors |
| `saveThumbnail(_:for:)` | Saves colored room thumbnail |
| `thumbnailURL(for:)` | Gets thumbnail file path |

---

### 8.3 TourManager.swift

**Location**: `/Envision/Managers/TourManager.swift`

**Purpose**: App tour/onboarding flow management.

---

## 9. Extension Files

### 9.1 SaveManager.swift

**Location**: `/Envision/Extensions/SaveManager.swift`  
**Lines**: 279

**Purpose**: Centralized model saving for furniture and rooms.

#### Singleton Access:
```swift
SaveManager.shared
```

#### ModelType Enum:
```swift
enum ModelType {
    case furniture  // Documents/furniture/
    case room       // Documents/roomPlan/
}
```

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `saveModel(from:type:customName:completion:)` | Copies USDZ to app storage |
| `deleteModel(at:completion:)` | Removes model file |
| `getFolderURL(for:)` | Gets storage folder path |
| `generateFileName(originalName:type:)` | Creates unique filename |
| `generateAndSaveThumbnail(for:type:)` | Creates model thumbnail |

---

### 9.2 UserManager.swift

**Location**: `/Envision/Extensions/UserManager.swift`  
**Lines**: 161

**Purpose**: User authentication and profile management.

#### Singleton Access:
```swift
UserManager.shared
```

#### Key Properties:

| Property | Type | Purpose |
|----------|------|---------|
| `currentUser` | UserModel? | Current logged-in user |
| `isLoggedIn` | Bool | Login state |

#### Key Functions:

| Function | Purpose |
|----------|---------|
| `login(email:password:completion:)` | Simulated login |
| `signup(name:email:password:completion:)` | Creates new user |
| `logout()` | Clears user data |
| `updateProfile(name:email:bio:)` | Updates user info |
| `saveProfileImage(_:)` | Saves profile photo |
| `loadProfileImage()` | Loads profile photo |
| `setTheme(_:)` | Sets app theme |

---

### 9.3 UserModel.swift

**Location**: `/Envision/Extensions/UserModel.swift`

**Purpose**: User data model.

```swift
struct UserModel: Codable {
    var name: String
    var email: String
    var bio: String?
    var profileImagePath: String?
    var preferences: UserPreferences
    var createdAt: Date
}

struct UserPreferences: Codable {
    var notificationsEnabled: Bool
    var scanReminders: Bool
    var newFeatureAlerts: Bool
    var theme: Int  // 0=Light, 1=Dark, 2=System
}
```

---

### 9.4 UIColor+Hex.swift

**Location**: `/Envision/Extensions/UIColor+Hex.swift`

**Purpose**: Hex color conversion utilities.

```swift
extension UIColor {
    convenience init(hex: String) { ... }
    func toHex() -> String { ... }
}
```

---

### 9.5 UIFont+AppFonts.swift

**Location**: `/Envision/Extensions/UIFont+AppFonts.swift`

**Purpose**: App typography constants.

```swift
struct AppFonts {
    static func regular(_ size: CGFloat) -> UIFont { ... }
    static func medium(_ size: CGFloat) -> UIFont { ... }
    static func semibold(_ size: CGFloat) -> UIFont { ... }
    static func bold(_ size: CGFloat) -> UIFont { ... }
}
```

---

### 9.6 Extensions.swift

**Location**: `/Envision/Extensions/Extensions.swift`

**Purpose**: Miscellaneous utilities.

Contains:
- `AppColors` - Color constants (accent, background, textPrimary, etc.)
- UI helper extensions

---

### 9.7 Entity+Visit.swift

**Location**: `/Envision/Extensions/Entity+Visit.swift`

**Purpose**: RealityKit Entity traversal helper.

```swift
extension Entity {
    func visit(_ closure: (Entity) -> Void) {
        closure(self)
        for child in children {
            child.visit(closure)
        }
    }
}
```

---

### 9.8 UIViewController+Transition.swift

**Location**: `/Envision/Extensions/UIViewController+Transition.swift`

**Purpose**: Custom view controller transitions.

---

## 10. Reusable Components

### 10.1 CustomTextField.swift

**Location**: `/Envision/Components/CustomTextField.swift`

**Purpose**: Styled text input field.

---

### 10.2 PrimaryButton.swift

**Location**: `/Envision/Components/PrimaryButton.swift`

**Purpose**: Primary action button with styling.

---

### 10.3 PrimaryButton1.swift

**Location**: `/Envision/Components/PrimaryButton1.swift`

**Purpose**: Alternative styled button.

---

## 11. Data Models

### 11.1 RoomsMetadata

```swift
struct RoomsMetadata: Codable {
    var version: String
    var rooms: [String: RoomMetadata]  // filename -> metadata
}
```

### 11.2 RoomMetadata

```swift
struct RoomMetadata: Codable {
    var category: RoomCategory
    var roomType: RoomType
    var createdAt: Date
    var dimensions: RoomDimensions?
    var tags: [String]
    var notes: String?
}
```

### 11.3 ProcessingJob

```swift
struct ProcessingJob: Codable, Identifiable {
    let id: UUID
    let imagesFolder: String
    let outputFileName: String
    let createdAt: Date
    var status: ProcessingStatus
    var progress: Float
    var errorMessage: String?
}
```

---

## 12. Data Flow & Workflows

### 12.1 Room Scanning Workflow

```
User taps "Scan" in My Rooms
        ↓
RoomPlanScannerViewController
    - RoomCaptureView starts
    - LiDAR scans room structure
    - captureSession delegates receive updates
        ↓
User taps "Save"
        ↓
RoomPreviewViewController
    - Exports to USDZ format
    - User enters name, category
        ↓
User taps "Save to My Rooms"
        ↓
SaveManager.saveModel()
    - Copies to Documents/roomPlan/
    - Generates thumbnail
        ↓
MetadataManager.updateMetadata()
    - Saves to rooms_metadata.json
        ↓
Returns to MyRoomsViewController
    - Reloads collection view
```

### 12.2 Furniture Scanning Workflow

```
User taps "Automatic Capture"
        ↓
ObjectScanViewController
    - Camera preview starts
    - Auto-capture every 0.4s
    - Photos saved to temp folder
        ↓
User taps "Finish Capture"
        ↓
ObjectCapturePreviewController
    - Shows photo gallery
    - User selects quality level
        ↓
User taps "Generate 3D Model"
        ↓
BackgroundModelProcessor.startProcessing()
    - PhotogrammetrySession processes images
    - Progress updates via callback
    - Background task keeps processing alive
        ↓
Processing completes
        ↓
SaveManager.saveModel()
    - Copies to Documents/furniture/
    - Generates thumbnail
        ↓
Returns to ScanFurnitureViewController
```

### 12.3 Room Color Editing Workflow

```
User taps room in My Rooms
        ↓
RoomViewerViewController
    - Shows "Visualize" mode by default
        ↓
User selects "Edit" tab
        ↓
RoomEditVC
    - Loads room USDZ
    - Applies saved colors from RoomColorManager
        ↓
User taps floating menu → Change Color → Walls
        ↓
UIColorPickerViewController
    - User selects color
        ↓
colorPickerViewControllerDidSelectColor()
    - Applies to all wall entities
    - RoomColorManager.saveColor()
    - Persists to Documents/RoomColors/{name}_colors.json
        ↓
User leaves screen
        ↓
viewWillDisappear()
    - saveColoredThumbnail()
    - Captures ARView snapshot
    - Saves to Documents/RoomThumbnails/{name}_thumb.jpg
    - Posts RoomThumbnailDidUpdate notification
        ↓
MyRoomsViewController
    - Receives notification
    - Clears thumbnail cache
    - Reloads with new thumbnail
```

---

## 13. File Storage Structure

### 13.1 Documents Directory Layout

```
Documents/
├── roomPlan/                          # Room models
│   ├── rooms_metadata.json            # All room metadata
│   ├── LivingRoom_2025-01-15.usdz
│   ├── Bedroom_2025-01-16.usdz
│   └── ...
│
├── furniture/                         # Furniture models
│   ├── Furniture_2025-01-15_14-30-00.usdz
│   ├── Chair_2025-01-16.usdz
│   └── ...
│
├── RoomColors/                        # Room color settings
│   ├── LivingRoom_2025-01-15_colors.json
│   └── ...
│
├── RoomThumbnails/                    # Colored room thumbnails
│   ├── LivingRoom_2025-01-15_thumb.jpg
│   └── ...
│
└── profile_image.jpg                  # User profile photo
```

### 13.2 UserDefaults Keys

| Key | Type | Purpose |
|-----|------|---------|
| `currentUser` | Data (JSON) | Encoded UserModel |
| `selectedTheme` | Int | 0=Light, 1=Dark, 2=System |
| `furniture_category_{filename}` | String | Saved category per furniture |

---

## 14. Key Features Implementation

### 14.1 LiDAR Room Scanning

**Implementation**: Uses Apple's RoomPlan framework

**Files Involved**:
- `RoomPlanScannerViewController.swift` - Capture UI
- `RoomPreviewViewController.swift` - Export and save

**Key APIs**:
```swift
RoomCaptureSession()
RoomCaptureView()
RoomCaptureSessionDelegate
CapturedRoom.export(to:exportOptions:)
```

---

### 14.2 Object Capture (Photogrammetry)

**Implementation**: Uses RealityKit's PhotogrammetrySession

**Files Involved**:
- `ObjectScanViewController.swift` - Photo capture
- `ObjectCapturePreviewController.swift` - Preview and process
- `BackgroundModelProcessor.swift` - Background processing

**Key APIs**:
```swift
PhotogrammetrySession(input:configuration:)
PhotogrammetrySession.Request.modelFile(url:detail:)
session.process(requests:)
```

---

### 14.3 3D Model Viewing & Editing

**Implementation**: Uses RealityKit's ARView in non-AR mode

**Files Involved**:
- `RoomEditVC.swift` - Edit with colors
- `RoomVisualizeVC.swift` - View with measurements
- `OrbitJoystick.swift` - Camera control

**Key APIs**:
```swift
ARView(frame:cameraMode:.nonAR)
Entity.load(contentsOf:)
ModelEntity
SimpleMaterial(color:roughness:isMetallic:)
```

---

### 14.4 Color Persistence

**Implementation**: JSON files per room

**Files Involved**:
- `RoomColorManager.swift` - Save/load colors
- `RoomEditVC.swift` - Apply colors

**Storage Format**:
```json
{
    "wall": "#3498db",
    "floor": "#7f8c8d",
    "door": "#2ecc71"
}
```

---

### 14.5 Thumbnail Generation

**Implementation**: QuickLook + ARView snapshots

**Files Involved**:
- `MyRoomsViewController.swift` - Load thumbnails
- `RoomEditVC.swift` - Save colored thumbnails
- `SaveManager.swift` - Generate on save

**Methods**:
1. **QuickLook**: `QLThumbnailGenerator` for default thumbnails
2. **ARView Snapshot**: `arView.snapshot()` for colored rooms
3. **DrawHierarchy**: `view.drawHierarchy()` for synchronous capture

---

### 14.6 Background Processing

**Implementation**: UIBackgroundTask + Local Notifications

**Files Involved**:
- `BackgroundModelProcessor.swift`

**Key Concepts**:
```swift
UIApplication.shared.beginBackgroundTask(withName:expirationHandler:)
UNUserNotificationCenter.current().add(request:)
```

---

## Summary

EnVision is a comprehensive iOS application that leverages Apple's latest AR and 3D technologies to create an immersive room and furniture scanning experience. The codebase is well-organized with clear separation of concerns:

- **Screens**: View controllers for each feature
- **Managers**: Singleton services for business logic
- **Extensions**: Reusable utilities and helpers
- **Components**: Shared UI elements

The app uses a fully programmatic UIKit approach with no storyboards (except launch screen), making it easy to maintain and extend. Data persistence is handled through a combination of FileManager (for models and images) and UserDefaults (for user data and preferences).

---

*Documentation generated: January 30, 2026*
