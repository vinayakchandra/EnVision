# EnVision - Complete Project Documentation

**Last Updated:** December 19, 2024

## Table of Contents

1. [Project Overview](#project-overview)
2. [App Architecture](#app-architecture)
3. [Complete File Structure](#complete-file-structure)
4. [App Flow Diagrams](#app-flow-diagrams)
5. [Screen-by-Screen Documentation](#screen-by-screen-documentation)
6. [Features & Functionality](#features--functionality)
7. [Data Management](#data-management)
8. [Extensions & Utilities](#extensions--utilities)
9. [3D Models & Assets](#3d-models--assets)
10. [Button Reference Guide](#button-reference-guide)

---

## Project Overview

**EnVision** is an iOS application that allows users to:
- **Scan rooms** using Apple's RoomPlan API to create 3D parametric models
- **Capture furniture** using Object Capture (Photogrammetry) technology
- **Visualize furniture** in scanned rooms using AR
- **Manage 3D models** (import, export, categorize, view in AR)
- **User authentication** with local persistence

**Tagline:** *"See it in your space, before you buy it."*

### Core Technologies
- **Swift / UIKit** - Programmatic UI (no Storyboards)
- **RoomPlan API** - Room structure scanning and 3D geometry capture
- **Object Capture (Photogrammetry)** - Converting photos into 3D furniture models
- **ARKit** - Augmented reality visualization and placement
- **RealityKit** - AR scene management and entity manipulation
- **QuickLook** - 3D model preview and thumbnails
- **AVFoundation** - Camera access and capture
- **UserDefaults & FileManager** - Local data persistence

### Minimum Requirements
- iOS 16.0+
- iPhone with LiDAR sensor (required for RoomPlan)
- A12 Bionic chip or later (required for Object Capture)
- Camera and Photo Library permissions

---

## App Architecture

### Entry Points

| File | Purpose |
|------|---------|
| `AppDelegate.swift` | Application lifecycle, scene configuration |
| `SceneDelegate.swift` | Window setup, root view controller management, theme handling |

### Navigation Structure (Hierarchy)

```
App Launch
    │
    └── SplashViewController (animated logo)
            │
            └── OnboardingController (3 swipeable pages)
                    │
                    └── LoginViewController
                            │
                            ├── SignupViewController
                            │
                            ├── ForgotPasswordViewController
                            │
                            └── MainTabBarController (3 tabs)
                                    │
                                    ├── Tab 1: MyRoomsViewController
                                    │
                                    ├── Tab 2: ScanFurnitureViewController
                                    │
                                    └── Tab 3: ProfileViewController
```

### App Lifecycle
1. **App Launch** → `AppDelegate` → `SceneDelegate`
2. **SceneDelegate** sets initial root view controller to `SplashViewController`
3. **Splash** displays logo with animation, then transitions to `OnboardingController`
4. **Onboarding** shows 3 pages explaining app features
5. **Login/Signup** authenticates user (local-only storage)
6. **Main App** presents tab bar with 3 main sections

---

## Workflow & User Journey

### 1. Initial Launch & Onboarding

#### SplashViewController
- **File**: `Envision/Screens/Onboarding/SplashViewController.swift`
- **Purpose**: App entry point with branded launch screen
- **Features**:
  - Displays EnVision logo and tagline
  - Smooth scale-up animation with spring damping
  - Auto-navigates to onboarding after animation completes
- **Duration**: ~2 seconds

#### OnboardingController
- **File**: `Envision/Screens/Onboarding/OnboardingController.swift`
- **Purpose**: Educational walkthrough of app capabilities
- **Features**:
  - Uses `UIPageViewController` for horizontal swiping
  - 3 pages with custom `OnboardingPage` view controllers:
    1. **"Scan Your Room"** - Introduces RoomPlan scanning
    2. **"Capture Any Furniture"** - Explains Object Capture
    3. **"Visualize with Confidence"** - Shows AR visualization
  - Page control dots at bottom
  - **Skip button** (top-right) - Jumps directly to login
  - **Continue button** (bottom) - Advances to next page or login

#### OnboardingPage
- **File**: `Envision/Screens/Onboarding/OnboardingPage.swift`
- **Purpose**: Individual onboarding page template
- **UI Components**:
  - System SF Symbol icon (150x150)
  - Title label (bold, 28pt)
  - Subtitle label (16pt, 2 lines max)

### 2. Authentication Flow

#### LoginViewController
- **File**: `Envision/Screens/Onboarding/LoginViewController.swift`
- **Purpose**: User authentication (local storage only)
- **UI Components**:
  - EnVision logo and title
  - Email text field (with validation)
  - Password text field (secure entry)
  - Error label (animated fade-in)
  - **Continue button** - Validates and logs in user
  - **Forgot Password button** - Navigates to ForgotPasswordViewController
  - **Create Account button** - Navigates to SignupViewController
  - **Sign in with Apple button** (placeholder)
  - **Sign in with Google button** (placeholder)
- **Validation**:
  - Checks for empty fields
  - Validates email format using regex
  - Uses `UserManager.shared.login()` for authentication
- **Behavior**:
  - On success: Switches to `MainTabBarController` via `SceneDelegate.switchToMainApp()`
  - On failure: Displays error message
  - Return key on email field focuses password field
  - Return key on password field submits form

#### SignupViewController
- **File**: `Envision/Screens/Onboarding/SignupViewController.swift`
- **Purpose**: New user registration
- **UI Components**:
  - Name field
  - Email field
  - Password field
  - Confirm password field
  - Error label
  - **Create Account button**
  - Social signup buttons (Apple, Google)
- **Validation**:
  - All fields required
  - Email must match regex pattern
  - Password must be strong (8+ chars, 1 uppercase, 1 number)
  - Confirm password must match
- **Behavior**:
  - Creates new user via `UserManager.shared.signup()`
  - Auto-logs in user on success
  - Switches to main app

#### ForgotPasswordViewController
- **File**: `Envision/Screens/Onboarding/ForgotPasswordViewController.swift`
- **Purpose**: Password reset flow (UI only, no backend)
- **UI Components**:
  - Logo
  - Title and instructions
  - Email input field
  - **Continue button**
- **Behavior**:
  - Displays alert on continue (placeholder for email reset)

### 3. Main Application (Tab Bar)

#### MainTabBarController
- **File**: `Envision/MainTabBarController.swift`
- **Purpose**: Primary navigation container
- **Tabs**:
  1. **My Rooms** - house icon, navigates to `MyRoomsViewController`
  2. **My Furniture** - custom sofa icon, navigates to `ScanFurnitureViewController`
  3. **Profile** - person icon, navigates to `ProfileViewController`
- **Styling**:
  - Rounded top corners (30pt radius)
  - Liquid glass effect (blur with transparency)
  - Subtle shadow
  - Tint color: AppColors.accent (#478F82)

---

## Detailed Feature Documentation

### Feature Set 1: My Rooms (Room Scanning)

#### MyRoomsViewController
- **File**: `Envision/Screens/MainTabs/Rooms/MyRoomsViewController.swift`
- **Purpose**: Manage scanned room models
- **Data Source**: `Documents/roomPlan/*.usdz` files

##### Navigation Bar Buttons
- **Right Side**:
  - **Camera icon (Green)** - Starts room scanning
  - **Import icon (Blue)** - Opens document picker for USDZ imports
- **Left Side**:
  - **Ellipsis menu** with options:
    - **Select Multiple** - Enables multi-selection mode with checkmarks
    - **Delete All** - Confirms and deletes all rooms
    - **Visualize furniture** - Opens `RoomFurniture()` AR playground

##### Search & Filter
- **Search bar**: Filters rooms by filename (case-insensitive)
- **Filter chips** (horizontal scroll):
  - **All (count)** - Shows all rooms
  - **Room Type chips**: Parametric, Textured
  - **Category chips**: Living Room, Bedroom, Study Room, Office, Other

##### Collection View
- **Layout**: 2 sections
  1. **Section 0**: Horizontal scrolling filter chips
  2. **Section 1**: Grid of room cards (1 column on iPhone, 4 on iPad)
- **Room Card (RoomCell)**:
  - Thumbnail image (generated via QuickLook)
  - Room filename
  - File size (e.g., "15.2 KB")
  - Category and room type badges
  - Selection checkmark (in multi-select mode)

##### Actions per Room
- **Tap**: Opens context menu with:
  - **Quick Look** - Native 3D preview
  - **View in AR** - Places model in real space
  - **Rename** - Changes filename
  - **Edit Details** - Updates category/type metadata
  - **Share** - System share sheet
  - **Delete** - Removes file and metadata

##### Import Flow
1. User taps Import button
2. Document picker shows (allows multiple USDZ files)
3. Alert prompts for Category selection
4. Alert prompts for Room Type selection
5. Files copied to roomPlan folder with metadata

##### Metadata System
- **MetadataManager.shared** handles JSON persistence
- **RoomMetadata structure**:
  - `category`: RoomCategory enum
  - `roomType`: RoomType enum
  - `createdAt`: Date
  - `dimensions`: Optional size info
  - `tags`: Array of strings
  - `notes`: Optional description
- **Storage**: `Documents/roomPlan/rooms_metadata.json`

##### Loading States
- Blur overlay with spinner
- Loading label ("Loading rooms…", "Importing…", etc.)
- Pull-to-refresh support

#### RoomPlanScannerViewController
- **File**: `Envision/Screens/MainTabs/Rooms/RoomPlanScan/RoomPlanScannerViewController.swift`
- **Purpose**: RoomPlan scanning interface
- **Features**:
  - Uses `RoomCaptureView` for live scanning
  - Shows RoomPlan's built-in UI (instructions, progress)
  - **Save button** appears when room data captured
  - Delegates to `RoomCaptureSessionDelegate`
- **Output**: `CapturedRoom` object with 3D structure

#### RoomPreviewViewController
- **File**: `Envision/Screens/MainTabs/Rooms/RoomPlanScan/RoomPreviewViewController.swift`
- **Purpose**: Review and save scanned room
- **UI Components**:
  - Large thumbnail preview
  - Room name text field
  - Category selection button (shows picker)
  - Info card with metadata
  - **Save to My Rooms button** - Exports USDZ with metadata
  - **Export button** - System share sheet
  - **View 3D Object button** - SceneKit preview
  - **View in AR button** - QuickLook AR

##### Export Process
1. Converts `CapturedRoom` to USDZ via `room.export()`
2. Saves to temporary directory
3. Allows user to rename
4. Moves to `Documents/roomPlan/`
5. Saves metadata via MetadataManager
6. Generates thumbnail

#### RoomFurniture (AR Playground)
- **File**: `Envision/Screens/MainTabs/Rooms/furniture+room/RoomFurniture-MAIN.swift`
- **Purpose**: Experimental AR furniture placement
- **Features**:
  - Places "hall" room model automatically
  - Tap to place "chair" furniture
  - **Joystick** (bottom center) - Moves chair X/Z axes
  - **Height slider** (bottom) - Adjusts Y position
  - **Rotation slider** - Rotates chair
  - **Scale buttons** (+/-) - Increases/decreases size
- **Technologies**: ARKit + RealityKit

---

### Feature Set 2: My Furniture (Object Scanning)

#### ScanFurnitureViewController
- **File**: `Envision/Screens/MainTabs/furniture/ScanFurnitureViewController.swift`
- **Purpose**: Manage 3D furniture models
- **Data Source**: `Documents/furniture/*.usdz` files

##### Navigation Bar Buttons
- **Right Side**:
  - **Camera icon (Green)** with dropdown menu:
    - **Automatic Object Capture** - Opens `ObjectScanViewController`
    - **Create From Photos** - Opens `CreateModelViewController`
  - **Import icon (Blue)** - Document picker for USDZ imports
- **Left Side**:
  - **Ellipsis menu** with options:
    - **Select Multiple** - Multi-selection mode
    - **Delete All** - Deletes all furniture
    - **Room Geometry Playground** - Opens `VisualizeRoomViewController`
    - **Room with replaced Furniture** - Opens `RoomARWithFurnitureViewController`

##### Search & Filter
- **Search bar**: Filters by filename
- **Category chips** (horizontal scroll):
  - All (count)
  - Chairs, Tables, Storage, Beds, Lighting, Decor, Kitchen, Outdoor, Office, Electronics, Other
  - Each chip shows count and icon
  - Selected chip highlighted with accent color

##### Collection View
- **Layout**: 2 sections
  1. **Section 0**: Category chips
  2. **Section 1**: Grid of furniture cards (2 columns on iPhone, 4 on iPad)
- **Furniture Card (FurnitureCell)**:
  - Thumbnail (cached for performance)
  - Filename
  - File size
  - Category badge
  - Checkmark (in multi-select mode)

##### Actions per Furniture
- **Long press**: Context menu with:
  - **Quick Look** - 3D preview
  - **View in AR** - Place in space
  - **Change Category** - Reassign category
  - **Rename** - Update filename
  - **Share** - Export
  - **Delete** - Remove file

##### Empty State
- Displayed when no models exist
- Shows cube icon, title, and instructions
- Prompts user to scan or import

#### ObjectScanViewController (Automatic Capture)
- **File**: `Envision/Screens/MainTabs/furniture/Object Capture/ObjectScanViewController.swift`
- **Purpose**: Guided photo capture for photogrammetry
- **Features**:
  - **Instruction card** on launch with tips
  - **Flashlight toggle** (top-right)
  - **Photo counter** (top center) with quality indicator
  - **Guidance label** (bottom) - "Walk slowly around object"
  - **Auto-capture timer** - Takes photo every 1.5 seconds
  - **Finish Capture button** - Stops and processes photos

##### Capture Flow
1. User taps "Continue" on instruction card
2. Timer starts capturing photos automatically
3. Counter updates ("15 photos", "30 photos", etc.)
4. Quality indicator shows status:
   - "Keep capturing..." (Yellow, < 20 photos)
   - "Good quality!" (Orange, 20-39 photos)
   - "Excellent!" (Green, 40+ photos)
5. User taps "Finish Capture"
6. Navigates to `ObjectCapturePreviewController`

##### Storage
- Photos saved to temp folder: `TemporaryDirectory/scan-{UUID}/`
- Cleaned up after processing

#### ObjectCapturePreviewController
- **File**: `Envision/Screens/MainTabs/furniture/Object Capture/ObjectCapturePreviewController.swift`
- **Purpose**: Process captured photos into 3D model
- **Features**:
  - Shows grid of captured photos
  - **Process button** - Starts photogrammetry
  - Progress bar and percentage
  - Uses PhotogrammetrySession API
  - Allows filename input
  - Saves to furniture folder with category metadata

#### CreateModelViewController (From Photos)
- **File**: `Envision/Screens/MainTabs/furniture/CreateModel/CreateModelViewController.swift`
- **Purpose**: Import folder of photos for photogrammetry
- **Features**:
  - **Import Folder button** - Opens document picker
  - Validates folder contains images (jpg, png, heic, etc.)
  - Copies images to temp folder
  - Starts PhotogrammetrySession with configuration:
    - Feature sensitivity: High
    - Sample ordering: Sequential
    - Object masking: Enabled
  - Progress UI with percentage
  - Output: USDZ model file

##### Processing Flow
1. User selects folder from Files app
2. App filters for image files
3. Copies to temp input folder
4. Creates PhotogrammetrySession
5. Processes with `.reduced` detail level
6. Shows progress updates via async stream
7. On completion: Prompts for filename
8. Saves to furniture folder
9. Generates thumbnail

#### VisualizeRoomViewController (Geometry Playground)
- **File**: `Envision/Screens/MainTabs/furniture/roomPlanColor/VisualizeRoomViewController.swift`
- **Purpose**: Experimental room geometry visualization
- **Features**:
  - Imports USDZ room model
  - **Show Labels toggle** - Displays entity names as 3D text
  - **Enable Colors toggle** - Applies semantic colors:
    - Walls: Blue
    - Floors: Gray
    - Ceilings: Light gray
    - Doors: Brown
    - Windows: Cyan
    - Furniture: Purple
  - **Tap to select** - Opens color picker to manually recolor
  - Supports scale, rotation, translation gestures

#### RoomARWithFurnitureViewController
- **File**: `Envision/Screens/MainTabs/furniture/roomPlanColor/RoomARWithFurnitureViewController.swift`
- **Purpose**: Replace furniture in scanned rooms
- **Features**:
  - Loads room USDZ
  - Detects furniture entities
  - Allows swapping with user's furniture models
  - Real-time AR preview

---

### Feature Set 3: Profile & Settings

#### ProfileViewController
- **File**: `Envision/Screens/MainTabs/profile/ProfileViewController.swift`
- **Purpose**: User account and app settings
- **Layout**: TableView with grouped sections

##### Profile Header
- **Components**:
  - Profile image (110x110, circular)
  - Name label ("Shaurya", bold 22pt)
  - Email label ("shaurya@gmail.com", 14pt gray)
  - **Edit Profile button** (200x44, rounded)
- **Action**: Opens `EditProfileViewController` as modal sheet

##### Settings Sections

**1. Account**
- **My Profile** → EditProfileViewController
- **Email & Password** → EmailPasswordViewController

**2. Preferences**
- **Appearance** → AppearanceViewController
  - Light/Dark/System theme toggle
  - Smooth crossfade animation on change
  - Persisted in UserDefaults
- **Notifications** → NotificationsViewController
  - All Notifications toggle
  - Scan Reminders toggle
  - New Feature Alerts toggle
  - Saved in UserManager preferences

**3. Privacy & Security**
- **Privacy Controls** → PrivacyControlsViewController
  - Data sharing preferences
  - Usage analytics toggle
- **Permissions** → PermissionsViewController
  - Camera status (Allowed/Denied/Not Set)
  - Photo Library status
  - Button to open Settings

**4. About**
- **App Info** → AppInfoViewController
  - Version and build number
  - Credits and acknowledgments
- **Terms of Service** → TermsViewController
- **Privacy Policy** → PrivacyPolicyViewController

**5. Logout**
- **Sign Out** (red text)
- Shows confirmation alert
- Calls `UserManager.shared.logout()`
- Switches to LoginViewController via SceneDelegate

##### Footer
- Version label (e.g., "Version 1.0.0 (1)")

#### EditProfileViewController
- **File**: `Envision/Screens/MainTabs/profile/EditProfileViewController.swift`
- **Purpose**: Edit user details
- **UI Components**:
  - Name text field
  - Email text field
  - Bio text view (multiline)
  - **Cancel button** - Dismisses without saving
  - **Save button** - Updates UserManager and dismisses
- **Presentation**: Modal form sheet

#### PermissionsViewController
- **File**: `Envision/Screens/MainTabs/profile/SubScreens/PermissionsViewController.swift`
- **Purpose**: Display permission status
- **Features**:
  - Lists Camera and Photo Library permissions
  - Shows status with color coding:
    - Green: Allowed
    - Red: Denied
    - Orange: Not Set
  - Tap to open Settings app

---

## File Structure & Responsibilities

### Core Files

| File | Purpose | Key Features |
|------|---------|--------------|
| `AppDelegate.swift` | App lifecycle manager | Handles app launch, scene configuration |
| `SceneDelegate.swift` | Window scene manager | Sets initial view controller, theme handling, navigation switching |
| `MainTabBarController.swift` | Tab navigation | 3 tabs, liquid glass styling |

### Screens

#### Onboarding (6 files)
- `SplashViewController.swift` - Animated launch screen
- `OnboardingController.swift` - Page view controller
- `OnboardingPage.swift` - Individual page template
- `LoginViewController.swift` - Authentication
- `SignupViewController.swift` - Registration
- `ForgotPasswordViewController.swift` - Password reset

#### My Rooms (8+ files)
- `MyRoomsViewController.swift` - Main rooms list
- `RoomCell.swift` - Collection view cell
- `RoomModel.swift` - Room data structure
- `RoomCategory.swift` - Enums for categories/types
- `MetadataManager.swift` - JSON metadata persistence
- `RoomPlanScannerViewController.swift` - RoomPlan capture
- `RoomPreviewViewController.swift` - Post-scan review
- `RoomFurniture-MAIN.swift` - AR furniture placement

#### My Furniture (10+ files)
- `ScanFurnitureViewController.swift` - Main furniture list
- `FurnitureCell.swift` - Collection view cell
- `FurnitureCategory.swift` - Category enums
- `ObjectScanViewController.swift` - Auto-capture photos
- `ObjectCapturePreviewController.swift` - Process photos to 3D
- `CreateModelViewController.swift` - Import photos from folder
- `VisualizeRoomViewController.swift` - Geometry playground
- `RoomARWithFurnitureViewController.swift` - Furniture replacement
- Supporting: `ProgressRingView.swift`, `InstructionOverlay.swift`, `FeedbackBubble.swift`, `ArrowGuideView.swift`, `ARMeshExporter.swift`

#### Profile (9+ files)
- `ProfileViewController.swift` - Main settings screen
- `ProfileCell.swift` - Table view cell
- `EditProfileViewController.swift` - Edit user info
- SubScreens:
  - `AppearanceViewController.swift` - Theme selection
  - `NotificationsViewController.swift` - Notification toggles
  - `PermissionsViewController.swift` - Permission status
  - `PrivacyControlsViewController.swift` - Privacy settings
  - `EmailPasswordViewController.swift` - Update credentials
  - `AppInfoViewController.swift`, `TermsViewController.swift`, `PrivacyPolicyViewController.swift`

### Extensions

| File | Purpose |
|------|---------|
| `UserManager.swift` | User authentication and profile management |
| `UserModel.swift` | User data structure with preferences |
| `SaveManager.swift` | USDZ file operations, thumbnails, metadata |
| `UIColor+Hex.swift` | Color definitions and hex parsing |
| `Extensions.swift` | String validation (email, password) |
| `Entity+Visit.swift` | RealityKit entity traversal |

### Components

| File | Purpose |
|------|---------|
| `CustomTextField.swift` | Styled text input with padding |
| `PrimaryButton.swift` | Accent-colored button with shadow |
| `PrimaryButton1.swift` | Alternative button style |
| `ModernTextField.swift` | Text field with secure entry support |
| `SocialButton.swift` | Sign-in button for Apple/Google |

---

## Technical Components

### Data Persistence

#### UserDefaults
- User session (JSON encoded UserModel)
- Theme preference (0=light, 1=dark, 2=system)
- Notification settings
- Furniture categories per file

#### FileManager
- **Documents Directory**:
  - `roomPlan/*.usdz` - Room models
  - `roomPlan/rooms_metadata.json` - Room metadata
  - `roomPlan/thumbnails/` - Cached thumbnails
  - `furniture/*.usdz` - Furniture models
  - `furniture/thumbnails/` - Cached thumbnails
  - `profile_image.jpg` - User profile photo
- **Temporary Directory**:
  - `scan-{UUID}/` - Photos during capture
  - `photogrammetry-input-{UUID}/` - Photos for processing
  - `Model_{UUID}.usdz` - Temporary output files

### Metadata Structures

#### RoomMetadata
```swift
struct RoomMetadata: Codable {
    var category: RoomCategory       // Living Room, Bedroom, etc.
    var roomType: RoomType           // Parametric or Textured
    var createdAt: Date
    var dimensions: String?          // Optional size info
    var tags: [String]               // User-defined tags
    var notes: String?               // Description
}
```

#### FurnitureMetadata
```swift
struct FurnitureMetadata: Codable {
    var category: FurnitureCategory? // Chairs, Tables, etc.
    var furnitureType: FurnitureType? // Scanned or Imported
    var createdAt: Date
    var tags: [String]
    var notes: String?
}
```

#### UserModel
```swift
struct UserModel: Codable {
    var id: String
    var name: String
    var email: String
    var bio: String?
    var profileImagePath: String?
    var createdAt: Date
    var preferences: UserPreferences
}

struct UserPreferences: Codable {
    var notificationsEnabled: Bool
    var scanReminders: Bool
    var newFeatureAlerts: Bool
    var theme: Int // 0=light, 1=dark, 2=system
}
```

### ARKit Configuration

#### RoomPlan Scanning
```swift
let config = RoomCaptureSession.Configuration()
config.isCoachingEnabled = true
session.run(configuration: config)
```

#### Object Placement AR
```swift
let config = ARWorldTrackingConfiguration()
config.planeDetection = [.horizontal]
config.environmentTexturing = .automatic
arView.session.run(config)
```

### Photogrammetry Configuration
```swift
var config = PhotogrammetrySession.Configuration()
config.featureSensitivity = .high
config.sampleOrdering = .sequential
config.isObjectMaskingEnabled = true

let session = try PhotogrammetrySession(input: folderURL, configuration: config)
let request = PhotogrammetrySession.Request.modelFile(url: outputURL, detail: .reduced)
```

---

## Data Management

### SaveManager Operations

#### Save Model
```swift
SaveManager.shared.saveModel(
    from: sourceURL,
    type: .furniture,
    customName: "Chair",
    completion: { result in
        // Handle success/failure
    }
)
```

#### Get Saved Models
```swift
let rooms = SaveManager.shared.getSavedModels(type: .room)
let furniture = SaveManager.shared.getSavedModels(type: .furniture)
```

#### Delete Model
```swift
SaveManager.shared.deleteModel(at: url) { success in
    // Model, thumbnail, and metadata removed
}
```

#### Generate Thumbnail
```swift
SaveManager.shared.getThumbnail(for: url) { image in
    // Returns cached or generates new thumbnail
}
```

### MetadataManager Operations

#### Load All Metadata
```swift
let metadata = MetadataManager.shared.loadMetadata()
// Returns RoomsMetadata with all room metadata
```

#### Get/Update Metadata
```swift
let roomMetadata = MetadataManager.shared.getMetadata(for: "room1.usdz")

MetadataManager.shared.updateMetadata(
    for: "room1.usdz",
    metadata: RoomMetadata(...)
)
```

#### Cleanup Orphaned
```swift
MetadataManager.shared.cleanupOrphanedMetadata()
// Removes metadata for deleted files
```

---

## UI/UX Components

### Custom UI Elements

#### Filter Chips
- Horizontal scrolling collection
- Pill-shaped with icon and label
- Selected state: accent color background
- Shows count per category

#### Room/Furniture Cards
- Thumbnail (400x400, cached)
- Title label (filename)
- Subtitle (file size)
- Category badge (colored pill)
- Shadow and rounded corners
- Selection checkmark overlay

#### Loading Overlay
- Blur effect background
- Spinner (large style)
- Loading message label
- Blocks interaction

#### Empty State
- Large icon (cube)
- Title and message
- Centered vertically
- Displayed when no data

#### Toast Messages
- Black background with transparency
- White text
- Rounded corners
- Bottom-center position
- Auto-dismiss after 2 seconds

### Color Scheme
- **Accent**: #478F82 (Teal/Green)
- **Secondary**: #8B6F47 (Brown)
- **Background**: System background (adaptive)
- **Text Primary**: #2C3E50 (Dark blue-gray)
- **Text Secondary**: #7F8C8D (Gray)

### Fonts
- **App fonts** defined in `UIFont+AppFonts.swift`
- System fonts with weights: regular, medium, semibold, bold

---

## Key Workflows Summary

### 1. Scan a Room
1. Open "My Rooms" tab
2. Tap camera icon
3. Follow RoomPlan instructions (walk around room)
4. Tap "Save"
5. Review in RoomPreviewViewController
6. Enter name and select category
7. Tap "Save to My Rooms"
8. Room appears in grid with thumbnail

### 2. Scan Furniture (Auto-Capture)
1. Open "My Furniture" tab
2. Tap camera icon → "Automatic Object Capture"
3. Read instructions, tap "Continue"
4. Walk slowly around furniture item
5. Photos captured every 1.5 seconds
6. Tap "Finish Capture" when done
7. Review photos in preview
8. Tap "Process" to generate 3D model
9. Enter name and category
10. Model saved to furniture folder

### 3. Create Model from Photos
1. Open "My Furniture" tab
2. Tap camera icon → "Create From Photos"
3. Tap "Import Folder"
4. Select folder with 20+ photos
5. Wait for photogrammetry processing
6. Enter filename
7. Model saved to furniture folder

### 4. View in AR
1. Long-press any room/furniture card
2. Select "View in AR"
3. Move device to place model
4. Pinch to scale, rotate to adjust
5. Tap to finalize placement

### 5. Change Theme
1. Open "Profile" tab
2. Tap "Appearance"
3. Select Light/Dark/System
4. Theme applies with smooth animation

---

## Summary of All Buttons & Their Actions

### Navigation Bar Buttons

| Screen | Button | Action |
|--------|--------|--------|
| MyRoomsViewController | Camera (right) | Opens RoomPlanScannerViewController |
| MyRoomsViewController | Import (right) | Opens document picker for USDZ |
| MyRoomsViewController | Ellipsis (left) | Shows menu: Select Multiple, Delete All, Visualize furniture |
| ScanFurnitureViewController | Camera (right) | Shows menu: Automatic Object Capture, Create From Photos |
| ScanFurnitureViewController | Import (right) | Opens document picker for USDZ |
| ScanFurnitureViewController | Ellipsis (left) | Shows menu: Select Multiple, Delete All, Room Geometry Playground, Room with replaced Furniture |

### In-Screen Buttons

| Screen | Button | Action |
|--------|--------|--------|
| SplashViewController | (auto) | Navigates to OnboardingController |
| OnboardingController | Skip | Jumps to LoginViewController |
| OnboardingController | Continue | Next page or LoginViewController |
| LoginViewController | Continue | Validates and logs in |
| LoginViewController | Forgot Password | Navigates to ForgotPasswordViewController |
| LoginViewController | Create Account | Navigates to SignupViewController |
| LoginViewController | Sign in with Apple | (Placeholder) |
| LoginViewController | Sign in with Google | (Placeholder) |
| SignupViewController | Create Account | Validates and signs up |
| ForgotPasswordViewController | Continue | Shows reset confirmation |
| RoomPlanScannerViewController | Save | Opens RoomPreviewViewController |
| RoomPreviewViewController | Save to My Rooms | Exports USDZ with metadata |
| RoomPreviewViewController | Export | Opens share sheet |
| RoomPreviewViewController | View 3D Object | SceneKit preview |
| RoomPreviewViewController | View in AR | QuickLook AR |
| ObjectScanViewController | Flashlight toggle | Turns camera flash on/off |
| ObjectScanViewController | Finish Capture | Opens ObjectCapturePreviewController |
| ObjectCapturePreviewController | Process | Starts photogrammetry |
| CreateModelViewController | Import Folder | Opens document picker |
| ProfileViewController | Edit Profile | Opens EditProfileViewController |
| EditProfileViewController | Cancel | Dismisses without saving |
| EditProfileViewController | Save | Updates user and dismisses |
| ProfileViewController | Sign Out | Logs out and returns to login |

---

## Dependencies & Requirements

### Apple Frameworks
- UIKit
- RoomPlan
- ARKit
- RealityKit
- SceneKit
- QuickLook
- QuickLookThumbnailing
- AVFoundation
- Photos
- LocalAuthentication
- UserNotifications
- UniformTypeIdentifiers

### No External Dependencies
- All functionality built with native Apple frameworks
- No CocoaPods, SPM, or Carthage dependencies required

---

## Conclusion

EnVision is a comprehensive 3D scanning application that demonstrates advanced iOS capabilities including:
- RoomPlan API for architectural scanning
- Object Capture photogrammetry for furniture modeling
- ARKit/RealityKit for augmented reality visualization
- Complex collection view layouts with filtering
- Robust local data persistence and metadata management
- Modern iOS UI patterns with blur effects, animations, and adaptive design

The app provides a complete workflow from scanning to visualization, with extensive customization options for categorization, metadata, and appearance preferences. All features are implemented natively without external dependencies, showcasing best practices in Swift and iOS development.

---

## Complete Button Reference Guide

### Tab Bar
| Tab | Icon | Screen | Description |
|-----|------|--------|-------------|
| My Rooms | house / house.fill | `MyRoomsViewController` | View and manage scanned rooms |
| My Furniture | sofa.viewfinder (custom) | `ScanFurnitureViewController` | View and manage furniture models |
| Profile | person / person.fill | `ProfileViewController` | User settings and account |

### Splash & Onboarding

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| SplashViewController | - | Auto | After animation, navigates to OnboardingController |
| OnboardingController | "Skip" | UIButton (top-right) | Skips onboarding, goes to LoginViewController |
| OnboardingController | "Continue" | UIButton (bottom) | Goes to next page, or to Login on last page |
| OnboardingController | Page dots | UIPageControl | Shows current page (3 pages total) |

### Authentication Flow

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| LoginViewController | Email field | ModernTextField | Enter email address |
| LoginViewController | Password field | ModernTextField (secure) | Enter password |
| LoginViewController | "Continue" | PrimaryButton1 | Validates credentials, logs in |
| LoginViewController | "Forgot password?" | UIButton | Opens ForgotPasswordViewController |
| LoginViewController | "Create Account" | UIButton | Opens SignupViewController |
| LoginViewController | "Sign in with Apple" | SocialButton | Placeholder for Apple Sign-In |
| LoginViewController | "Sign in with Google" | SocialButton | Placeholder for Google Sign-In |
| SignupViewController | Name field | ModernTextField | Enter display name |
| SignupViewController | Email field | ModernTextField | Enter email |
| SignupViewController | Password field | ModernTextField (secure) | Enter password (8+ chars, 1 upper, 1 num) |
| SignupViewController | Confirm field | ModernTextField (secure) | Confirm password |
| SignupViewController | "Create Account" | PrimaryButton1 | Creates account and logs in |
| ForgotPasswordViewController | Email field | ModernTextField | Enter email for reset |
| ForgotPasswordViewController | "Continue" | PrimaryButton1 | Sends reset email (placeholder) |

### My Rooms (Tab 1)

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| MyRoomsViewController | Camera icon (green) | UIBarButtonItem | Opens RoomPlanScannerViewController |
| MyRoomsViewController | Import icon (blue) | UIBarButtonItem | Opens document picker for USDZ import |
| MyRoomsViewController | Ellipsis menu | UIBarButtonItem | Shows options menu |
| MyRoomsViewController | → Select Multiple | UIAction | Enables multi-selection mode |
| MyRoomsViewController | → Delete All | UIAction (destructive) | Deletes all rooms after confirmation |
| MyRoomsViewController | → Visualize furniture | UIAction | Opens RoomFurniture AR view |
| MyRoomsViewController | Search bar | UISearchController | Filters rooms by name |
| MyRoomsViewController | Filter chips | ChipCell collection | Filter by category/type |
| MyRoomsViewController | Room cell tap | UICollectionView | Opens RoomViewerViewController |
| MyRoomsViewController | Room cell long-press | Context menu | Shows: Quick Look, Edit Category, Edit Room Type, Rename, Share, Delete |

### Room Scanning Flow

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| RoomPlanScannerViewController | "Save" | UIButton (bottom) | Saves scan, opens RoomPreviewViewController |
| RoomPreviewViewController | Room name field | UITextField | Enter custom name |
| RoomPreviewViewController | Category button | UIButton | Shows category picker (Living Room, Bedroom, etc.) |
| RoomPreviewViewController | "💾 Save to My Rooms" | UIButton | Exports USDZ with metadata |
| RoomPreviewViewController | "View 3D Object" | UIButton | Opens RoomViewerViewController |
| RoomPreviewViewController | "View in AR" | UIButton | Opens RoomViewerViewController |
| RoomPreviewViewController | "Export" | UIButton | Shows: Save to Files, Share |

### Room Viewer

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| RoomViewerViewController | Segmented control | UISegmentedControl | Switches between Visualize and Edit mode |
| RoomVisualizeVC | "+" button | UIBarButtonItem | Opens FurniturePicker |
| RoomVisualizeVC | Pan gesture | UIPanGestureRecognizer | Rotates camera orbit |
| RoomVisualizeVC | Pinch gesture | UIPinchGestureRecognizer | Zoom in/out |
| RoomEditVC | "+" button | UIBarButtonItem | Opens FurniturePicker |
| RoomEditVC | "Show Labels" switch | UISwitch | Toggles 3D text labels |
| RoomEditVC | "Enable Colors" switch | UISwitch | Toggles semantic coloring |
| RoomEditVC | Orbit joystick | OrbitJoystick | Rotates camera |
| RoomEditVC | Pinch gesture | UIPinchGestureRecognizer | Zoom in/out |
| RoomEditVC | Tap gesture | UITapGestureRecognizer | Selects entity |

### Room AR Playground

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| RoomFurniture | Tap on floor | UITapGestureRecognizer | Places chair model |
| RoomFurniture | Joystick | Custom view | Moves chair X/Z |
| RoomFurniture | Height slider | UISlider | Moves chair Y (up/down) |
| RoomFurniture | Rotation slider | UISlider | Rotates chair |
| RoomFurniture | "➕" button | UIButton | Scales chair up |
| RoomFurniture | "➖" button | UIButton | Scales chair down |

### My Furniture (Tab 2)

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| ScanFurnitureViewController | Camera icon (green) | UIBarButtonItem | Shows dropdown menu |
| ScanFurnitureViewController | → Automatic Object Capture | UIAction | Opens ObjectScanViewController |
| ScanFurnitureViewController | → Create From Photos | UIAction | Opens CreateModelViewController |
| ScanFurnitureViewController | Import icon (blue) | UIBarButtonItem | Opens document picker for USDZ |
| ScanFurnitureViewController | Ellipsis menu | UIBarButtonItem | Shows options menu |
| ScanFurnitureViewController | → Select Multiple | UIAction | Enables multi-selection mode |
| ScanFurnitureViewController | → Delete All | UIAction (destructive) | Deletes all furniture |
| ScanFurnitureViewController | → Room Geometry Playground | UIAction | Opens VisualizeRoomViewController |
| ScanFurnitureViewController | → Room with replaced Furniture | UIAction | Opens RoomARWithFurnitureViewController |
| ScanFurnitureViewController | Search bar | UISearchController | Filters furniture by name |
| ScanFurnitureViewController | Category chips | FurnitureChipCell collection | Filter by category |
| ScanFurnitureViewController | Furniture cell tap | UICollectionView | Opens QuickLook preview |
| ScanFurnitureViewController | Furniture cell long-press | Context menu | Shows: Quick Look, View in AR, Change Category, Rename, Share, Delete |

### Object Capture Flow

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| ObjectScanViewController | Instruction card | UIView | Shows capture tips |
| ObjectScanViewController | "Continue" | UIButton | Dismisses instructions, starts capture |
| ObjectScanViewController | Flashlight toggle | UIButton | Toggles camera flash |
| ObjectScanViewController | Photo counter | UILabel | Shows "X photos" count |
| ObjectScanViewController | Quality indicator | UILabel | Shows capture quality status |
| ObjectScanViewController | Guidance label | UILabel | Shows "Walk slowly around object" |
| ObjectScanViewController | "Finish Capture" | UIButton | Stops capture, processes photos |
| ObjectCapturePreviewController | Photo grid | UICollectionView | Preview captured images |
| ObjectCapturePreviewController | "Process" | UIButton | Starts photogrammetry |
| ObjectCapturePreviewController | Progress bar | UIProgressView | Shows processing progress |
| ObjectCapturePreviewController | Name field | UITextField | Enter model name |

### Create From Photos

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| CreateModelViewController | "Import Folder" | UIBarButtonItem | Opens folder picker |
| CreateModelViewController | Progress bar | UIProgressView | Shows processing progress |
| CreateModelViewController | Progress label | UILabel | Shows percentage |

### Furniture Picker (in Room Viewer)

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| FurniturePicker | Cancel | UIBarButtonItem | Dismisses picker |
| FurniturePicker | Furniture grid | UICollectionView | Shows available furniture |
| FurniturePicker | Cell tap | UICollectionView | Selects and inserts furniture |

### Geometry Playgrounds

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| VisualizeRoomViewController | "Show Labels" switch | UISwitch | Toggles 3D entity name labels |
| VisualizeRoomViewController | "Enable Colors" switch | UISwitch | Toggles semantic coloring |
| VisualizeRoomViewController | Tap on entity | UITapGestureRecognizer | Opens color picker |
| VisualizeRoomViewController | Gestures | UIGestureRecognizer | Scale, rotate, translate models |
| RoomARWithFurnitureViewController | - | Auto | Loads room with replaced furniture |

### Profile (Tab 3)

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| ProfileViewController | Profile image | UIImageView | Displays user photo |
| ProfileViewController | "Edit Profile" | UIButton | Opens EditProfileViewController |
| ProfileViewController | "My Profile" row | UITableViewCell | Opens EditProfileViewController |
| ProfileViewController | "Email & Password" row | UITableViewCell | Opens EmailPasswordViewController |
| ProfileViewController | "Appearance" row | UITableViewCell | Opens AppearanceViewController |
| ProfileViewController | "Notifications" row | UITableViewCell | Opens NotificationsViewController |
| ProfileViewController | "Privacy Controls" row | UITableViewCell | Opens PrivacyControlsViewController |
| ProfileViewController | "Permissions" row | UITableViewCell | Opens PermissionsViewController |
| ProfileViewController | "App Info" row | UITableViewCell | Opens AppInfoViewController |
| ProfileViewController | "Terms of Service" row | UITableViewCell | Opens TermsViewController |
| ProfileViewController | "Privacy Policy" row | UITableViewCell | Opens PrivacyPolicyViewController |
| ProfileViewController | "Sign Out" row | UITableViewCell (destructive) | Shows confirmation, logs out |

### Profile Sub-Screens

| Screen | Element | Type | Action |
|--------|---------|------|--------|
| EditProfileViewController | "Cancel" | UIBarButtonItem | Dismisses without saving |
| EditProfileViewController | "Save" | UIBarButtonItem | Saves changes, dismisses |
| EditProfileViewController | Name field | UITextField | Edit display name |
| EditProfileViewController | Email field | UITextField | Edit email |
| EditProfileViewController | Bio field | UITextView | Edit bio text |
| AppearanceViewController | Theme control | UISegmentedControl | Light / Dark / System |
| NotificationsViewController | All Notifications | UISwitch | Master toggle |
| NotificationsViewController | Scan Reminders | UISwitch | Reminder toggle |
| NotificationsViewController | New Feature Alerts | UISwitch | Updates toggle |
| PermissionsViewController | Camera row | UITableViewCell | Shows status, taps opens Settings |
| PermissionsViewController | Photo Library row | UITableViewCell | Shows status, taps opens Settings |

---

## Enums Reference

### RoomCategory
```swift
enum RoomCategory: String, Codable, CaseIterable {
    case livingRoom = "Living Room"   // sofa.fill, orange
    case bedroom = "Bedroom"          // bed.double.fill, purple
    case studyRoom = "Study Room"     // books.vertical.fill, blue
    case office = "Office"            // briefcase.fill, green
    case other = "Other"              // questionmark.folder.fill, gray
}
```

### RoomType
```swift
enum RoomType: String, Codable, CaseIterable {
    case parametric = "Parametric"    // cube.transparent, teal - RoomPlan API
    case textured = "Textured"        // photo.fill.on.rectangle.fill, pink - Object Capture
}
```

### FurnitureCategory
```swift
enum FurnitureCategory: String, Codable, CaseIterable {
    case seating = "Chairs"           // chair.fill, blue
    case tables = "Tables"            // table.furniture.fill, orange
    case storage = "Storage"          // cabinet.fill, purple
    case beds = "Beds"                // bed.double.fill, indigo
    case lighting = "Lighting"        // lamp.floor.fill, yellow
    case decor = "Decor"              // photo.artframe, pink
    case kitchen = "Kitchen"          // refrigerator.fill, teal
    case outdoor = "Outdoor"          // tree.fill, green
    case office = "Office"            // desktopcomputer, brown
    case electronics = "Electronics"  // tv.fill, cyan
    case other = "Other"              // shippingbox.fill, gray
}
```

### FurnitureType
```swift
enum FurnitureType: String, Codable, CaseIterable {
    case scanned = "Scanned"          // camera.viewfinder, green - Object Capture
    case imported = "Imported"        // square.and.arrow.down.fill, blue - From Files
}
```

---

## File Quick Reference

### Files by Feature

| Feature | Files |
|---------|-------|
| **App Entry** | `AppDelegate.swift`, `SceneDelegate.swift`, `MainTabBarController.swift` |
| **Onboarding** | `SplashViewController.swift`, `OnboardingController.swift`, `OnboardingPage.swift` |
| **Authentication** | `LoginViewController.swift`, `SignupViewController.swift`, `ForgotPasswordViewController.swift` |
| **Room Management** | `MyRoomsViewController.swift`, `RoomCell.swift`, `MetadataManager.swift`, `RoomCategory.swift` |
| **Room Scanning** | `RoomPlanScannerViewController.swift`, `RoomPreviewViewController.swift` |
| **Room Viewing** | `RoomViewerViewController.swift`, `RoomVisualizeVC.swift`, `RoomEditVC.swift` |
| **AR Playground** | `RoomFurniture-MAIN.swift`, `VisualizeRoomViewController.swift`, `RoomARWithFurnitureViewController.swift` |
| **Furniture Management** | `ScanFurnitureViewController.swift`, `FurnitureCell.swift`, `FurnitureCategory.swift` |
| **Object Capture** | `ObjectScanViewController.swift`, `ObjectCapturePreviewController.swift` |
| **From Photos** | `CreateModelViewController.swift`, `CreateModelViewController2.swift` |
| **Profile** | `ProfileViewController.swift`, `ProfileCell.swift`, `EditProfileViewController.swift` |
| **Settings** | `AppearanceViewController.swift`, `NotificationsViewController.swift`, `PermissionsViewController.swift` |
| **Data** | `UserManager.swift`, `UserModel.swift`, `SaveManager.swift` |
| **UI Components** | `ModernTextField.swift`, `SocialButton.swift`, `PrimaryButton.swift`, `OrbitJoystick.swift` |
| **Utilities** | `Extensions.swift`, `UIColor+Hex.swift`, `UIFont+AppFonts.swift`, `Entity+Visit.swift` |

---

*Documentation generated: December 19, 2024*
*EnVision iOS App - Version 1.0*
