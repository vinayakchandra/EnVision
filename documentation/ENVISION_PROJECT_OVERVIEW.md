 f# EnVision - AR Room Visualization App

<div align="center">

![EnVision Logo](Envision/Assets.xcassets/envision.imageset/envision.png)

**Transform Your Space with Augmented Reality**

*iOS App for Room Scanning, Furniture Visualization & Interior Design*

---

</div>

## 🎯 Overview

**EnVision** is an innovative iOS application that leverages Apple's ARKit and RoomPlan technologies to help users scan their rooms, visualize furniture placement, and design their interior spaces in augmented reality. Users can scan real rooms, add virtual furniture, take accurate measurements, and share their designs.

---

## ✨ Key Features

| Feature | Description |
|---------|-------------|
| 🏠 **Room Scanning** | Scan real rooms using Apple RoomPlan to create accurate 3D models |
| 🪑 **Furniture Placement** | Add and position virtual furniture in your scanned rooms |
| 📏 **AR Measurements** | Real-world accurate measurements with proximity detection |
| 🎨 **Color Customization** | Change colors of walls, floors, doors, and windows |
| 📤 **Export & Share** | Export as images or USDZ 3D files |
| 📱 **Object Capture** | Create custom 3D furniture models from photos |

---

## 🛠️ Technology Stack

| Component | Technology |
|-----------|------------|
| **Platform** | iOS 16+ |
| **Language** | Swift 5 |
| **AR Framework** | ARKit, RealityKit |
| **Room Scanning** | RoomPlan API |
| **3D Models** | USDZ Format |
| **UI Framework** | UIKit |
| **Authentication** | Firebase (Google Sign-In) |

---

## 📱 App Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      EnVision App                           │
├─────────────────────────────────────────────────────────────┤
│  Onboarding    │    Main Tabs    │    AR Features          │
│  ───────────   │    ──────────   │    ────────────         │
│  • Splash      │    • Rooms      │    • Room Scan          │
│  • Login       │    • Furniture  │    • Furniture Place    │
│  • Signup      │    • Profile    │    • Measurements       │
│  • Onboarding  │                 │    • Object Capture     │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔑 Core Modules

### 1. Room Management
- Scan rooms using LiDAR/RoomPlan
- Save and organize room models
- Apply color customizations
- Category-based organization

### 2. Furniture System
- Browse furniture catalog
- Create custom models via Object Capture
- Import USDZ files
- Scale and position in AR

### 3. Measurement System
- **Point-to-Point**: Tap two points to measure distance
- **Room Dimensions**: View full room W×H×D
- **Furniture Dimensions**: Tap furniture for measurements
- **Proximity Detection**: Auto-measure distances to walls/objects

### 4. Export & Sharing
- Screenshot export (PNG)
- 3D model export (USDZ)
- Share via iOS Share Sheet

---

## 📂 Project Structure

```
Envision/
├── Screens/           # View Controllers
│   ├── Onboarding/    # Login, Signup, Splash
│   └── MainTabs/      # Rooms, Furniture, Profile
├── Managers/          # Business Logic
│   ├── MeasurementManager.swift
│   ├── ProximityMeasurementSystem.swift
│   └── RealWorldScaleManager.swift
├── Components/        # Reusable UI Components
├── Extensions/        # Swift Extensions
└── 3D_Models/         # Sample USDZ Models
```

---

## 🚀 Getting Started

1. **Clone** the repository
2. **Open** `Envision.xcodeproj` in Xcode 15+
3. **Configure** signing with your Apple Developer account
4. **Build & Run** on an iOS device with LiDAR (iPhone 12 Pro+)

---

## 📋 Requirements

- **Device**: iPhone 12 Pro or later (LiDAR required for room scanning)
- **iOS**: 16.0 or later
- **Xcode**: 15.0 or later

---

## 👥 Target Users

- **Homeowners** planning renovations or furniture purchases
- **Interior Designers** creating client visualizations
- **Real Estate Agents** staging virtual properties
- **Furniture Retailers** offering AR preview experiences

---

## 📊 Future Roadmap

- [ ] Cloud sync for projects
- [ ] Collaborative room editing
- [ ] AI-powered furniture recommendations
- [ ] Integration with furniture e-commerce
- [ ] Multi-room floor plans

---

<div align="center">

**EnVision** - *See Your Space, Reimagined*

© 2026 EnVision Team | Built with ❤️ using Swift & ARKit

</div>
