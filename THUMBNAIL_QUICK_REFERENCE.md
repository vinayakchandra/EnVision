# Quick Reference: Thumbnail System

## Overview
Centralized guide for understanding the thumbnail system in EnVision after the fixes.

---

## 📐 System Architecture

### Thumbnail Flow
```
Room Scan/Edit → ARView Snapshot → RoomColorManager → Disk Storage → MyRooms Display
                                         ↓
                                  400x400 JPEG
                                  RoomThumbnails/
```

---

## 🔧 Key Components

### 1. **RoomColorManager** (Static Methods)
**Location**: `Managers/RoomColorManager.swift`

**Responsibilities**:
- Save thumbnails to disk
- Get thumbnail URL
- Delete thumbnails
- Standardize size (400x400)

**Key Methods**:
```swift
RoomColorManager.saveThumbnail(_ image: UIImage, for roomURL: URL)
RoomColorManager.thumbnailURL(for roomURL: URL) -> URL
RoomColorManager.deleteThumbnail(for roomURL: URL)
RoomColorManager.hasCustomThumbnail(for roomURL: URL) -> Bool
```

---

### 2. **RoomEditVC** (Thumbnail Generation)
**Location**: `Screens/MainTabs/Rooms/furniture+room/RoomEditVC.swift`

**Trigger Points**:
- `viewWillDisappear()` - Auto-saves when leaving
- `saveAndGoBack()` - Saves when user taps Save button

**Method**:
```swift
private func saveColoredThumbnail() {
    arView.snapshot(saveToHDR: false) { image in
        RoomColorManager.saveThumbnail(image, for: self.roomURL)
        NotificationCenter.default.post(
            name: Notification.Name("RoomThumbnailDidUpdate"),
            object: nil,
            userInfo: ["roomURL": self.roomURL]
        )
    }
}
```

**Important**: Always uses `arView.snapshot()` - never `UIGraphicsImageRenderer`

---

### 3. **RoomPreviewViewController** (New Room Thumbnails)
**Location**: `Screens/MainTabs/Rooms/RoomPlanScan/RoomPreviewViewController.swift`

**Trigger Point**:
- `performSave()` - Saves thumbnail when room is first saved

**Method**:
```swift
if let thumbnail = self.imageView.image {
    RoomColorManager.saveThumbnail(thumbnail, for: savedURL)
}
```

---

### 4. **MyRoomsViewController** (Display & Cache)
**Location**: `Screens/MainTabs/Rooms/MyRoomsViewController.swift`

**Cache Configuration**:
```swift
lazy var thumbnailCache: NSCache<NSURL, UIImage> = {
    let cache = NSCache<NSURL, UIImage>()
    cache.countLimit = 50           // Max 50 images
    cache.totalCostLimit = 50 * 1024 * 1024  // Max 50MB
    return cache
}()
```

**Loading Strategy**:
1. Check memory cache (fast)
2. Check disk (background thread)
3. Generate from USDZ (QuickLook)

**Notification Handling**:
```swift
@objc private func handleThumbnailUpdate(_ notification: Notification) {
    // Clear cache
    thumbnailCache.removeObject(forKey: roomURL as NSURL)
    
    // Find room index
    guard let index = displayFiles.firstIndex(of: roomURL) else { return }
    
    // Reload only if visible
    if collectionView.indexPathsForVisibleItems.contains(indexPath) {
        collectionView.reloadItems(at: [indexPath])
    }
}
```

---

### 5. **RoomCell** (Display)
**Location**: `Screens/MainTabs/Rooms/RoomCell.swift`

**Methods**:
```swift
// Full configuration (initial load)
func configure(fileName:size:dateText:thumbnail:category:roomType:)

// Thumbnail-only update (async load)
func updateThumbnail(_ image: UIImage?)
```

---

## 📁 File Storage

### Directory Structure
```
Documents/
├── roomPlan/              # USDZ room files
│   ├── Room_2026-02-01.usdz
│   └── Room_2026-02-02.usdz
│
├── RoomThumbnails/        # Thumbnail images
│   ├── Room_2026-02-01_thumb.jpg
│   └── Room_2026-02-02_thumb.jpg
│
├── RoomColors/            # Color metadata
│   └── Room_2026-02-01_colors.json
│
└── RoomMetadata/          # Room metadata
    └── metadata.json
```

### Naming Convention
- Room file: `{custom_name}.usdz`
- Thumbnail: `{room_name}_thumb.jpg`
- Colors: `{room_name}_colors.json`

---

## 🔄 Lifecycle Events

### Scanning New Room
```
1. User scans room
2. RoomPlanScannerViewController captures
3. RoomPreviewViewController shows preview
4. User taps "Save"
5. performSave() saves USDZ + metadata + thumbnail
6. Thumbnail comes from preview imageView
```

### Editing Existing Room
```
1. User taps room in MyRooms
2. RoomViewerViewController opens
3. User taps edit or applies colors
4. RoomEditVC opens
5. User changes colors
6. User taps Save or navigates back
7. saveColoredThumbnail() captures ARView
8. Notification posted
9. MyRooms updates specific cell
```

