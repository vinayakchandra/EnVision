# EnVision - Room & Furniture 3D Scanner

<p align="center">
  <img src="Envision/Assets.xcassets/envision.imageset/envision-background.png" alt="EnVision Logo" width="120"/>
</p>

<p align="center">
  <strong>Scan, Visualize & Manage Your Spaces in 3D</strong> 
</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-26.0+-blue.svg" alt="iOS 26.0+"/>
  <img src="https://img.shields.io/badge/Swift-6.2-orange.svg" alt="Swift 6.2"/>
</p>

---

## 📱 Overview

EnVision is an iOS application that leverages Apple's RoomPlan and Object Capture technologies to scan rooms and
furniture, creating detailed 3D models that can be viewed in augmented reality.

## ✨ Features

### 🏠 My Rooms

- **Room Scanning** - Use RoomPlan API to capture detailed room layouts
- **Parametric & Textured Modes** - Choose between different scanning modes
- **Category Filtering** - Organize rooms by type (Living Room, Bedroom, Kitchen, etc.)
- **Search & Filter** - Quickly find rooms with search and filter chips
- **Quick Look & AR View** - Preview models in 3D or place them in AR
- **Multi-Select** - Select multiple rooms for batch operations
- **Import USDZ** - Import existing 3D models from files
- **Edit Mode** - Change colors/textures, hide entities, and show labels in room editor
- **Room Export & Share** - Export scanned rooms as USDZ and share with iOS share sheet

### 🪑 My Furniture

- **Object Capture** - Scan furniture using photogrammetry
- **Automatic Capture** - Guided scanning experience
- **Create from Photos** - Build models from existing photo sets
- **Category Organization** - Organize by furniture type (Seating, Tables, Storage, etc.)
- **AR Placement** - Place furniture models in your real space
- **Quick Look** - 3D preview with rotation and zoom
- **Multi-Select with Checkmarks** - Visual selection feedback
- **Background Processing** - Continue long photogrammetry processing with notifications

### 🔎 Search

- **Unified Model Search** - Search both room and furniture libraries from a dedicated tab
- **Quick Navigation** - Open rooms directly or preview furniture from search results

### 📏 AR Tools

- **Measurement System** - Bounding boxes, distance lines, and unit-aware dimension labels
- **Proximity Detection** - Auto-measure clearances to nearby walls/objects
- **Real-World Scale Mapping** - Convert display values to real dimensions for accurate results

### 💡 Guided Experience

- **In-App Tour** - Contextual tips across Rooms, Furniture, and Profile workflows
- **Tips Library** - Dedicated screen with tutorials and restartable app tour

### 👤 Profile

- **User Management** - Local user data persistence
- **Firebase Authentication** - Email/password plus Google and Apple sign-in
- **Profile Photo** - Camera & gallery integration
- **Appearance** - Light/Dark/System theme support
- **Notifications** - Configurable notification preferences
- **Permissions** - Camera & Photo Library status
- **Security** - Face ID/Touch ID support
- **Privacy Controls** - Data sharing preferences

## 🛠 Technologies

| Technology                 | Usage                               |
|----------------------------|-------------------------------------|
| **RoomPlan**               | Room scanning and structure capture |
| **ARKit**                  | Augmented reality visualization     |
| **RealityKit**             | 3D rendering and interaction        |
| **Object Capture**         | Photogrammetry for furniture models |
| **QuickLook**              | 3D model preview                    |
| **QuickLookThumbnailing**  | Model thumbnail generation          |
| **Firebase Auth**          | Email/password and social auth      |
| **Google Sign-In**         | Google account authentication       |
| **AuthenticationServices** | Sign in with Apple                  |
| **UserNotifications**      | Local notifications                 |
| **LocalAuthentication**    | Biometric authentication            |

## 📋 Requirements

- iOS 26.0+
- Xcode 26.0+
- iPhone with LiDAR sensor (for best results)
- A12 Bionic chip or later

## 🚀 Getting Started

### Installation

1. Clone the repository:

```bash
git clone https://github.com/vinayakchandra/EnVision.git
```

2. Open the project in Xcode:

```bash
cd ios--EnVision-Final-repo
open Envision.xcodeproj
```

3. Select your development team in Signing & Capabilities

4. Build and run on a physical device (simulator doesn't support all AR features)

### Project Structure

```
Envision/
├── Extensions/
│   ├── UserManager.swift          # User data persistence
│   ├── UserModel.swift            # User data model
│   └── SaveManager.swift          # Room/Furniture metadata
├── Managers/                      # Core managers (auth, measurement, tour, colors)
├── Tips/                          # Guided tips/tour components
├── Screens/
│   ├── MainTabs/
│   │   ├── Rooms/                 # My Rooms tab
│   │   ├── furniture/             # My Furniture tab
│   │   ├── profile/               # Profile tab
│   │   └── Search/                # Unified search tab
│   └── Onboarding/                # Login/Signup flows
├── Components/                     # Reusable UI components
└── Assets.xcassets/               # Images and colors
```

## 🎯 Recent Updates

- ✅ Guided tips and app tour flow across Rooms, Furniture, and Profile
- ✅ Dedicated Search tab for combined room/furniture model lookup
- ✅ Room edit enhancements: color/texture customization, hide controls, labels
- ✅ AR measurement tooling with bounding boxes and proximity distance indicators
- ✅ Firebase auth improvements with Google and Apple sign-in support

## 👥 Contributors

- **Abbinav** - Lead Developer
- **Vinayak** - Lead Developer

## 🙏 Acknowledgments

- Apple RoomPlan Framework
- Apple Object Capture API
- SF Symbols for iconography
