# EnVision - Project Workflow Documentation

## Overview
EnVision is an iOS AR/3D visualization app that enables users to:
- Scan and capture 3D models of furniture using photogrammetry
- Scan rooms using Apple's RoomPlan API
- Visualize and place furniture in rooms
- Manage saved 3D models and room scans

---

## Project Structure

```
Envision/
├── AppDelegate.swift           # App lifecycle
├── SceneDelegate.swift         # Window/Scene setup, navigation root
├── MainTabBarController.swift  # Main tab bar with 3 tabs
├── ViewController.swift        # Base view controller
│
├── 3D_Models/                  # Sample USDZ models
│
├── Assets.xcassets/            # App assets (icons, images)
│
├── Components/                 # Reusable UI components
│   ├── CustomTextField.swift
│   ├── PrimaryButton.swift
│   └── PrimaryButton1.swift
│
├── Extensions/                 # Helper extensions
│   ├── Entity+Visit.swift      # RealityKit entity traversal
│   ├── Extensions.swift        # General extensions
│   ├── SaveManager.swift       # Model saving/loading
│   ├── UIColor+Hex.swift       # Hex color support
│   ├── UIFont+AppFonts.swift   # Custom fonts
│   ├── UIViewController+Transition.swift
│   ├── UserManager.swift       # User session management
│   └── UserModel.swift         # User data model
│
├── Managers/
│   ├── BackgroundModelProcessor.swift  # Background photogrammetry processing
│   └── TourManager.swift               # App tour/tips management
│
├── Tips/                       # TipKit integration
│   ├── AppTips.swift
│   └── TipPresenter.swift
│
└── Screens/
    ├── Onboarding/             # Login/signup flow
    │   ├── SplashViewController.swift
    │   ├── OnboardingController.swift
    │   ├── OnboardingPage.swift
    │   ├── LoginViewController.swift
    │   ├── SignupViewController.swift
    │   ├── ForgotPasswordViewController.swift
    │   ├── ModernTextField.swift
    │   └── SocialButton.swift
    │
    └── MainTabs/
        ├── Rooms/              # Room scanning & visualization
        │   ├── MyRoomsViewController.swift
        │   ├── RoomCell.swift
        │   ├── RoomModel.swift
        │   ├── MetadataManager.swift
        │   ├── RoomPlanScan/
        │   │   ├── RoomPlanScannerViewController.swift
        │   │   └── RoomPreviewViewController.swift
        │   └── furniture+room/
        │       ├── RoomViewerViewController.swift
        │       ├── RoomEditVC.swift
        │       ├── RoomVisualizeVC.swift
        │       ├── FurniturePicker.swift
        │       ├── FurnitureControlPanel.swift
        │       └── OrbitJoystick.swift
        │
        ├── furniture/          # Furniture/object capture
        │   ├── ScanFurnitureViewController.swift
        │   ├── FurnitureCategory.swift
        │   ├── FurnitureCell.swift
        │   ├── CreateModel/
        │   │   ├── CreateModelViewController.swift
        │   │   └── CreateModelViewController2.swift
        │   ├── ModelsFromFiles/
        │   │   ├── ViewModelsViewController.swift
        │   │   └── USDZCell.swift
        │   ├── Object Capture/
        │   │   ├── ObjectScanViewController.swift
        │   │   ├── ObjectCapturePreviewController.swift  # Photo preview & processing
        │   │   ├── ARMeshExporter.swift
        │   │   ├── ArrowGuideView.swift
        │   │   ├── FeedbackBubble.swift
        │   │   ├── InstructionOverlay.swift
        │   │   └── ProgressRingView.swift
        │   └── roomPlanColor/
        │       ├── RoomARView 1.swift
        │       ├── RoomARView 2.swift
        │       ├── RoomARWithFurnitureViewController.swift
        │       └── VisualizeRoomViewController.swift
        │
        └── profile/            # User settings
            ├── ProfileViewController.swift
            ├── ProfileCell.swift
            ├── EditProfileViewController.swift
            └── SubScreens/
                ├── AppearanceViewController.swift
                ├── AppInfoViewController.swift
                ├── EmailPasswordViewController.swift
                ├── NotificationsViewController.swift
                ├── PermissionsViewController.swift
                ├── PrivacyControlsViewController.swift
                ├── PrivacyPolicyViewController.swift
                ├── TermsViewController.swift
                └── TipsLibraryViewController.swift
```

---

## Application Flow

### 1. App Launch
```
AppDelegate → SceneDelegate → SplashViewController
```

### 2. Onboarding Flow
```
SplashViewController
    ↓
OnboardingController (first launch)
    ↓
LoginViewController ←→ SignupViewController
                    ↔ ForgotPasswordViewController
    ↓
MainTabBarController
```

### 3. Main App (Tab Bar)
```
MainTabBarController
├── Tab 1: My Rooms (MyRoomsViewController)
├── Tab 2: My Furniture (ScanFurnitureViewController)
└── Tab 3: Profile (ProfileViewController)
```