### Deleting Room
```
1. User selects rooms
2. Taps delete
3. performBatchDelete() executes
4. SaveManager.deleteModel() - removes USDZ
5. MetadataManager.deleteMetadata() - removes metadata
6. RoomColorManager.deleteThumbnail() - removes thumbnail
7. Clears RoomColors too
```

---

## 🎯 Best Practices

### DO ✅
- Always use `arView.snapshot()` for thumbnail generation
- Save thumbnails on background thread
- Use `RoomColorManager` static methods
- Post notification after thumbnail update
- Delete thumbnails when deleting rooms
- Use 400x400 size

### DON'T ❌
- Don't use `UIGraphicsImageRenderer` for AR content
- Don't block main thread with disk I/O
- Don't forget to clear cache on updates
- Don't create thumbnails directory manually (use static method)
- Don't use inconsistent sizes
- Don't leave orphaned files

---

## 🐛 Debugging

### No Thumbnail Appears
1. Check if thumbnail file exists:
   ```swift
   RoomColorManager.hasCustomThumbnail(for: roomURL)
   ```

2. Check console for errors:
   - "⚠️ No preview image available"
   - "❌ Failed to save thumbnail"
   - "⚠️ Failed to capture ARView snapshot"

3. Check file permissions in Documents directory

### Thumbnail Not Updating
1. Verify notification is posted:
   ```swift
   NotificationCenter.default.post(
       name: Notification.Name("RoomThumbnailDidUpdate"),
       object: nil,
       userInfo: ["roomURL": roomURL]
   )
   ```

2. Check cache is cleared:
   ```swift
   thumbnailCache.removeObject(forKey: roomURL as NSURL)
   ```

3. Verify room is in displayFiles (not filtered out)

### Memory Issues
1. Check cache limits are set:
   ```swift
   thumbnailCache.countLimit  // Should be 50
   thumbnailCache.totalCostLimit  // Should be ~50MB
   ```

2. Monitor memory in Xcode Instruments

3. Check for retain cycles in closures

---

## 📊 Performance Metrics

### Target Performance
- **Thumbnail Load**: < 100ms (cached)
- **Thumbnail Save**: < 500ms (background)
- **Memory Usage**: < 50MB for thumbnails
- **Scroll FPS**: 60fps with 50+ rooms

### Monitoring Points
```swift
// Measure cache hit rate
let cacheHits = thumbnailCache.countLimit
let diskLoads = // Count from logs

// Check main thread blocking
// Use Time Profiler in Instruments

// Monitor memory
// Use Allocations instrument
```

---

## 🔧 Maintenance

### Adding New Features
1. Always use `RoomColorManager` for thumbnail operations
2. Post notification after saves
3. Handle errors gracefully
4. Update both THUMBNAIL_ISSUES_ANALYSIS.md and this file

### Testing Checklist
- [ ] New room scan shows thumbnail immediately
- [ ] Color changes update thumbnail
- [ ] Deletion removes thumbnail file
- [ ] Filtering doesn't break updates
- [ ] Memory stays under limit
- [ ] No main thread blocking

---

## 📞 Common Questions

**Q: Why use ARView snapshot instead of UIGraphicsImageRenderer?**
A: ARView snapshot properly captures ARKit 3D content, while UIGraphicsImageRenderer may fail or show blank/black images.

**Q: Why save thumbnail in RoomPreviewViewController?**
A: Users see the preview image before saving. It's the perfect representation of the scanned room.

**Q: Why delete thumbnails when deleting rooms?**
A: Prevents orphaned files and wasted disk space. Clean deletion is important.

**Q: Why use background thread for disk I/O?**
A: Prevents UI stuttering when scrolling through large room collections. Keeps app responsive.

**Q: Why limit cache to 50 items?**
A: Balance between performance and memory. 50 thumbnails ~50MB is reasonable for most devices.

**Q: Can I change thumbnail size?**
A: Yes, but update all locations consistently. Current standard is 400x400 in RoomColorManager.

---

## 🎓 Code Snippets

### Save Thumbnail (Manual)
```swift
// From any view with ARView
arView.snapshot(saveToHDR: false) { image in
    guard let image = image else { return }
    RoomColorManager.saveThumbnail(image, for: roomURL)
    
    // Notify UI to update
    NotificationCenter.default.post(
        name: Notification.Name("RoomThumbnailDidUpdate"),
        object: nil,
        userInfo: ["roomURL": roomURL]
    )
}
```

### Load Thumbnail (Manual)
```swift
// Check cache first
if let cached = thumbnailCache.object(forKey: roomURL as NSURL) {
    imageView.image = cached
    return
}

// Load from disk on background
DispatchQueue.global(qos: .userInitiated).async {
    let thumbnailURL = RoomColorManager.thumbnailURL(for: roomURL)
    guard let data = try? Data(contentsOf: thumbnailURL),
          let image = UIImage(data: data) else { return }
    
    DispatchQueue.main.async {
        self.thumbnailCache.setObject(image, forKey: roomURL as NSURL)
        self.imageView.image = image
    }
}
```

### Delete Thumbnail (Manual)
```swift
RoomColorManager.deleteThumbnail(for: roomURL)
```

---

*Last Updated: February 2, 2026*
