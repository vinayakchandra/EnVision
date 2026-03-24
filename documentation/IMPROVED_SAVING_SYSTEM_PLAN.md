# EnVision - Improved Model Saving System
## Comprehensive Implementation Plan

**Document Version:** 1.0  
**Created:** February 7, 2026  
**Status:** Planning Phase

---

## Table of Contents

1. [Current System Analysis](#1-current-system-analysis)
2. [Pain Points & Issues](#2-pain-points--issues)
3. [Proposed Improvements](#3-proposed-improvements)
4. [New Architecture Design](#4-new-architecture-design)
5. [Feature 1: Unified Save Manager](#5-feature-1-unified-save-manager)
6. [Feature 2: Auto-Save System](#6-feature-2-auto-save-system)
7. [Feature 3: Quick Save Actions](#7-feature-3-quick-save-actions)
8. [Feature 4: Enhanced Thumbnails](#8-feature-4-enhanced-thumbnails)
9. [Feature 5: Project Bundles](#9-feature-5-project-bundles)
10. [UI/UX Improvements](#10-uiux-improvements)
11. [Implementation Timeline](#11-implementation-timeline)

---

## 1. Current System Analysis

### Existing Components

| Component | File | Purpose |
|-----------|------|---------|
| `SaveManager` | `Extensions/SaveManager.swift` | Basic save/load for USDZ models |
| `MetadataManager` | `Screens/MainTabs/Rooms/MetadataManager.swift` | Room-specific metadata |
| `RoomColorManager` | `Managers/RoomColorManager.swift` | Persists room color customizations |

### Current Capabilities

```
┌─────────────────────────────────────────────────────────────────┐
│                    CURRENT SAVE SYSTEM                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Room Saving:                                                   │
│  • RoomPlan scan → USDZ file saved to Documents/roomPlan/      │
│  • Metadata saved in rooms_metadata.json                        │
│  • Thumbnails generated via QuickLook                           │
│  • Colors saved in UserDefaults via RoomColorManager            │
│                                                                 │
│  Furniture Saving:                                              │
│  • Object Capture → USDZ file saved to Documents/furniture/    │
│  • Basic metadata (filename, date, size)                        │
│  • Thumbnails generated via QuickLook                           │
│                                                                 │
│  Placed Furniture in Rooms:                                     │
│  • NOT SAVED! Lost when exiting the view                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Pain Points & Issues

### Critical Issues

| Issue | Severity | Description |
|-------|----------|-------------|
| **Furniture Placement Lost** | 🔴 Critical | Placed furniture positions not saved |
| **No Auto-Save** | 🔴 Critical | Work can be lost if app crashes |
| **Duplicate Managers** | 🟡 Medium | SaveManager & MetadataManager overlap |
| **No Undo/Redo** | 🟡 Medium | Can't undo accidental changes |
| **Slow Thumbnail Generation** | 🟢 Low | QuickLook can be slow for complex models |

### User Pain Points

1. **"I placed furniture perfectly, but when I came back it was gone!"**
2. **"It takes too long to save my room scan"**
3. **"I accidentally deleted a room and couldn't recover it"**
4. **"I want to share my designed room with furniture included"**
5. **"I can't rename my saved rooms easily"**

---

## 3. Proposed Improvements

### High-Level Goals

```
┌─────────────────────────────────────────────────────────────────┐
│                    IMPROVED SAVE SYSTEM                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ✅ Automatic saving of furniture placements                   │
│  ✅ Auto-save every 30 seconds while editing                   │
│  ✅ One-tap quick save with visual feedback                    │
│  ✅ Project bundles (room + furniture + colors in one file)   │
│  ✅ Better thumbnail generation with custom renderer           │
│  ✅ Undo/Redo support for furniture placement                  │
│  ✅ Cloud backup integration (iCloud)                          │
│  ✅ Easy rename and organize                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. New Architecture Design

### Proposed File Structure

```
Documents/
├── EnVisionProjects/
│   ├── projects_index.json          # Master index of all projects
│   │
│   ├── room_abc123/                  # Project bundle folder
│   │   ├── project.json              # Project metadata
│   │   ├── room.usdz                 # Original room scan
│   │   ├── thumbnail.jpg             # Project thumbnail
│   │   ├── thumbnail_large.jpg       # High-res thumbnail
│   │   ├── colors.json               # Color customizations
│   │   ├── placements.json           # Furniture placements
│   │   └── history/                  # Undo history
│   │       ├── state_001.json
│   │       └── state_002.json
│   │
│   └── room_def456/
│       └── ...
│
├── FurnitureLibrary/
│   ├── furniture_index.json          # Furniture catalog
│   │
│   ├── chair_001/
│   │   ├── model.usdz
│   │   ├── metadata.json
│   │   └── thumbnail.jpg
│   │
│   └── sofa_002/
│       └── ...
│
└── Backups/
    ├── auto_backup_2026-02-07.zip
    └── ...
```

### New Data Models

```swift
// Project metadata
struct EnVisionProject: Codable {
    let id: UUID
    var name: String
    let createdDate: Date
    var modifiedDate: Date
    var roomModelPath: String
    var thumbnailPath: String?
    var colorScheme: RoomColorScheme?
    var furniturePlacements: [FurniturePlacement]
    var tags: [String]
    var isFavorite: Bool
}

// Furniture placement data
struct FurniturePlacement: Codable {
    let id: UUID
    let furnitureId: String       // Reference to furniture library
    var position: SIMD3<Float>
    var rotation: simd_quatf
    var scale: SIMD3<Float>
    let placedDate: Date
}

// Room color scheme
struct RoomColorScheme: Codable {
    var walls: String?      // Hex color
    var floor: String?
    var ceiling: String?
    var doors: String?
    var windows: String?
    // ... other elements
}
```

---

## 5. Feature 1: Unified Save Manager

### Design

Replace the current fragmented save system with a single, unified `ProjectManager`:

```swift
// New unified manager
final class ProjectManager {
    static let shared = ProjectManager()
    
    // MARK: - Project Operations
    func createProject(from roomScan: URL, name: String) async throws -> EnVisionProject
    func openProject(_ projectId: UUID) async throws -> EnVisionProject
    func saveProject(_ project: EnVisionProject) async throws
    func deleteProject(_ projectId: UUID) async throws
    
    // MARK: - Furniture Operations
    func addFurnitureToProject(_ furnitureId: String, at position: SIMD3<Float>)
    func updateFurniturePlacement(_ placementId: UUID, position: SIMD3<Float>, rotation: simd_quatf)
    func removeFurnitureFromProject(_ placementId: UUID)
    
    // MARK: - Auto-Save
    func enableAutoSave(interval: TimeInterval = 30)
    func disableAutoSave()
    
    // MARK: - Export
    func exportProject(_ projectId: UUID, format: ExportFormat) async throws -> URL
}
```

### Benefits

| Benefit | Description |
|---------|-------------|
| **Single Source of Truth** | One manager handles all save operations |
| **Atomic Saves** | All related data saved together |
| **Easy Backup** | Project bundles are self-contained |
| **Shareable** | Can export entire projects |

---

## 6. Feature 2: Auto-Save System

### How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                      AUTO-SAVE FLOW                             │
└──────────────────────────┬──────────────────────────────────────┘
                           │
           User enters RoomVisualizeVC
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│              AutoSaveManager.shared.startTracking()             │
│                                                                 │
│  • Timer starts (30 second interval)                           │
│  • Change detection enabled                                     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
              User moves furniture / changes colors
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Change Detected                              │
│                                                                 │
│  • Mark project as "dirty" (unsaved changes)                   │
│  • Show subtle indicator (●) in nav bar                        │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                    Timer fires (30s)
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Background Save                               │
│                                                                 │
│  • Save furniture positions                                     │
│  • Save color changes                                           │
│  • Update thumbnail if view changed significantly              │
│  • Clear "dirty" flag                                          │
│  • Brief "Saved ✓" toast (optional)                            │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation

```swift
final class AutoSaveManager {
    static let shared = AutoSaveManager()
    
    private var timer: Timer?
    private var isDirty = false
    private var currentProject: EnVisionProject?
    
    // Configurable
    var autoSaveInterval: TimeInterval = 30
    var showSaveIndicator = true
    
    func startTracking(project: EnVisionProject) {
        currentProject = project
        timer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            self?.performAutoSaveIfNeeded()
        }
    }
    
    func markDirty() {
        isDirty = true
        NotificationCenter.default.post(name: .projectHasUnsavedChanges, object: nil)
    }
    
    private func performAutoSaveIfNeeded() {
        guard isDirty, let project = currentProject else { return }
        
        Task {
            try? await ProjectManager.shared.saveProject(project)
            isDirty = false
            
            if showSaveIndicator {
                await MainActor.run {
                    showSavedIndicator()
                }
            }
        }
    }
}
```

---

## 7. Feature 3: Quick Save Actions

### Save Button in Room Visualize

Add a dedicated save button for explicit saves:

```
┌─────────────────────────────────────────────────────────────────┐
│  < Back    [Visualize | Edit]    [📏] [💾] [📤] [➕]           │
│                                  ruler save share add           │
└─────────────────────────────────────────────────────────────────┘
```

### Save States & Visual Feedback

| State | Icon | Color | Description |
|-------|------|-------|-------------|
| Saved | `checkmark.circle.fill` | Green | All changes saved |
| Unsaved | `circle.fill` | Orange | Has unsaved changes |
| Saving | `arrow.triangle.2.circlepath` | Blue | Save in progress |
| Error | `exclamationmark.circle.fill` | Red | Save failed |

### Quick Save Flow

```
┌──────────────────┐
│ User taps 💾     │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────┐
│ Show saving animation    │
│ (spinning icon)          │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│ ProjectManager.save()    │
│ • Save placements        │
│ • Save colors            │
│ • Update thumbnail       │
└────────┬─────────────────┘
         │
    ┌────┴────┐
    │         │
 Success    Failure
    │         │
    ▼         ▼
┌────────┐ ┌─────────────────┐
│ ✓ Saved│ │ Show error alert│
│ (brief)│ │ Offer retry     │
└────────┘ └─────────────────┘
```

---

## 8. Feature 4: Enhanced Thumbnails

### Current Problem

- QuickLook thumbnails can be slow
- Don't show placed furniture
- Don't reflect color customizations

### Solution: Custom Thumbnail Renderer

```swift
final class ThumbnailRenderer {
    
    /// Render thumbnail from current ARView state (includes furniture & colors)
    static func captureCurrentState(from arView: ARView, size: CGSize) -> UIImage? {
        // Capture exactly what user sees
        return arView.snapshot(saveToHDR: false)
    }
    
    /// Generate thumbnail from project data
    static func renderProjectThumbnail(
        _ project: EnVisionProject,
        size: CGSize = CGSize(width: 400, height: 400)
    ) async -> UIImage? {
        // Load room model
        // Apply colors
        // Place furniture
        // Render from isometric angle
        // Return image
    }
    
    /// Generate multiple thumbnails at different angles
    static func renderThumbnailSet(_ project: EnVisionProject) async -> [UIImage] {
        let angles: [Float] = [0, .pi/4, .pi/2, .pi]
        // Render from each angle
    }
}
```

### Thumbnail Update Triggers

| Trigger | Action |
|---------|--------|
| Initial room scan | Generate default thumbnail |
| Furniture added/moved | Update thumbnail (debounced) |
| Colors changed | Update thumbnail |
| Manual save | Always update thumbnail |
| Export | Generate high-res thumbnail |

---

## 9. Feature 5: Project Bundles

### What is a Project Bundle?

A self-contained folder with all project data:

```
my_living_room.envision/
├── manifest.json           # Version, compatibility info
├── project.json            # Project metadata
├── room.usdz               # Original room scan
├── thumbnail.jpg           # Preview image
├── colors.json             # Color customizations
├── placements.json         # Furniture positions
└── furniture/              # Embedded furniture (optional)
    ├── chair_001.usdz
    └── sofa_002.usdz
```

### Benefits

| Benefit | Description |
|---------|-------------|
| **Portable** | Move entire projects between devices |
| **Shareable** | Send complete rooms to other users |
| **Backupable** | Easy to backup single projects |
| **Version Control** | Can track project versions |

### Export/Import

```swift
// Export as shareable bundle
let bundleURL = try await ProjectManager.shared.exportBundle(
    projectId: project.id,
    embedFurniture: true,  // Include furniture models
    quality: .high         // Thumbnail quality
)

// Import bundle
let project = try await ProjectManager.shared.importBundle(from: bundleURL)
```

---

## 10. UI/UX Improvements

### 10.1 Save Status Indicator

Always-visible indicator showing save state:

```
┌─────────────────────────────────────────────────────────────────┐
│                        Top of Screen                            │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  My Living Room                              ● Unsaved    │ │
│  │  Last saved: 2 minutes ago                               │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│                        OR (when saved)                          │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  My Living Room                              ✓ Saved      │ │
│  │  Auto-save enabled                                        │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 10.2 Rename Flow

Easy inline renaming:

```
┌─────────────────────────────────────────────────────────────────┐
│                       RENAME FLOW                               │
│                                                                 │
│  1. Long-press on project name or tap "..." menu               │
│  2. Select "Rename"                                             │
│  3. Inline text field appears with current name                │
│  4. User types new name                                         │
│  5. Tap "Done" or tap outside to save                          │
│  6. Name updates immediately + auto-save triggers              │
└─────────────────────────────────────────────────────────────────┘
```

### 10.3 Unsaved Changes Warning

Prevent accidental data loss:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│     ┌─────────────────────────────────────┐                    │
│     │       Unsaved Changes               │                    │
│     │                                     │                    │
│     │  You have unsaved changes to       │                    │
│     │  "My Living Room"                   │                    │
│     │                                     │                    │
│     │  ┌─────────┐ ┌─────────┐ ┌──────┐  │                    │
│     │  │  Save   │ │ Discard │ │Cancel│  │                    │
│     │  └─────────┘ └─────────┘ └──────┘  │                    │
│     └─────────────────────────────────────┘                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 10.4 Quick Actions Menu

Long-press on project thumbnail:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│     ┌─────────────────────────────────────┐                    │
│     │  [thumbnail]  My Living Room        │                    │
│     │               Feb 7, 2026           │                    │
│     │  ─────────────────────────────────  │                    │
│     │  📝 Rename                          │                    │
│     │  📋 Duplicate                       │                    │
│     │  📤 Share                           │                    │
│     │  ⭐ Add to Favorites               │                    │
│     │  🗂️ Move to Folder                  │                    │
│     │  ─────────────────────────────────  │                    │
│     │  🗑️ Delete                  (red)   │                    │
│     └─────────────────────────────────────┘                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 11. Implementation Timeline

### Phase 1: Core Infrastructure (Week 1-2)

| Task | Priority | Estimate |
|------|----------|----------|
| Create `ProjectManager` class | 🔴 High | 2 days |
| Define new data models | 🔴 High | 1 day |
| Implement project bundle structure | 🔴 High | 2 days |
| Migrate existing save code | 🔴 High | 2 days |
| Add furniture placement saving | 🔴 High | 1 day |

### Phase 2: Auto-Save System (Week 3)

| Task | Priority | Estimate |
|------|----------|----------|
| Implement `AutoSaveManager` | 🔴 High | 2 days |
| Add change detection | 🟡 Medium | 1 day |
| Add save status indicators | 🟡 Medium | 1 day |
| Test auto-save reliability | 🔴 High | 1 day |

### Phase 3: UI/UX Improvements (Week 4)

| Task | Priority | Estimate |
|------|----------|----------|
| Add save button to nav bar | 🟡 Medium | 0.5 day |
| Implement rename flow | 🟡 Medium | 1 day |
| Add unsaved changes warning | 🔴 High | 1 day |
| Quick actions menu | 🟢 Low | 1 day |
| Polish animations & feedback | 🟢 Low | 1 day |

### Phase 4: Enhanced Thumbnails (Week 5)

| Task | Priority | Estimate |
|------|----------|----------|
| Create `ThumbnailRenderer` | 🟡 Medium | 2 days |
| Implement capture from ARView | 🟡 Medium | 1 day |
| Add thumbnail update triggers | 🟢 Low | 1 day |
| Optimize thumbnail generation | 🟢 Low | 1 day |

### Phase 5: Export & Sharing (Week 6)

| Task | Priority | Estimate |
|------|----------|----------|
| Implement bundle export | 🟡 Medium | 2 days |
| Implement bundle import | 🟡 Medium | 1 day |
| Add share functionality | 🟡 Medium | 1 day |
| Test cross-device compatibility | 🔴 High | 1 day |

---

## Summary

### Key Improvements

| Feature | Impact | Effort |
|---------|--------|--------|
| Save furniture placements | 🔴 Critical | Medium |
| Auto-save system | 🔴 Critical | Medium |
| Project bundles | 🟡 High | High |
| Quick save button | 🟡 High | Low |
| Enhanced thumbnails | 🟢 Medium | Medium |
| Rename & organize | 🟢 Medium | Low |

### Total Timeline: **6 weeks**

### Files to Create

```
Managers/
    ProjectManager.swift           # Unified save manager
    AutoSaveManager.swift          # Auto-save functionality
    ThumbnailRenderer.swift        # Custom thumbnail generation

Models/
    EnVisionProject.swift          # Project data model
    FurniturePlacement.swift       # Placement data model
    
Extensions/
    SaveManager.swift              # UPDATE existing
```

---

**Document prepared for EnVision iOS Application**  
**© 2026 EnVision Team**
