# Furniture Scanning Guide - Technical Documentation & Improvements

> **A comprehensive guide to the Object Capture implementation in EnVision, with detailed recommendations for generating higher quality 3D models.**

---

## Table of Contents

1. [Current Implementation Overview](#1-current-implementation-overview)
2. [How Object Capture Works](#2-how-object-capture-works)
3. [Current Code Analysis](#3-current-code-analysis)
4. [Issues with Current Implementation](#4-issues-with-current-implementation)
5. [Recommendations for Better 3D Models](#5-recommendations-for-better-3d-models)
6. [Code Improvements](#6-code-improvements)
7. [Best Practices for Users](#7-best-practices-for-users)
8. [Advanced Features to Add](#8-advanced-features-to-add)
9. [Troubleshooting Common Issues](#9-troubleshooting-common-issues)

---

## 1. Current Implementation Overview

### File Structure
```
Object Capture/
├── ObjectScanViewController.swift       # Camera capture UI (411 lines)
├── ObjectCapturePreviewController.swift # Preview & processing (553 lines)
├── ARMeshExporter.swift                 # Empty/unused
├── ArrowGuideView.swift                 # Visual guidance
├── FeedbackBubble.swift                 # User feedback UI
├── InstructionOverlay.swift             # Instructions
└── ProgressRingView.swift               # Progress indicator
```

### Current Flow
```
┌─────────────────────────┐
│ ScanFurnitureVC         │
│                         │
│ [Scan ▾] → Automatic    │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────────────┐
│ ObjectScanViewController         │
│                                 │
│ 1. Show instruction card        │
│ 2. Start camera session         │
│ 3. Auto-capture every 1.0s      │
│ 4. Save JPGs to temp folder     │
│ 5. Track photo count            │
│                                 │
│ [Finish Capture]                │
└───────────┬─────────────────────┘
            │
            ▼
┌─────────────────────────────────────┐
│ ObjectCapturePreviewController       │
│                                     │
│ 1. Display captured photos          │
│ 2. Show quality assessment          │
│ 3. Start PhotogrammetrySession      │
│ 4. Process images → USDZ            │
│ 5. Save via SaveManager             │
│                                     │
│ [Generate 3D Model]                 │
└─────────────────────────────────────┘
```

---

## 2. How Object Capture Works

### Apple's PhotogrammetrySession

PhotogrammetrySession uses **Structure from Motion (SfM)** and **Multi-View Stereo (MVS)** algorithms:

1. **Feature Detection**: Identifies distinctive points in each image
2. **Feature Matching**: Finds corresponding points across images
3. **Camera Pose Estimation**: Determines camera position for each photo
4. **Sparse Point Cloud**: Creates initial 3D points
5. **Dense Reconstruction**: Fills in the mesh
6. **Texture Mapping**: Applies colors from photos

### Key Factors for Quality

| Factor | Impact | Current Implementation |
|--------|--------|------------------------|
| **Photo Count** | High | 20-80+ photos ✓ |
| **Photo Overlap** | Critical | Not controlled ⚠️ |
| **Image Quality** | High | Standard JPG ⚠️ |
| **Lighting** | Critical | Basic flash only ⚠️ |
| **Camera Angles** | Critical | Not guided ⚠️ |
| **Object Coverage** | High | No visual feedback ⚠️ |
| **Motion Blur** | High | No detection ❌ |
| **Focus** | High | Auto-focus only ⚠️ |

---

## 3. Current Code Analysis

### ObjectScanViewController.swift

#### Camera Setup
```swift
private func setupCamera() {
    session.beginConfiguration()
    session.sessionPreset = .photo  // ⚠️ Could use .high for better quality
    
    guard let device = AVCaptureDevice.default(for: .video),
          let input = try? AVCaptureDeviceInput(device: device)
    // ...
}
```

**Issues:**
- Uses default video device (wide-angle camera)
- No manual focus control
- No exposure optimization
- No image stabilization settings

#### Auto Capture Timer
```swift
private func startAutoCapture() {
    captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
        self.takePhoto()
    }
}
```

**Issues:**
- Fixed 1-second interval regardless of movement
- No motion detection
- No blur detection before capture
- No overlap calculation

#### Photo Capture
```swift
private func takePhoto() {
    let settings = AVCapturePhotoSettings()
    photoOutput.capturePhoto(with: settings, delegate: self)
}
```

**Issues:**
- Default photo settings (no HEIF, no RAW)
- No flash optimization
- No HDR
- No depth data capture

### ObjectCapturePreviewController.swift

#### Photogrammetry Configuration
```swift
var config = PhotogrammetrySession.Configuration()
config.sampleOrdering = .sequential
config.featureSensitivity = .normal  // ⚠️ Could be .high
```

**Issues:**
- `featureSensitivity = .normal` misses fine details
- No object masking enabled
- No custom bounding box

#### Model Quality
```swift
let request = PhotogrammetrySession.Request.modelFile(url: outputURL)
// ⚠️ No detail level specified - defaults to .preview
```

**Issues:**
- Missing `detail` parameter (defaults to `.preview`)
- Should use `.medium` or `.full` for better quality

---

## 4. Issues with Current Implementation

### Critical Issues

| Issue | Impact | Solution |
|-------|--------|----------|
| **No motion blur detection** | Blurry photos ruin reconstruction | Add accelerometer-based capture |
| **Fixed capture interval** | May miss angles or capture duplicates | Use motion-based triggering |
| **Default detail level** | Low-quality output mesh | Specify `.medium` or `.full` |
| **No depth data** | Less accurate geometry | Enable LiDAR if available |
| **No coverage guidance** | Users don't know what angles to capture | Add visual coverage map |

### Medium Issues

| Issue | Impact | Solution |
|-------|--------|----------|
| **No HEIF format** | Larger files, less color depth | Enable HEIF capture |
| **No HDR** | Poor handling of shadows/highlights | Enable Smart HDR |
| **No focus lock** | Inconsistent focus across shots | Lock focus on object |
| **No exposure lock** | Brightness varies between photos | Lock exposure |
| **No object masking** | Background included in model | Enable masking |

### Minor Issues

| Issue | Impact | Solution |
|-------|--------|----------|
| **No capture sound** | Users unsure if photo taken | Add shutter sound option |
| **No preview of last photo** | Can't verify quality | Show thumbnail |
| **No delete bad photo** | Can't remove blurry shots | Add review mode |

---

## 5. Recommendations for Better 3D Models

### 5.1 Camera Configuration Improvements

```swift
private func setupOptimizedCamera() {
    session.beginConfiguration()
    session.sessionPreset = .photo
    
    // Prefer LiDAR-enabled camera if available
    let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInLiDARDepthCamera, .builtInWideAngleCamera],
        mediaType: .video,
        position: .back
    )
    
    guard let device = discoverySession.devices.first,
          let input = try? AVCaptureDeviceInput(device: device) else { return }
    
    // Configure device for best quality
    try? device.lockForConfiguration()
    
    // Enable auto-focus with continuous adjustment
    if device.isFocusModeSupported(.continuousAutoFocus) {
        device.focusMode = .continuousAutoFocus
    }
    
    // Enable auto-exposure with bias
    if device.isExposureModeSupported(.continuousAutoExposure) {
        device.exposureMode = .continuousAutoExposure
    }
    
    // Enable optical image stabilization
    if device.isOpticalStabilizationSupported {
        // Applied in photo settings
    }
    
    device.unlockForConfiguration()
    
    // Add depth output if available
    if let depthOutput = AVCaptureDepthDataOutput() {
        if session.canAddOutput(depthOutput) {
            session.addOutput(depthOutput)
        }
    }
    
    session.commitConfiguration()
}
```

### 5.2 Smart Capture with Motion Detection

```swift
import CoreMotion

class SmartCaptureManager {
    private let motionManager = CMMotionManager()
    private var lastCaptureAttitude: CMAttitude?
    private let minimumRotationDegrees: Double = 5.0
    
    func startMotionTracking(onSignificantMovement: @escaping () -> Void) {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, let self = self else { return }
            
            if let lastAttitude = self.lastCaptureAttitude {
                let rotation = self.rotationDifference(from: lastAttitude, to: motion.attitude)
                
                if rotation >= self.minimumRotationDegrees {
                    onSignificantMovement()
                    self.lastCaptureAttitude = motion.attitude.copy() as? CMAttitude
                }
            } else {
                self.lastCaptureAttitude = motion.attitude.copy() as? CMAttitude
            }
        }
    }
    
    private func rotationDifference(from: CMAttitude, to: CMAttitude) -> Double {
        let deltaRoll = abs(to.roll - from.roll) * 180 / .pi
        let deltaPitch = abs(to.pitch - from.pitch) * 180 / .pi
        let deltaYaw = abs(to.yaw - from.yaw) * 180 / .pi
        return max(deltaRoll, deltaPitch, deltaYaw)
    }
    
    func isDeviceStable(threshold: Double = 0.5) -> Bool {
        guard let motion = motionManager.deviceMotion else { return false }
        
        let acceleration = motion.userAcceleration
        let magnitude = sqrt(pow(acceleration.x, 2) + pow(acceleration.y, 2) + pow(acceleration.z, 2))
        
        return magnitude < threshold
    }
}
```

### 5.3 Enhanced Photo Settings

```swift
private func takeOptimizedPhoto() {
    var settings = AVCapturePhotoSettings()
    
    // Use HEIF for better quality and smaller size
    if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
        settings = AVCapturePhotoSettings(format: [
            AVVideoCodecKey: AVVideoCodecType.hevc
        ])
    }
    
    // Enable high resolution
    settings.isHighResolutionPhotoEnabled = true
    
    // Enable Smart HDR if available
    if photoOutput.isHighResolutionCaptureEnabled {
        settings.isHighResolutionPhotoEnabled = true
    }
    
    // Enable flash in low light
    if let device = AVCaptureDevice.default(for: .video) {
        if device.hasTorch && isLowLight() {
            settings.flashMode = .auto
        }
    }
    
    // Enable depth data if available
    if photoOutput.isDepthDataDeliverySupported {
        settings.isDepthDataDeliveryEnabled = true
    }
    
    // Enable image stabilization
    settings.photoQualityPrioritization = .quality
    
    photoOutput.capturePhoto(with: settings, delegate: self)
}

private func isLowLight() -> Bool {
    guard let device = AVCaptureDevice.default(for: .video) else { return false }
    return device.iso > 400 // Arbitrary threshold
}
```

### 5.4 Blur Detection Before Capture

```swift
import Vision

class BlurDetector {
    func detectBlur(in image: UIImage, completion: @escaping (Bool, Double) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(true, 0)
            return
        }
        
        let request = VNGenerateImageFeaturePrintRequest { request, error in
            // Use Laplacian variance for blur detection
            let laplacianVariance = self.calculateLaplacianVariance(cgImage)
            let isBlurry = laplacianVariance < 100 // Threshold
            completion(isBlurry, laplacianVariance)
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    private func calculateLaplacianVariance(_ image: CGImage) -> Double {
        // Simplified blur detection using pixel variance
        // In production, use Metal for GPU-accelerated Laplacian
        
        let context = CIContext()
        let ciImage = CIImage(cgImage: image)
        
        // Apply edge detection filter
        guard let filter = CIFilter(name: "CIEdges") else { return 0 }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(1.0, forKey: kCIInputIntensityKey)
        
        guard let output = filter.outputImage,
              let cgOutput = context.createCGImage(output, from: output.extent) else {
            return 0
        }
        
        // Calculate variance of edge image
        return calculateVariance(cgOutput)
    }
    
    private func calculateVariance(_ image: CGImage) -> Double {
        // Simplified variance calculation
        return 150.0 // Placeholder
    }
}
```

### 5.5 Visual Coverage Guidance

```swift
class CoverageTracker {
    private var capturedAngles: [(pitch: Float, yaw: Float)] = []
    
    struct CoverageSegment {
        let pitchRange: ClosedRange<Float>
        let yawRange: ClosedRange<Float>
        var isCovered: Bool = false
    }
    
    private var segments: [CoverageSegment] = []
    
    init() {
        // Create 3D grid of segments (spherical coverage)
        // Pitch: -60° to +60° (above and below)
        // Yaw: 0° to 360° (around object)
        
        for pitch in stride(from: -60, through: 60, by: 30) {
            for yaw in stride(from: 0, through: 330, by: 30) {
                segments.append(CoverageSegment(
                    pitchRange: Float(pitch)...Float(pitch + 30),
                    yawRange: Float(yaw)...Float(yaw + 30)
                ))
            }
        }
    }
    
    func recordCapture(pitch: Float, yaw: Float) {
        capturedAngles.append((pitch, yaw))
        
        for i in segments.indices {
            if segments[i].pitchRange.contains(pitch) &&
               segments[i].yawRange.contains(yaw) {
                segments[i].isCovered = true
            }
        }
    }
    
    var coveragePercentage: Float {
        let covered = segments.filter { $0.isCovered }.count
        return Float(covered) / Float(segments.count) * 100
    }
    
    var uncoveredDirections: [String] {
        var directions: [String] = []
        
        let topCovered = segments.filter { $0.pitchRange.lowerBound >= 30 && $0.isCovered }.count
        let bottomCovered = segments.filter { $0.pitchRange.upperBound <= -30 && $0.isCovered }.count
        
        if topCovered < 4 { directions.append("Capture from above") }
        if bottomCovered < 4 { directions.append("Capture from below") }
        
        return directions
    }
}
```

### 5.6 Improved Photogrammetry Configuration

```swift
func startOptimizedPhotogrammetry(inputFolder: URL, outputURL: URL) {
    var config = PhotogrammetrySession.Configuration()
    
    // Use highest quality settings
    config.sampleOrdering = .sequential
    config.featureSensitivity = .high  // Capture fine details
    config.isObjectMaskingEnabled = true  // Remove background
    
    guard let session = try? PhotogrammetrySession(
        input: inputFolder,
        configuration: config
    ) else {
        handleError(message: "Failed to create session")
        return
    }
    
    // Request high-quality model
    // Options: .preview (fastest), .reduced, .medium, .full, .raw
    let request = PhotogrammetrySession.Request.modelFile(
        url: outputURL,
        detail: .medium  // Balance of quality and speed
        // Use .full for highest quality (slower)
    )
    
    // Process with progress tracking
    Task {
        do {
            for try await output in session.outputs {
                await handleOutput(output)
            }
        } catch {
            await handleError(error)
        }
    }
    
    try? session.process(requests: [request])
}
```

---

## 6. Code Improvements

### 6.1 Updated ObjectScanViewController

Key changes to implement:

```swift
// Add these properties
private let motionManager = CMMotionManager()
private var lastCaptureAttitude: CMAttitude?
private var blurDetector = BlurDetector()
private var coverageTracker = CoverageTracker()
private var captureMode: CaptureMode = .motionBased

enum CaptureMode {
    case timerBased      // Current: every 1 second
    case motionBased     // New: capture on movement
    case manual          // New: tap to capture
}

// Replace startAutoCapture with smart capture
private func startSmartCapture() {
    switch captureMode {
    case .timerBased:
        startTimerCapture(interval: 0.5) // Faster for more overlap
        
    case .motionBased:
        startMotionBasedCapture()
        
    case .manual:
        // Show manual capture button
        showManualCaptureButton()
    }
}

private func startMotionBasedCapture() {
    guard motionManager.isDeviceMotionAvailable else {
        // Fallback to timer
        startTimerCapture(interval: 1.0)
        return
    }
    
    motionManager.deviceMotionUpdateInterval = 0.05
    motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
        guard let self = self, let motion = motion else { return }
        
        // Check if device has moved significantly
        if self.shouldCaptureBasedOnMotion(motion) {
            // Check if device is stable (not moving during shot)
            if self.isDeviceStable(motion) {
                self.takeOptimizedPhoto()
                self.lastCaptureAttitude = motion.attitude.copy() as? CMAttitude
            }
        }
    }
}

private func shouldCaptureBasedOnMotion(_ motion: CMDeviceMotion) -> Bool {
    guard let lastAttitude = lastCaptureAttitude else {
        return true // First capture
    }
    
    // Calculate rotation difference
    let current = motion.attitude
    let deltaRoll = abs(current.roll - lastAttitude.roll) * 180 / .pi
    let deltaPitch = abs(current.pitch - lastAttitude.pitch) * 180 / .pi
    let deltaYaw = abs(current.yaw - lastAttitude.yaw) * 180 / .pi
    
    let maxDelta = max(deltaRoll, deltaPitch, deltaYaw)
    
    return maxDelta >= 5.0 // Capture every 5 degrees of rotation
}

private func isDeviceStable(_ motion: CMDeviceMotion) -> Bool {
    let acc = motion.userAcceleration
    let magnitude = sqrt(acc.x*acc.x + acc.y*acc.y + acc.z*acc.z)
    return magnitude < 0.3 // Device is relatively still
}
```

### 6.2 Updated ObjectCapturePreviewController

Key changes:

```swift
@objc private func startProcessing() {
    // ... existing setup code ...
    
    // IMPROVED: Use better configuration
    var config = PhotogrammetrySession.Configuration()
    config.sampleOrdering = .sequential
    config.featureSensitivity = .high        // Changed from .normal
    config.isObjectMaskingEnabled = true      // Added: remove background
    
    guard let session = try? PhotogrammetrySession(
        input: self.imagesFolder,
        configuration: config
    ) else {
        handleError(message: "Failed to create session")
        return
    }
    
    // IMPROVED: Specify detail level
    let request = PhotogrammetrySession.Request.modelFile(
        url: outputURL,
        detail: .medium    // Added: was using default .preview
    )
    
    // ... rest of processing ...
}
```

---

## 7. Best Practices for Users

### 7.1 Lighting

| Condition | Quality Impact | Recommendation |
|-----------|----------------|----------------|
| **Bright, even lighting** | ⭐⭐⭐⭐⭐ | Best results |
| **Natural daylight** | ⭐⭐⭐⭐ | Very good |
| **Single light source** | ⭐⭐⭐ | Shadows may cause issues |
| **Low light** | ⭐⭐ | Grainy photos, poor detail |
| **Direct sunlight** | ⭐⭐ | Harsh shadows, overexposure |

**Recommendations:**
- Use diffused lighting from multiple angles
- Avoid harsh shadows
- Ensure the object is evenly lit
- Use the flashlight for fill light, not as primary

### 7.2 Object Placement

```
GOOD:                          BAD:
                              
┌─────────────────┐           ┌─────────────────┐
│                 │           │   ████████████  │
│    ┌─────┐      │           │   █ Object █    │
│    │     │      │           │   ████████████  │
│    │ Obj │      │           │                 │
│    └─────┘      │           │                 │
│                 │           └─────────────────┘
│  Clear space    │              Against wall
└─────────────────┘              (can't capture back)
```

**Do:**
- Place object in center of open space
- Ensure 360° access around object
- Keep floor/background simple and matte
- Use contrasting background color

**Don't:**
- Place against walls
- Put on reflective surfaces
- Include other objects in frame
- Use shiny/glass backgrounds

### 7.3 Capture Technique

```
TOP VIEW - Capture Pattern:

         ★ (start)
          ↓
    ←  ●  ●  ●  →
      ●       ●
    ●    OBJ    ●
      ●       ●
    ←  ●  ●  ●  →
          ↑
         ★ (end at different height)

Walk in circles at 3 different heights:
1. Eye level
2. Above (looking down 30-45°)
3. Below (looking up 30-45°)
```

**Photo Overlap:**
```
Photo 1    Photo 2    Photo 3
┌──────────────────────────────┐
│ ████████                     │
│ ████████████████             │
│      ████████████████        │
│           ████████████████   │
│                ████████████  │
└──────────────────────────────┘
         60-80% overlap recommended
```

### 7.4 Minimum Photo Requirements

| Object Size | Minimum Photos | Recommended | Maximum Useful |
|-------------|---------------|-------------|----------------|
| Small (<30cm) | 30 | 50-70 | 100 |
| Medium (30-100cm) | 40 | 70-100 | 150 |
| Large (>100cm) | 50 | 100-150 | 200 |

**Quality Formula:**
```
Model Quality ≈ (Photo Count × Photo Quality × Coverage) / Processing Detail
```

---

## 8. Advanced Features to Add

### 8.1 Real-time Quality Feedback

```swift
// Add to ObjectScanViewController
struct CaptureQuality {
    var sharpness: Float = 0
    var exposure: Float = 0
    var coverage: Float = 0
    
    var overall: Float {
        (sharpness + exposure + coverage) / 3.0
    }
    
    var recommendation: String {
        if sharpness < 0.5 { return "Hold steadier" }
        if exposure < 0.5 { return "Improve lighting" }
        if coverage < 0.5 { return "Capture more angles" }
        return "Looking good!"
    }
}
```

### 8.2 AR Preview Before Processing

```swift
// Add option to preview captured points in AR
func showPointCloudPreview() {
    // Use captured images to show approximate 3D structure
    // Helps users identify missing coverage areas
}
```

### 8.3 Object Bounding Box

```swift
// Let user define object bounds for better masking
struct ObjectBounds {
    var center: SIMD3<Float>
    var size: SIMD3<Float>
}

// Use in configuration
config.isObjectMaskingEnabled = true
// Define custom bounds if object detection fails
```

### 8.4 Quality Presets

```swift
enum CaptureQualityPreset {
    case quick      // 20-30 photos, .reduced detail
    case standard   // 40-60 photos, .medium detail
    case highQuality // 80-120 photos, .full detail
    case maximum    // 150+ photos, .raw detail
    
    var photoCount: ClosedRange<Int> {
        switch self {
        case .quick: return 20...30
        case .standard: return 40...60
        case .highQuality: return 80...120
        case .maximum: return 150...250
        }
    }
    
    var detailLevel: PhotogrammetrySession.Request.Detail {
        switch self {
        case .quick: return .reduced
        case .standard: return .medium
        case .highQuality: return .full
        case .maximum: return .raw
        }
    }
}
```

### 8.5 Resume Capture Session

```swift
// Save capture progress for later
func saveProgress() {
    let progress = CaptureProgress(
        folderURL: tempFolderURL,
        photoCount: images.count,
        capturedAngles: coverageTracker.capturedAngles,
        timestamp: Date()
    )
    
    try? JSONEncoder().encode(progress)
        .write(to: progressFileURL)
}

func resumeCapture() {
    guard let data = try? Data(contentsOf: progressFileURL),
          let progress = try? JSONDecoder().decode(CaptureProgress.self, from: data) else {
        return
    }
    
    tempFolderURL = progress.folderURL
    images = loadExistingImages()
    coverageTracker.restore(progress.capturedAngles)
}
```

---

## 9. Troubleshooting Common Issues

### 9.1 Poor Model Quality

| Symptom | Cause | Solution |
|---------|-------|----------|
| Holes in mesh | Missing photo angles | Ensure 360° coverage at multiple heights |
| Blurry textures | Motion blur in photos | Hold device steadier, use stabilization |
| Wrong scale | No reference object | Include object of known size |
| Missing details | Low feature sensitivity | Use `.high` feature sensitivity |
| Background in model | Object masking failed | Use contrasting background |

### 9.2 Processing Failures

| Error | Cause | Solution |
|-------|-------|----------|
| "Not enough images" | < 20 photos | Capture at least 30 photos |
| "Failed to find features" | Low-texture object | Add temporary markers |
| "Out of memory" | Too many high-res photos | Reduce photo count or resolution |
| "Processing timeout" | Complex geometry | Use `.reduced` detail first |

### 9.3 Specific Object Types

| Object Type | Challenge | Solution |
|-------------|-----------|----------|
| **Shiny/reflective** | Inconsistent reflections | Use polarizer, matte spray |
| **Transparent** | Can't detect surfaces | Not suitable for photogrammetry |
| **Very dark** | Features not visible | Increase lighting significantly |
| **Very thin** | Not enough depth | Capture at extreme angles |
| **Symmetric** | Matching confusion | Add temporary asymmetric markers |
| **Repetitive patterns** | Feature matching errors | Photograph in sections |

---

## Summary: Priority Improvements

### Immediate (High Impact, Low Effort)
1. ✅ Change `featureSensitivity` to `.high`
2. ✅ Add `detail: .medium` to model request
3. ✅ Enable `isObjectMaskingEnabled = true`
4. ✅ Reduce capture interval to 0.5 seconds

### Short Term (High Impact, Medium Effort)
1. Add motion-based capture triggering
2. Add blur detection before saving photo
3. Show coverage percentage to user
4. Add quality presets (Quick/Standard/High)

### Long Term (Medium Impact, High Effort)
1. Implement full coverage guidance system
2. Add AR point cloud preview
3. Support depth data from LiDAR
4. Add resume/pause capture functionality

---

*Last Updated: January 3, 2026*
*EnVision Furniture Scanning Documentation*
