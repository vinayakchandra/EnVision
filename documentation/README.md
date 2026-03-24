# EnVision - Room & Furniture 3D Scanner

<p align="center">
  <img src="Envision/Assets.xcassets/envision.imageset/envision.png" alt="EnVision Logo" width="120"/>
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

### 🪑 My Furniture

- **Object Capture** - Scan furniture using photogrammetry
- **Automatic Capture** - Guided scanning experience
- **Category Organization** - Organize by furniture type (Seating, Tables, Storage, etc.)
- **AR Placement** - Place furniture models in your real space
- **Quick Look** - 3D preview with rotation and zoom
- **Multi-Select with Checkmarks** - Visual selection feedback

### 👤 Profile

- **User Management** - Local user data persistence
- **Profile Photo** - Camera & gallery integration
- **Appearance** - Light/Dark/System theme support
- **Notifications** - Configurable notification preferences
- **Permissions** - Camera & Photo Library status
- **Security** - Face ID/Touch ID support
- **Privacy Controls** - Data sharing preferences

## 🛠 Technologies

| Technology              | Usage                               |
|-------------------------|-------------------------------------|
| **RoomPlan**            | Room scanning and structure capture |
| **ARKit**               | Augmented reality visualization     |
| **Object Capture**      | Photogrammetry for furniture models |
| **QuickLook**           | 3D model preview                    |
| **UserNotifications**   | Local notifications                 |
| **LocalAuthentication** | Biometric authentication            |

## 📋 Requirements

- iOS 16.0+
- Xcode 15.0+
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
│   ├── NotificationHelper.swift   # Local notifications
│   └── SaveManager.swift          # Room/Furniture metadata
├── Screens/
│   ├── MainTabs/
│   │   ├── Rooms/                 # My Rooms tab
│   │   ├── furniture/             # My Furniture tab
│   │   └── profile/               # Profile tab
│   └── Onboarding/                # Login/Signup flows
├── Components/                     # Reusable UI components
└── Assets.xcassets/               # Images and colors
```

## 🎯 Recent Updates

- ✅ Empty states with CTA buttons for both tabs
- ✅ Multi-select with checkmark indicators
- ✅ Search with "no results" feedback
- ✅ Processing complete notifications
- ✅ Complete Profile tab with all sub-screens
- ✅ Filter chips for categories
- ✅ Consistent large title navigation
- ✅ Quick Look & AR View for furniture models\
  

## 👥 Contributors

- **Abbinav** - Lead Developer
- **Vinayak** - Lead Developer

## 🙏 Acknowledgments

- Apple RoomPlan Framework
- Apple Object Capture API
- SF Symbols for iconography

---

<p align="center">
  Made with ❤️ for iOS
</p>