---

## Feature Workflows

### Room Scanning Flow
```
MyRoomsViewController
    ↓ (Scan button)
RoomPlanScannerViewController (Uses RoomPlan API)
    ↓ (Capture complete)
RoomPreviewViewController (Preview & save)
    ↓ (Save)
MyRoomsViewController (Updated list)
    ↓ (Select room)
RoomViewerViewController / RoomEditVC
    ↓ (Add furniture)
FurniturePicker → RoomVisualizeVC
```

### Furniture/Object Capture Flow
```
ScanFurnitureViewController
    ↓ (Automatic Object Capture)
ObjectScanViewController (Camera capture)
    ↓ (Photos captured)
ObjectCapturePreviewController
    ↓ (Generate 3D Model - uses BackgroundModelProcessor)
    ↓ (Processing happens in background)
    ↓ (Model saved via SaveManager)
ScanFurnitureViewController (Updated list)
    ↓ (View model)
QuickLook Preview
```

### Background Processing (Key Feature)
```
ObjectCapturePreviewController
    ↓ startProcessing()
BackgroundModelProcessor.shared.startProcessing()
    ↓
    ├── Creates PhotogrammetrySession
    ├── Registers UIBackgroundTask for extended processing
    ├── Processes images → 3D model
    ├── Updates progress via callbacks
    ├── Sends local notification on completion
    └── Saves model via SaveManager
```

---

## Key Components

### BackgroundModelProcessor
**Purpose**: Enables 3D model generation to continue even when user leaves the screen.

**Features**:
- Background task registration for extended processing
- Thread-safe progress tracking
- Callback-based UI updates
- Local notifications for completion
- Cancellation support

**Usage**:
```swift
BackgroundModelProcessor.shared.startProcessing(
    imagesFolder: imagesFolderURL,
    detailLevel: .reduced
) { result in
    switch result {
    case .success(let savedURL):
        // Model saved successfully
    case .failure(let error):
        // Handle error
    }
}
```

### SaveManager
**Purpose**: Handles saving and loading 3D models and room data.

**Locations**:
- Furniture: `Documents/Furniture/`
- Rooms: `Documents/Rooms/`
- Thumbnails: Cached separately

### MetadataManager
**Purpose**: Manages room metadata (names, dates, categories).

---

## Technologies Used

- **RealityKit**: 3D rendering and AR
- **ARKit**: Augmented reality sessions
- **RoomPlan**: Room scanning (iOS 16+)
- **PhotogrammetrySession**: Object capture (iOS 17+)
- **QuickLook**: 3D model preview
- **TipKit**: User tips and tours

---

## Error Fixed (January 27, 2026)

### Issue
`PhotogrammetrySession.Request.Detail` enum in iOS 26 SDK doesn't have `.preview`, `.medium`, or `.full` members.

### Files Modified
1. `ObjectCapturePreviewController.swift`
   - Line 178: Changed `.preview` to `.reduced`
   - Lines 227-233: Changed all detail levels to `.reduced`

2. `BackgroundModelProcessor.swift`
   - Wrapped async calls with `await MainActor.run { }` to fix Swift 6 concurrency warnings

### Build Status
✅ BUILD SUCCEEDED

---

## Notes for Future Development

1. **Detail Levels**: The quality selector UI shows "Fast", "Balanced", "High Quality" but all map to `.reduced`. When newer SDK versions provide more options, update `updateQualityDescription()`.

2. **Swift 6 Compatibility**: Main actor isolation warnings were fixed in BackgroundModelProcessor. Monitor other files with similar warnings.

3. **Deprecated APIs**: Several iOS 26 deprecation warnings exist (UIScreen.main, UIBarButtonItem.Style.done). Address these for full iOS 26 compatibility.

---

## Recent Updates (January 27, 2026)

### Color Persistence Feature
Added the ability to save and restore colors when switching between Edit and Visualize modes.

**New Files:**
- `Managers/RoomColorManager.swift` - Singleton manager for persisting room element colors

**Modified Files:**
- `RoomEditVC.swift` - Now saves colors to RoomColorManager when changed
- `RoomVisualizeVC.swift` - Now loads and applies saved colors when loading room

**How It Works:**
1. User changes color in Edit mode using the color picker
2. Color is automatically saved to `Documents/RoomColors/{roomName}_colors.json`
3. When switching to Visualize mode, saved colors are loaded and applied
4. Colors persist across app restarts

**Supported Element Types:**
- Walls, Floors, Doors, Windows, Tables, Chairs, Storage

### Color Picker UI Improvements
- Added native "Cancel" and "Done" buttons to the color picker navigation bar
- Cancel button restores previous colors
- Done button confirms the color selection

### Material Resolution Warnings
The warnings about "Could not resolve material name 'engine:BuiltinRenderGraphResources/AR/...'" are RealityKit internal warnings in the iOS Simulator. They don't affect functionality and typically don't appear on physical devices.

