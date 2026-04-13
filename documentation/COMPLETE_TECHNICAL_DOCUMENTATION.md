# EnVision - Complete Technical Documentation
*Last Updated: January 21, 2026*

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Authentication Flow](#authentication-flow)
4. [Core Features](#core-features)
5. [Data Models](#data-models)
6. [File Structure](#file-structure)
7. [Third-Party Dependencies](#third-party-dependencies)
8. [Backend Design (Firebase)](#backend-design-firebase)
9. [Tips & Tour System (REMOVED)](#tips--tour-system-removed)
10. [Key Improvements Needed](#key-improvements-needed)

---

## 1. Project Overview

**EnVision** is an iOS 17+ AR/spatial computing app that allows users to:
- Scan rooms using **RoomPlan** (LiDAR)
- Capture furniture using **photogrammetry** (Object Capture)
- View and edit 3D models in AR
- Organize rooms and furniture with categories
- Manage user profiles with preferences

**Tech Stack:**
- **Language**: Swift (UIKit programmatic, no Storyboards except LaunchScreen)
- **Frameworks**: ARKit, RealityKit, RoomPlan, AVFoundation, QuickLook
- **Persistence**: UserDefaults (currently), FileManager (3D models)
- **Planned Backend**: Firebase (Auth + Firestore + Storage)

---

## 2. Architecture

### 2.1 App Entry Flow
```
SceneDelegate (willConnectTo)
    ↓
SplashViewController (logo animation ~2s)
    ↓
OnboardingController (UIPageViewController, 3 pages)
    ↓
LoginViewController
    ↓
MainTabBarController (3 tabs)
```

**Note**: Currently no "auto-skip login" logic. Every launch goes through Splash → Onboarding → Login.

### 2.2 Navigation Structure
```
MainTabBarController
├── Tab 0: My Rooms (UINavigationController)
│   └── MyRoomsViewController
│       ├── RoomPlanScannerViewController (LiDAR scan)
│       ├── RoomPreviewViewController (save scanned room)
│       ├── RoomViewerViewController (3D viewer + furniture placement)
│       └── RoomEditVC (edit room metadata)
├── Tab 1: My Furniture (UINavigationController)
│   └── ScanFurnitureViewController
│       ├── ObjectScanViewController (auto-capture photogrammetry)
│       ├── ObjectCapturePreviewController (process images)
│       ├── CreateModelViewController (manual photo selection)
│       └── ViewModelsViewController (browse USDZ files)
└── Tab 2: Profile (UINavigationController)
    └── ProfileViewController
        ├── EditProfileViewController
        ├── TipsLibraryViewController (static tips list)
        ├── SettingsViewController
        └── ThemeViewController
```

### 2.3 Key Design Patterns
- **Programmatic UIKit**: No Interface Builder (except LaunchScreen.storyboard)
- **Singleton Managers**: `UserManager`, `SaveManager`, `TourManager`, `MetadataManager`
- **Delegate Pattern**: Used for camera capture, search, collection view
- **File-based Persistence**: USDZ models stored in Documents directory
- **JSON Metadata**: Room/furniture metadata stored as JSON files

---

## 3. Authentication Flow

### 3.1 Current Implementation (Local Only)

#### Files Involved:
- `Envision/Screens/Onboarding/LoginViewController.swift`
- `Envision/Screens/Onboarding/SignupViewController.swift`
- `Envision/Screens/Onboarding/ForgotPasswordViewController.swift`
- `Envision/Extensions/UserManager.swift`
- `Envision/Extensions/UserModel.swift`
- `Envision/SceneDelegate.swift`

#### Login Flow:
1. **UI**: `LoginViewController`
   - Email + Password fields (custom `ModernTextField`)
   - "Continue" button → `handleLogin()`
   - "Create Account" → pushes `SignupViewController`
   - "Forgot Password" → pushes `ForgotPasswordViewController`

2. **Validation**:
   - Non-empty fields
   - Valid email format (`String.isValidEmail` in `Extensions.swift`)

3. **Auth Logic** (currently simulated):
   ```swift
   UserManager.shared.login(email: String, password: String) { success in
       if success {
           SceneDelegate.shared?.switchToMainApp()
       }
   }
   ```

4. **Current Behavior**:
   - If a user exists in UserDefaults with matching email → success
   - Else creates a new user and logs in (no password verification)

#### Signup Flow:
1. **UI**: `SignupViewController`
   - Name, Email, Password, Confirm Password
   - Validates strong password (`String.isStrongPassword`)

2. **Auth Logic**:
   ```swift
   UserManager.shared.signup(name:email:password:) { success in
       if success {
           SceneDelegate.shared?.switchToMainApp()
       }
   }
   ```

3. **Current Behavior**:
   - Creates `UserModel` with provided data
   - Stores in UserDefaults as JSON (`"currentUser"` key)
   - Switches to `MainTabBarController`

#### Forgot Password Flow:
1. **UI**: `ForgotPasswordViewController`
   - Email field only
   - "Send Reset Link" button → `handleReset()`

2. **Current Behavior**:
   - Validates email format
   - Calls `AuthManager.shared.sendPasswordReset(email:)` → `Auth.auth().sendPasswordReset(withEmail:)`
   - On success: shows "Reset Email Sent" alert, then pops back to Login
   - On failure: displays Firebase error message inline

### 3.2 Session Management

**Current**:
- `UserManager.shared.currentUser` stored in `UserDefaults`
- `UserManager.shared.isLoggedIn` checks if `currentUser != nil`
- No auto-login on app launch

**Logout**:
- `UserManager.shared.logout()` clears UserDefaults
- `SceneDelegate.shared?.switchToLogin()` resets root to login

---

## 4. Core Features

### 4.1 Room Scanning (RoomPlan + LiDAR)

#### Files:
- `Envision/Screens/MainTabs/Rooms/MyRoomsViewController.swift` (main library)
- `Envision/Screens/MainTabs/Rooms/RoomPlanScan/RoomPlanScannerViewController.swift` (LiDAR scan)
- `Envision/Screens/MainTabs/Rooms/RoomPlanScan/RoomPreviewViewController.swift` (save scan)
- `Envision/Screens/MainTabs/Rooms/RoomModel.swift` (data model)
- `Envision/Screens/MainTabs/Rooms/MetadataManager.swift` (JSON persistence)

#### Flow:
1. **Scan Initiation**: `MyRoomsViewController` → "+" button → `RoomPlanScannerViewController`
2. **LiDAR Capture**: User walks around room, RoomPlan builds 3D mesh
3. **Preview**: `RoomPreviewViewController` shows captured room
4. **Save**:
   - USDZ file saved to `Documents/roomPlan/{UUID}.usdz`
   - Metadata saved to `Documents/roomPlan/rooms_metadata.json`
   - Thumbnail generated using QuickLook

#### Data Model:
```swift
struct RoomModel {
    let id: UUID
    let name: String
    var category: RoomCategory
    let createdAt: Date
    let usdzFilename: String
    var thumbnailPath: String?
}

struct RoomMetadata {
    var name: String
    var category: String
    var createdAt: String
    var dimensions: [String: Double]?
    var notes: String?
}
```

#### Categories:
- Living Room, Bedroom, Kitchen, Bathroom, Office, Dining Room, Garage, Outdoor, Other

### 4.2 Furniture Capture (Object Capture / Photogrammetry)

#### Files:
- `Envision/Screens/MainTabs/furniture/ScanFurnitureViewController.swift` (library)
- `Envision/Screens/MainTabs/furniture/Object Capture/ObjectScanViewController.swift` (auto-capture)
- `Envision/Screens/MainTabs/furniture/Object Capture/ObjectCapturePreviewController.swift` (process)
- `Envision/Screens/MainTabs/furniture/CreateModel/CreateModelViewController.swift` (manual photos)
- `Envision/Screens/MainTabs/furniture/FurnitureCategory.swift`

#### Flow:
1. **Scan Initiation**: `ScanFurnitureViewController` → Scan menu
2. **Options**:
   - **Automatic Object Capture**: `ObjectScanViewController`
     - Auto-captures photos every 0.5s while user walks around object
     - Shows counter, quality indicator, guidance
     - Minimum 20 photos (recommended 50+)
   - **Create From Photos**: `CreateModelViewController`
     - User manually selects 20-100 photos from library
     - Validates photo count and quality

3. **Processing**: `ObjectCapturePreviewController`
   - Uses `PhotogrammetrySession` (iOS 17+)
   - Generates USDZ model
   - Saves to `Documents/furniture/{UUID}.usdz`

4. **Storage**:
   - USDZ files in `Documents/furniture/`
   - Thumbnails cached in-memory

#### Categories:
- Seating, Tables, Storage, Beds, Lighting, Decor, Kitchen, Outdoor, Office, Electronics, Other

### 4.3 3D Viewing & AR Placement

#### Files:
- `Envision/Screens/MainTabs/Rooms/furniture+room/RoomViewerViewController.swift`
- `Envision/Screens/MainTabs/Rooms/furniture+room/FurniturePicker.swift`
- `Envision/Screens/MainTabs/Rooms/furniture+room/FurnitureControlPanel.swift`
- `Envision/Screens/MainTabs/Rooms/furniture+room/OrbitJoystick.swift`

#### Features:
- **RealityKit-based 3D viewer**
- **Furniture placement** via drag-and-drop
- **Transform controls**: Move, Rotate, Scale
- **Orbit camera** with joystick
- **Save/Load** placed furniture positions
- **AR Preview** (launches QuickLook AR)

### 4.4 Profile & Settings

#### Files:
- `Envision/Screens/MainTabs/profile/ProfileViewController.swift`
- `Envision/Screens/MainTabs/profile/EditProfileViewController.swift`
- `Envision/Screens/MainTabs/profile/SubScreens/SettingsViewController.swift`
- `Envision/Screens/MainTabs/profile/SubScreens/ThemeViewController.swift`
- `Envision/Screens/MainTabs/profile/SubScreens/TipsLibraryViewController.swift`

#### Features:
- **Edit Profile**: Name, Email, Bio, Profile Picture
- **Preferences**: Notifications, Scan Reminders, New Features
- **Theme**: Light, Dark, System
- **Tips & Tutorials**: Static list of all tips (not affected by TipKit removal)
- **App Tour Reset**: Resets tour state in `TourManager`
- **Logout**: Clears session and returns to login

---

## 5. Data Models

### 5.1 User Model
```swift
struct UserModel: Codable {
    let id: String
    var name: String
    var email: String
    var bio: String?
    var profileImagePath: String?
    let createdAt: Date
    var preferences: UserPreferences
}

struct UserPreferences: Codable {
    var notificationsEnabled: Bool = true
    var scanReminders: Bool = true
    var newFeatureAlerts: Bool = true
    var theme: Int = 0 // 0: System, 1: Light, 2: Dark
}
```

**Persistence**: UserDefaults (`"currentUser"` key, JSON-encoded)

### 5.2 Room Model
```swift
struct RoomModel {
    let id: UUID
    let name: String
    var category: RoomCategory
    let createdAt: Date
    let usdzFilename: String
    var thumbnailPath: String?
}

struct RoomMetadata: Codable {
    var name: String
    var category: String
    var createdAt: String
    var dimensions: [String: Double]?
    var notes: String?
}

struct RoomsMetadata: Codable {
    let version: String
    var rooms: [String: RoomMetadata] // Key = filename
}
```

**Persistence**:
- USDZ files: `Documents/roomPlan/{filename}.usdz`
- Metadata: `Documents/roomPlan/rooms_metadata.json`
- Thumbnails: `Documents/roomPlan/thumbnails/{filename}.jpg`

### 5.3 Furniture Model
```swift
// No explicit struct - just file URLs
// Category inference from filename or UserDefaults

enum FurnitureCategory: String, CaseIterable {
    case seating, tables, storage, beds, lighting, 
         decor, kitchen, outdoor, office, electronics, other
    
    var icon: String { /* SF Symbol */ }
    var color: UIColor { /* Category color */ }
}
```

**Persistence**:
- USDZ files: `Documents/furniture/{filename}.usdz`
- Category: `UserDefaults` (`"furniture_category_{filename}"`)
- Thumbnails: In-memory cache (`NSCache`)

---

## 6. File Structure

### 6.1 Project Organization
```
EnVision/
├── Envision/
│   ├── AppDelegate.swift           # App lifecycle, theme setup
│   ├── SceneDelegate.swift         # Window/scene management, root switching
│   ├── MainTabBarController.swift  # 3-tab container
│   ├── Info.plist                  # App config (camera, photo library, ARKit)
│   │
│   ├── Assets.xcassets/            # Images, icons, SF Symbols
│   ├── Base.lproj/
│   │   └── LaunchScreen.storyboard # Only storyboard in project
│   │
│   ├── 3D_Models/                  # Sample USDZ files
│   │   ├── chair.usdz
│   │   ├── table.usdz
│   │   ├── hall.usdz
│   │   └── ios_room*.usdz
│   │
│   ├── Components/                 # Reusable UI components
│   │   ├── CustomTextField.swift
│   │   ├── PrimaryButton.swift
│   │   └── ModernTextField.swift
│   │
│   ├── Extensions/                 # Utilities & managers
│   │   ├── Extensions.swift        # String validation, Date formatting
│   │   ├── UIColor+Hex.swift       # Hex color support
│   │   ├── UIFont+AppFonts.swift   # Custom fonts (if any)
│   │   ├── UIViewController+Transition.swift
│   │   ├── Entity+Visit.swift      # RealityKit entity helpers
│   │   ├── UserManager.swift       # Auth & user state
│   │   ├── UserModel.swift         # User data model
│   │   └── SaveManager.swift       # File I/O helpers
│   │
│   ├── Managers/
│   │   └── TourManager.swift       # App tour state (deprecated)
│   │
│   ├── Tips/                       # TipKit (REMOVED, placeholder only)
│   │   ├── AppTips.swift           # Empty placeholder
│   │   └── TipPresenter.swift      # Empty placeholder
│   │
│   └── Screens/
│       ├── Onboarding/             # Login, Signup, Forgot Password
│       │   ├── SplashViewController.swift
│       │   ├── OnboardingController.swift
│       │   ├── OnboardingPage.swift
│       │   ├── LoginViewController.swift
│       │   ├── SignupViewController.swift
│       │   ├── ForgotPasswordViewController.swift
│       │   ├── ModernTextField.swift
│       │   └── SocialButton.swift
│       │
│       └── MainTabs/
│           ├── Rooms/              # Room scanning & management
│           │   ├── MyRoomsViewController.swift
│           │   ├── MyRoomsViewController+helpers.swift
│           │   ├── RoomModel.swift
│           │   ├── RoomCategory.swift
│           │   ├── RoomCell.swift
│           │   ├── MetadataManager.swift
│           │   ├── RoomPlanScan/
│           │   │   ├── RoomPlanScannerViewController.swift
│           │   │   └── RoomPreviewViewController.swift
│           │   └── furniture+room/
│           │       ├── RoomViewerViewController.swift
│           │       ├── RoomEditVC.swift
│           │       ├── RoomVisualizeVC.swift
│           │       ├── FurniturePicker.swift
│           │       ├── FurnitureControlPanel.swift
│           │       └── OrbitJoystick.swift
│           │
│           ├── furniture/          # Furniture capture & library
│           │   ├── ScanFurnitureViewController.swift
│           │   ├── FurnitureCategory.swift
│           │   ├── FurnitureCell.swift
│           │   ├── Object Capture/
│           │   │   ├── ObjectScanViewController.swift
│           │   │   ├── ObjectCapturePreviewController.swift
│           │   │   ├── ARMeshExporter.swift
│           │   │   ├── InstructionOverlay.swift
│           │   │   ├── FeedbackBubble.swift
│           │   │   └── ArrowGuideView.swift
│           │   ├── CreateModel/
│           │   │   ├── CreateModelViewController.swift
│           │   │   └── CreateModelViewController2.swift
│           │   ├── ModelsFromFiles/
│           │   │   ├── ViewModelsViewController.swift
│           │   │   └── USDZCell.swift
│           │   └── roomPlanColor/
│           │       └── (Color customization - not fully implemented)
│           │
│           └── profile/            # User profile & settings
│               ├── ProfileViewController.swift
│               ├── ProfileCell.swift
│               ├── EditProfileViewController.swift
│               └── SubScreens/
│                   ├── SettingsViewController.swift
│                   ├── ThemeViewController.swift
│                   ├── TipsLibraryViewController.swift
│                   ├── AboutViewController.swift
│                   ├── PrivacyViewController.swift
│                   └── SupportViewController.swift
│
└── Envision.xcodeproj/
```

### 6.2 Documents Directory Structure (Runtime)
```
Documents/
├── roomPlan/
│   ├── {uuid}.usdz                 # Room USDZ files
│   ├── rooms_metadata.json         # All room metadata
│   └── thumbnails/
│       └── {uuid}.jpg
│
└── furniture/
    └── {uuid}.usdz                 # Furniture USDZ files
```

---

## 7. Third-Party Dependencies

**Current**: None (uses only Apple frameworks)

**Planned** (for Firebase backend):
- Firebase SDK (via Swift Package Manager)
  - FirebaseAuth
  - FirebaseFirestore
  - FirebaseStorage

---

## 8. Backend Design (Firebase)

### 8.1 Recommended Firebase Products

1. **Firebase Authentication**
   - Email/Password authentication
   - Password reset emails
   - (Future) Sign in with Apple, Google

2. **Cloud Firestore**
   - User profiles
   - Room metadata
   - Furniture metadata
   - Shared collections

3. **Firebase Storage**
   - Profile pictures
   - Room USDZ files (optional, can stay local)
   - Furniture USDZ files (optional)
   - Thumbnails

### 8.2 Firestore Data Model

#### Collection: `users/{uid}`
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "bio": "AR enthusiast",
  "profileImageURL": "gs://bucket/users/{uid}/profile.jpg",
  "createdAt": "2026-01-21T10:00:00Z",
  "preferences": {
    "notificationsEnabled": true,
    "scanReminders": true,
    "newFeatureAlerts": true,
    "theme": 0
  }
}
```

#### Collection: `users/{uid}/rooms/{roomId}`
```json
{
  "id": "uuid",
  "name": "Living Room",
  "category": "living",
  "createdAt": "2026-01-21T10:30:00Z",
  "usdzURL": "gs://bucket/users/{uid}/rooms/{roomId}.usdz",
  "thumbnailURL": "gs://bucket/users/{uid}/rooms/{roomId}_thumb.jpg",
  "dimensions": {
    "width": 5.2,
    "length": 4.8,
    "height": 2.7
  },
  "notes": "Main living area"
}
```

#### Collection: `users/{uid}/furniture/{furnitureId}`
```json
{
  "id": "uuid",
  "name": "Modern Chair",
  "category": "seating",
  "createdAt": "2026-01-21T11:00:00Z",
  "usdzURL": "gs://bucket/users/{uid}/furniture/{furnitureId}.usdz",
  "thumbnailURL": "gs://bucket/users/{uid}/furniture/{furnitureId}_thumb.jpg"
}
```

### 8.3 Implementation Plan

#### Phase 1: Authentication
1. Add Firebase SDK via SPM
2. Configure `FirebaseApp` in `AppDelegate`
3. Replace `UserManager.login/signup` with Firebase Auth calls:
   ```swift
   Auth.auth().signIn(withEmail:password:) { result, error in
       // Fetch user doc from Firestore
   }
   
   Auth.auth().createUser(withEmail:password:) { result, error in
       // Create user doc in Firestore
   }
   
   Auth.auth().sendPasswordReset(withEmail:) { error in
       // Show success alert
   }
   ```
4. Add auto-login in `SplashViewController`:
   ```swift
   if Auth.auth().currentUser != nil {
       switchToMainApp()
   } else {
       goToOnboarding()
   }
   ```

#### Phase 2: User Profile Sync
1. Create Firestore helper: `FirestoreManager.swift`
2. On login/signup: fetch/create user doc
3. On profile edit: update Firestore + local cache
4. Keep local cache for offline access

#### Phase 3: Room & Furniture Sync
1. Upload USDZ to Firebase Storage (optional, bandwidth consideration)
2. Store metadata in Firestore
3. Sync on app launch / manual refresh
4. Show sync indicator in UI

#### Phase 4: Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      
      match /rooms/{roomId} {
        allow read, write: if request.auth.uid == userId;
      }
      
      match /furniture/{furnitureId} {
        allow read, write: if request.auth.uid == userId;
      }
    }
  }
}
```

### 8.4 Migration Strategy
- Keep existing file-based storage as primary
- Add Firebase as sync/backup layer
- Implement "Export/Import" feature for USDZ files
- Show cloud sync status in UI

---

## 9. Tips & Tour System (REMOVED)

### 9.1 Previous Implementation (Now Removed)

**What was removed**:
- `import TipKit` from all files
- `Tips.configure()` in `AppDelegate`
- `Tips.resetDatastore()` in `TourManager`
- All `TipView(...)` hosting in view controllers
- `AppTips.swift` definitions (25 tips)
- `TipPresenter.swift` SwiftUI hosting controller

**Reason for removal**:
- SwiftUI `TipView` hosting in UIKit was causing layout issues (vertical text, overlapping UI, non-responsive buttons)
- TipKit requires iOS 17+ and was adding complexity without stable behavior

### 9.2 What Still Exists (Unchanged)

**Profile → Tips & Tutorials**:
- `TipsLibraryViewController.swift` remains fully functional
- Shows static list of all tips (hardcoded)
- User can browse tips anytime regardless of app state
- No TipKit dependency

**TourManager**:
- `TourManager.swift` remains for tour state tracking
- Stores `hasCompletedTour`, `currentTourStep` in UserDefaults
- `resetTour()` clears tour state (no longer calls TipKit)
- Used by "Restart App Tour" button in Profile

### 9.3 Future Recommendation: Pure UIKit Tips

If tips need to be re-added, implement as **pure UIKit** (no SwiftUI):

1. **Custom UIView subclass**: `TipBubbleView`
   - Arrow pointer (CAShapeLayer)
   - Title + message labels
   - Action buttons (primary + dismiss)
   - Auto-layout constraints

2. **Presentation**:
   - Add as subview to target view controller
   - Position relative to anchor view (e.g., below nav bar, above button)
   - Animate in/out with spring animations

3. **State Management**:
   - Keep `TourManager` for progression tracking
   - Store "seen tips" in UserDefaults
   - Rules-based showing (e.g., "show after first room scan")

4. **Benefits**:
   - Full control over layout
   - No SwiftUI hosting issues
   - Responsive touch handling
   - Native UIKit feel

---

## 10. Key Improvements Needed

### Priority 1: Tips & Tour System (CRITICAL)

**Problem**: Tips feature was removed due to instability. App has no onboarding guidance.

**Recommendation**: Implement pure UIKit tips system (see section 9.3)

**Implementation Checklist**:
- [ ] Create `TipBubbleView.swift` (UIView subclass)
  - Arrow pointer with CAShapeLayer
  - Title, message, primary button, dismiss button
  - Constraint-based layout
- [ ] Create `TipCoordinator.swift`
  - Manages tip lifecycle (show, dismiss, track)
  - Rules engine (conditions for showing)
  - Integrates with TourManager
- [ ] Define tip content (same as old AppTips.swift):
  - Welcome tip (on first launch)
  - My Rooms tips (scan, import, actions menu)
  - Furniture tips (capture, quality)
  - Profile tips (settings, customization)
- [ ] Add tip anchors to view controllers:
  - `MyRoomsViewController`: below nav bar, above collection view
  - `ScanFurnitureViewController`: below scan button
  - `ProfileViewController`: above settings row
- [ ] Wire progression:
  - Step 1: Welcome → My Rooms
  - Step 2: First room scan → Furniture
  - Step 3: First furniture capture → Profile
  - Step 4: Complete tour
- [ ] Add "Skip Tour" option (respects user choice)
- [ ] Test on iPhone 14 Pro / 15 Pro (different screen sizes)
- [ ] Ensure tips don't block critical UI elements

**Estimated Effort**: 2-3 days

---

### Priority 2: Firebase Backend Integration

**Problem**: Auth & data currently local-only (UserDefaults, FileManager). No sync, no multi-device.

**Recommendation**: Implement Firebase (see section 8)

**Implementation Checklist**:
- [ ] Add Firebase SDK via SPM
- [ ] Configure Firebase project (console.firebase.google.com)
- [ ] Add `GoogleService-Info.plist` to Xcode
- [ ] Configure `FirebaseApp` in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
- [ ] Rewrite `UserManager.login/signup/reset` with Firebase Auth
- [ ] Add auto-login in `SplashViewController`
- [ ] Create `FirestoreManager.swift` for Firestore operations
- [ ] Sync user profile on login/edit
- [ ] (Optional) Upload USDZ to Firebase Storage
- [ ] Add offline caching (Firestore has built-in cache)
- [ ] Implement security rules
- [ ] Add sync indicator UI (cloud icon in nav bar)
- [ ] Handle network errors gracefully

**Estimated Effort**: 4-5 days

---

### Priority 3: Auto-Login & Session Persistence

**Problem**: User must log in every time app launches (no persistent session check).

**Recommendation**: Check Firebase Auth state in `SplashViewController`

**Implementation**:
```swift
// In SplashViewController.goNext()
if let user = Auth.auth().currentUser {
    // User already logged in
    SceneDelegate.shared?.switchToMainApp()
} else {
    // Show onboarding
    let onboarding = OnboardingController()
    present(onboarding, animated: true)
}
```

**Implementation Checklist**:
- [ ] Add Firebase Auth state check in `SplashViewController`
- [ ] Keep onboarding for first-time users only
- [ ] Add "Show Onboarding Again" option in Settings
- [ ] Test logout → re-login flow
- [ ] Test app termination → relaunch (session should persist)

**Estimated Effort**: 1 day

---

### Priority 4: Error Handling & Loading States

**Problem**: No consistent error handling. No loading indicators during async operations.

**Recommendation**: Add error alerts + loading overlays

**Implementation Checklist**:
- [ ] Create `ErrorAlertHelper.swift` (standard error alert factory)
- [ ] Create `LoadingOverlay.swift` (reusable loading view)
- [ ] Add error handling to:
  - Login/Signup (network errors, invalid credentials)
  - Room scanning (RoomPlan failure, no LiDAR)
  - Furniture capture (insufficient photos, processing failure)
  - File operations (disk full, permission denied)
- [ ] Add loading states to:
  - Login/Signup (show spinner during auth)
  - Room/Furniture processing (show progress %)
  - File uploads (Firebase Storage)
- [ ] Add retry logic for network failures
- [ ] Log errors to console (or Firebase Crashlytics)

**Estimated Effort**: 2 days

---

### Priority 5: Thumbnail Generation Optimization

**Problem**: Thumbnails generated synchronously on main thread (blocks UI).

**Recommendation**: Move to background queue + cache

**Implementation Checklist**:
- [ ] Use `QLThumbnailGenerator` with `.background` queue
- [ ] Cache thumbnails in Documents (persistent, not in-memory only)
- [ ] Show placeholder image while generating
- [ ] Regenerate thumbnails if USDZ changes
- [ ] Add "Clear Thumbnail Cache" option in Settings

**Estimated Effort**: 1 day

---

### Priority 6: Search & Filter UX

**Problem**: Search is basic text matching. No advanced filters (date, size, category combination).

**Recommendation**: Add filter chips + sort options

**Implementation Checklist**:
- [ ] Add sort menu (Name A-Z, Date Created, Recently Modified)
- [ ] Add multi-select category filter (not just single)
- [ ] Add date range filter (Last 7 days, Last 30 days, Custom)
- [ ] Add size filter for rooms (Small, Medium, Large)
- [ ] Persist filter/sort state in UserDefaults
- [ ] Show "Clear Filters" button when active

**Estimated Effort**: 2 days

---

### Priority 7: AR Placement Improvements

**Problem**: Furniture placement in `RoomViewerViewController` is basic. No snap-to-grid, no collision detection.

**Recommendation**: Add placement helpers

**Implementation Checklist**:
- [ ] Add snap-to-grid (0.1m increments)
- [ ] Add collision detection (furniture can't overlap)
- [ ] Add "Align to Wall" button (snap to nearest room wall)
- [ ] Add measurement tool (show distance between furniture)
- [ ] Add undo/redo for transforms
- [ ] Add "Reset Position" button (return to original placement)
- [ ] Save/load furniture transforms in room metadata

**Estimated Effort**: 3 days

---

### Priority 8: Accessibility

**Problem**: No VoiceOver support, no Dynamic Type support.

**Recommendation**: Add accessibility labels + scale fonts

**Implementation Checklist**:
- [ ] Add `.accessibilityLabel` to all interactive elements
- [ ] Add `.accessibilityHint` for non-obvious actions
- [ ] Support Dynamic Type (use `.preferredFont(forTextStyle:)`)
- [ ] Test with VoiceOver enabled
- [ ] Add high contrast mode support
- [ ] Add reduce motion support (disable fancy animations)
- [ ] Test with Accessibility Inspector

**Estimated Effort**: 2 days

---

### Priority 9: Localization

**Problem**: All strings hardcoded in English.

**Recommendation**: Extract strings to `Localizable.strings`

**Implementation Checklist**:
- [ ] Create `Localizable.strings` (English)
- [ ] Replace all hardcoded strings with `NSLocalizedString`
- [ ] Add Spanish localization (es.lproj)
- [ ] Add French localization (fr.lproj)
- [ ] Test language switching
- [ ] Localize Info.plist strings (camera/photo permissions)

**Estimated Effort**: 3 days

---

### Priority 10: Unit & UI Tests

**Problem**: No tests. No CI/CD.

**Recommendation**: Add XCTest suite

**Implementation Checklist**:
- [ ] Create `EnvisionTests` target
- [ ] Add unit tests for:
  - `UserManager` (login/signup/logout)
  - `MetadataManager` (load/save)
  - `RoomModel` (init, category inference)
  - String extensions (email/password validation)
- [ ] Create `EnvisionUITests` target
- [ ] Add UI tests for:
  - Login flow (happy path + error cases)
  - Signup flow
  - Room scan flow (mock LiDAR)
  - Furniture capture flow (mock camera)
- [ ] Set up GitHub Actions CI (run tests on PR)

**Estimated Effort**: 4 days

---

## Summary of Improvements (Prioritized)

| Priority | Feature | Effort | Impact | Status |
|----------|---------|--------|--------|--------|
| **1** | **Tips & Tour System (UIKit)** | 2-3 days | **Critical** | ⚠️ **REMOVED** |
| **2** | **Firebase Backend** | 4-5 days | High | ❌ Not started |
| **3** | **Auto-Login** | 1 day | High | ❌ Not started |
| **4** | **Error Handling** | 2 days | High | ⚠️ Partial |
| **5** | **Thumbnail Optimization** | 1 day | Medium | ⚠️ Partial |
| **6** | **Search & Filter UX** | 2 days | Medium | ⚠️ Basic only |
| **7** | **AR Placement Helpers** | 3 days | Medium | ❌ Not started |
| **8** | **Accessibility** | 2 days | Medium | ❌ Not started |
| **9** | **Localization** | 3 days | Low | ❌ Not started |
| **10** | **Unit & UI Tests** | 4 days | Low | ❌ Not started |

**Total Estimated Effort**: ~24-27 days

---

## Appendix: Key Code Snippets

### A1: UserManager.login (Current - Local Only)
```swift
// Envision/Extensions/UserManager.swift
func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
    // Simulated login
    if let user = currentUser, user.email == email {
        completion(true)
    } else {
        // Create new user (no password verification)
        let newUser = UserModel(
            id: UUID().uuidString,
            name: email.components(separatedBy: "@").first ?? "User",
            email: email,
            createdAt: Date(),
            preferences: UserPreferences()
        )
        currentUser = newUser
        completion(true)
    }
}
```

### A2: SceneDelegate.switchToMainApp
```swift
// Envision/SceneDelegate.swift
func switchToMainApp() {
    let mainVC = MainTabBarController()
    
    window?.rootViewController = mainVC
    window?.makeKeyAndVisible()
    
    UIView.transition(with: window!, duration: 0.4, options: .transitionCrossDissolve) {
        // Smooth fade transition
    }
}
```

### A3: RoomPlanScanner (LiDAR)
```swift
// Envision/Screens/MainTabs/Rooms/RoomPlanScan/RoomPlanScannerViewController.swift
import RoomPlan

class RoomPlanScannerViewController: UIViewController, RoomCaptureViewDelegate {
    private var captureView: RoomCaptureView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureView = RoomCaptureView(frame: view.bounds)
        captureView.captureSession.run(configuration: .init())
        captureView.delegate = self
        view.addSubview(captureView)
    }
    
    func captureView(_ view: RoomCaptureView, didEndWith data: CapturedRoom) {
        // Convert to USDZ
        let url = exportToUSDZ(data)
        // Save and show preview
    }
}
```

### A4: ObjectScanViewController (Photogrammetry)
```swift
// Envision/Screens/MainTabs/furniture/Object Capture/ObjectScanViewController.swift
class ObjectScanViewController: UIViewController {
    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var images: [URL] = []
    
    private func startAutoCapture() {
        captureTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.takePhoto()
        }
    }
    
    @objc private func stopCapture() {
        captureTimer?.invalidate()
        // Process images with PhotogrammetrySession
        let preview = ObjectCapturePreviewController(imagesFolder: tempFolderURL)
        navigationController?.pushViewController(preview, animated: true)
    }
}
```

---

**Document Version**: 1.0  
**Last Updated**: January 21, 2026  
**Author**: GitHub Copilot  
**Project**: EnVision iOS App  

---

*End of Technical Documentation*
