# EnVision Tips & Tour System - Complete Improvement Plan
*Priority: CRITICAL | Status: REMOVED (Needs Rebuild)*

---

## Executive Summary

The Tips & Tour system was **removed from the codebase** on January 21, 2026 due to:
- SwiftUI `TipView` hosting instability in UIKit
- Vertical text artifacts overlaying all screens
- Non-responsive button actions
- Layout conflicts with collection views and navigation bars

**This document outlines a complete rebuild using pure UIKit** (no SwiftUI, no TipKit), ensuring:
- Native iOS feel
- Reliable touch handling
- No layout corruption
- Progressive onboarding that guides users through app features

---

## Table of Contents
1. [Original Vision](#1-original-vision)
2. [What Went Wrong](#2-what-went-wrong)
3. [New Architecture (Pure UIKit)](#3-new-architecture-pure-uikit)
4. [Implementation Phases](#4-implementation-phases)
5. [Visual Design Specs](#5-visual-design-specs)
6. [Code Structure](#6-code-structure)
7. [Testing Plan](#7-testing-plan)
8. [Timeline & Milestones](#8-timeline--milestones)

---

## 1. Original Vision

### 1.1 Purpose
A **TipKit-based progressive onboarding system** that guides users from first launch to advanced features using context-aware tips, managed by a central TourManager, with 25 lightweight tips, a resettable tour, and screen-level integration that shows the right tip at the right time without disrupting the app experience.

### 1.2 Original Tips (25 Total)

#### Getting Started (2 tips)
1. **Welcome** - "Take a tour to learn how to scan rooms and furniture"
2. **Profile** - "Customize your profile and preferences"

#### My Rooms (8 tips)
3. **Intro** - "Scan your first room with LiDAR"
4. **Scan Slowly** - "Move your device slowly for best accuracy"
5. **Import** - "Bring in existing USDZ models"
6. **Actions Menu** - "Select multiple rooms to delete/share"
7. **Categories** - "Organize rooms by type"
8. **Search** - "Find rooms quickly by name"
9. **Room Detail** - "View and edit room metadata"
10. **AR Preview** - "Place furniture in your scanned room"

#### My Furniture (8 tips)
11. **Intro** - "Capture furniture using 360° photogrammetry"
12. **Automatic Capture** - "Walk around object while camera captures"
13. **Photo Count** - "Take 30-50 photos for best quality"
14. **Good Lighting** - "Ensure even lighting and avoid shadows"
15. **360° Coverage** - "Capture all angles of the object"
16. **From Photos** - "Create models from existing photos"
17. **Import USDZ** - "Bring in furniture models from Files"
18. **Categories** - "Organize furniture by type"

#### Profile (7 tips)
19. **Settings** - "Customize app behavior"
20. **Theme** - "Choose light, dark, or system theme"
21. **Notifications** - "Enable scan reminders"
22. **Tips Library** - "Browse all tips anytime"
23. **Restart Tour** - "Reset the app tour"
24. **Export Data** - "Backup your scans to iCloud"
25. **Support** - "Contact us for help"

### 1.3 Original Tour Progression
```
Launch → Welcome Tip (MainTabBarController)
   ↓
My Rooms (0 rooms) → Intro Tip → Scan First Room
   ↓
My Rooms (1 room) → Actions Menu Tip + Categories Tip
   ↓
My Furniture (0 items) → Intro Tip → Capture First Object
   ↓
My Furniture (1 item) → Quality Tips
   ↓
Profile → Settings Tip → Complete Tour
```

---

## 2. What Went Wrong

### 2.1 Technical Issues

#### Issue 1: SwiftUI Hosting in UIKit
```swift
// Old broken approach
let tipView = TipView(WelcomeTip(), arrowEdge: .top)
let host = UIHostingController(rootView: tipView)
view.addSubview(host.view)
```

**Problems**:
- SwiftUI `TipView` has unpredictable layout in UIKit container
- Auto-layout constraints conflict with SwiftUI's layout system
- Views don't clean up properly on dismiss
- Touch events intercepted by SwiftUI layer

#### Issue 2: Global Overlay at Tab Bar Level
```swift
// In MainTabBarController.viewDidAppear
showWelcomeTip() // Added to tabBarController.view
```

**Problems**:
- Tip appears on ALL tabs (leaks across screens)
- Can't be removed reliably when switching tabs
- Vertical text artifact (zero-width constraint issue)
- Blocks touches to tab bar and child view controllers

#### Issue 3: Type Erasure in TipPresenter
```swift
// Invalid Swift code
class TipPresenter: UIHostingController<TipView<(any Tip)>> {
    // Error: 'any Tip' cannot be used as generic parameter
}
```

**Problems**:
- `any Tip` is an existential type, not a concrete type
- Can't be used as generic parameter for `TipView<T: Tip>`
- Causes compile errors or runtime crashes

#### Issue 4: Layout Conflicts in MyRoomsViewController
```swift
// Multiple tip hosting attempts
private var tipContainerView: UIView!
private let tipPresenter = TipPresenter(...)
// Both coexist, causing layout fights
```

**Problems**:
- Two different tip systems in same view controller
- Constraints added/removed unpredictably
- Collection view insets not reset properly
- Tips cover search bar and chip filters

### 2.2 User-Facing Symptoms
- ❌ Vertical line of text ("Welcome to EnVision..." rotated 90°) on every screen
- ❌ Tips appear in wrong locations (covering nav bar, search bar)
- ❌ Buttons don't respond to taps
- ❌ Tips don't dismiss when tapping "Later" or "Got It"
- ❌ App feels "broken" and unprofessional
- ❌ No way to skip or disable tips

---

## 3. New Architecture (Pure UIKit)

### 3.1 Core Principles
1. **No SwiftUI** - Pure UIKit programmatic views
2. **No TipKit** - Custom tip management with TourManager
3. **Container-based** - Tips live inside dedicated containers, not overlays
4. **Layout-safe** - No constraint conflicts with existing UI
5. **Touch-safe** - Tips only intercept touches within their bounds
6. **Dismissible** - Always provide "Later" or "Got It" options
7. **Skippable** - Respect user choice to skip tour

### 3.2 Component Design

#### TipBubbleView (UIView)
A reusable UIView that displays a tip with:
- **Arrow pointer** (CAShapeLayer) pointing to target element
- **Title** (bold, 16pt)
- **Message** (regular, 14pt, 2-3 lines max)
- **Primary action button** (e.g., "Try It", "Scan Now")
- **Dismiss button** (e.g., "Later", "Got It")
- **Close X** (top-right corner, always available)

**Layout**:
```
┌─────────────────────────────┐
│  ×                          │ (close button)
│  Title (bold)               │
│  Message text wraps to 2-3  │
│  lines for readability      │
│  ┌─────────┐  ┌──────────┐ │
│  │ Primary │  │  Later   │ │
│  └─────────┘  └──────────┘ │
└─────────────────────────────┘
        ▼ (arrow pointer)
```

#### TipCoordinator (Manager)
Manages tip lifecycle:
- **Conditions** - Check if tip should show (e.g., "hasSeenWelcomeTip", "roomCount == 0")
- **Show** - Present tip in target view controller's container
- **Dismiss** - Remove tip and mark as seen
- **Skip** - Mark all tips as seen (user choice)
- **Reset** - Clear all seen states (restart tour)

#### TourManager (Existing, Enhanced)
Stores tour state in UserDefaults:
- `hasCompletedTour: Bool`
- `currentTourStep: Int` (0-25)
- `seenTips: Set<String>` (tip IDs that have been shown)
- `tourSkipped: Bool` (user chose to skip)

---

## 4. Implementation Phases

### Phase 1: Core Components (Day 1-2)

#### Task 1.1: Create TipBubbleView
**File**: `Envision/Tips/TipBubbleView.swift`

```swift
import UIKit

final class TipBubbleView: UIView {
    
    enum ArrowEdge {
        case top, bottom, left, right
    }
    
    struct Configuration {
        let title: String
        let message: String
        let primaryActionTitle: String
        let dismissActionTitle: String
        let arrowEdge: ArrowEdge
        let arrowOffset: CGFloat // Horizontal/vertical offset from center
    }
    
    // MARK: - Callbacks
    var onPrimaryAction: (() -> Void)?
    var onDismiss: (() -> Void)?
    
    // MARK: - UI Elements
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let primaryButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let arrowLayer = CAShapeLayer()
    
    private let config: Configuration
    
    // MARK: - Init
    init(configuration: Configuration) {
        self.config = configuration
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Container (rounded rect with shadow)
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.15
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        
        // Arrow (triangle pointer)
        arrowLayer.fillColor = UIColor.systemBackground.cgColor
        layer.addSublayer(arrowLayer)
        
        // Title
        titleLabel.text = config.title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.numberOfLines = 1
        
        // Message
        messageLabel.text = config.message
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 3
        
        // Primary button
        primaryButton.setTitle(config.primaryActionTitle, for: .normal)
        primaryButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        primaryButton.backgroundColor = .systemBlue
        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.layer.cornerRadius = 10
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        
        // Dismiss button
        dismissButton.setTitle(config.dismissActionTitle, for: .normal)
        dismissButton.titleLabel?.font = .systemFont(ofSize: 15)
        dismissButton.setTitleColor(.secondaryLabel, for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        
        // Close button
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .tertiaryLabel
        closeButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        
        // Layout
        [containerView, titleLabel, messageLabel, primaryButton, dismissButton, closeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(messageLabel)
        containerView.addSubview(primaryButton)
        containerView.addSubview(dismissButton)
        containerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            // Container (main bubble)
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: arrowHeight()),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Close button
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Buttons
            primaryButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 16),
            primaryButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            primaryButton.heightAnchor.constraint(equalToConstant: 44),
            primaryButton.widthAnchor.constraint(equalToConstant: 120),
            primaryButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            dismissButton.centerYAnchor.constraint(equalTo: primaryButton.centerYAnchor),
            dismissButton.leadingAnchor.constraint(equalTo: primaryButton.trailingAnchor, constant: 12),
            dismissButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        drawArrow()
    }
    
    private func arrowHeight() -> CGFloat {
        return config.arrowEdge == .top ? 12 : 0
    }
    
    private func drawArrow() {
        let arrowSize: CGFloat = 12
        let path = UIBezierPath()
        
        switch config.arrowEdge {
        case .top:
            let centerX = bounds.width / 2 + config.arrowOffset
            path.move(to: CGPoint(x: centerX, y: 0))
            path.addLine(to: CGPoint(x: centerX - arrowSize, y: arrowSize))
            path.addLine(to: CGPoint(x: centerX + arrowSize, y: arrowSize))
            path.close()
        default:
            break // Add other directions if needed
        }
        
        arrowLayer.path = path.cgPath
    }
    
    @objc private func primaryTapped() {
        onPrimaryAction?()
    }
    
    @objc private func dismissTapped() {
        onDismiss?()
    }
}
```

#### Task 1.2: Create TipCoordinator
**File**: `Envision/Tips/TipCoordinator.swift`

```swift
import UIKit

final class TipCoordinator {
    static let shared = TipCoordinator()
    
    private init() {}
    
    // MARK: - Public API
    
    func showTip(
        id: String,
        configuration: TipBubbleView.Configuration,
        in viewController: UIViewController,
        containerView: UIView,
        onPrimaryAction: @escaping () -> Void
    ) {
        // Check if already seen
        guard !hasSeen(tipID: id), !TourManager.shared.tourSkipped else { return }
        
        // Create tip bubble
        let tipView = TipBubbleView(configuration: configuration)
        tipView.translatesAutoresizingMaskIntoConstraints = false
        tipView.alpha = 0
        
        tipView.onPrimaryAction = { [weak self, weak viewController] in
            self?.markAsSeen(tipID: id)
            self?.dismissTip(from: containerView)
            onPrimaryAction()
        }
        
        tipView.onDismiss = { [weak self] in
            self?.markAsSeen(tipID: id)
            self?.dismissTip(from: containerView)
        }
        
        // Add to container
        containerView.addSubview(tipView)
        NSLayoutConstraint.activate([
            tipView.topAnchor.constraint(equalTo: containerView.topAnchor),
            tipView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            tipView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
        
        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0.2, options: .curveEaseOut) {
            tipView.alpha = 1
        }
    }
    
    func dismissTip(from containerView: UIView) {
        guard let tipView = containerView.subviews.first(where: { $0 is TipBubbleView }) else { return }
        
        UIView.animate(withDuration: 0.2, animations: {
            tipView.alpha = 0
        }) { _ in
            tipView.removeFromSuperview()
        }
    }
    
    // MARK: - State Management
    
    private func hasSeen(tipID: String) -> Bool {
        return TourManager.shared.seenTips.contains(tipID)
    }
    
    private func markAsSeen(tipID: String) {
        TourManager.shared.markTipAsSeen(tipID)
    }
}
```

#### Task 1.3: Enhance TourManager
**File**: `Envision/Managers/TourManager.swift`

```swift
// Add these properties and methods

var seenTips: Set<String> {
    get {
        guard let array = UserDefaults.standard.array(forKey: "seenTips") as? [String] else {
            return []
        }
        return Set(array)
    }
    set {
        UserDefaults.standard.set(Array(newValue), forKey: "seenTips")
    }
}

var tourSkipped: Bool {
    get { UserDefaults.standard.bool(forKey: "tourSkipped") }
    set { UserDefaults.standard.set(newValue, forKey: "tourSkipped") }
}

func markTipAsSeen(_ tipID: String) {
    var seen = seenTips
    seen.insert(tipID)
    seenTips = seen
}

func skipTour() {
    tourSkipped = true
}

func resetTour() {
    hasCompletedTour = false
    currentTourStep = 0
    seenTips = []
    tourSkipped = false
}
```

---

### Phase 2: Tip Definitions (Day 2-3)

#### Task 2.1: Define Tip Content
**File**: `Envision/Tips/TipDefinitions.swift`

```swift
import UIKit

struct TipDefinition {
    let id: String
    let title: String
    let message: String
    let primaryActionTitle: String
    let dismissActionTitle: String
    let arrowEdge: TipBubbleView.ArrowEdge
}

enum AppTips {
    
    // MARK: - Welcome
    static let welcome = TipDefinition(
        id: "welcome",
        title: "Welcome to EnVision",
        message: "Scan rooms with LiDAR and capture furniture with photogrammetry.",
        primaryActionTitle: "Start Tour",
        dismissActionTitle: "Skip",
        arrowEdge: .top
    )
    
    // MARK: - My Rooms
    static let roomsIntro = TipDefinition(
        id: "rooms_intro",
        title: "Scan Your First Room",
        message: "Tap the camera button to start scanning with LiDAR.",
        primaryActionTitle: "Try It",
        dismissActionTitle: "Later",
        arrowEdge: .top
    )
    
    static let roomImport = TipDefinition(
        id: "room_import",
        title: "Import Existing Models",
        message: "Already have USDZ files? Import them from Files app.",
        primaryActionTitle: "Import",
        dismissActionTitle: "Later",
        arrowEdge: .top
    )
    
    static let roomActions = TipDefinition(
        id: "room_actions",
        title: "Manage Your Rooms",
        message: "Select multiple rooms to delete or share at once.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later",
        arrowEdge: .top
    )
    
    static let roomCategories = TipDefinition(
        id: "room_categories",
        title: "Organize by Category",
        message: "Filter rooms by type: Living Room, Bedroom, Kitchen, etc.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later",
        arrowEdge: .top
    )
    
    // MARK: - My Furniture
    static let furnitureIntro = TipDefinition(
        id: "furniture_intro",
        title: "Capture Furniture",
        message: "Use 360° photogrammetry to create 3D models of objects.",
        primaryActionTitle: "Try It",
        dismissActionTitle: "Later",
        arrowEdge: .top
    )
    
    static let furnitureQuality = TipDefinition(
        id: "furniture_quality",
        title: "Best Results",
        message: "Walk slowly around the object. Capture 30-50 photos for high quality.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later",
        arrowEdge: .top
    )
    
    // MARK: - Profile
    static let profileSettings = TipDefinition(
        id: "profile_settings",
        title: "Customize Settings",
        message: "Change theme, enable notifications, and manage preferences.",
        primaryActionTitle: "Open Settings",
        dismissActionTitle: "Later",
        arrowEdge: .top
    )
    
    static let tipsLibrary = TipDefinition(
        id: "tips_library",
        title: "Browse All Tips",
        message: "View all tips and tutorials anytime from here.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later",
        arrowEdge: .top
    )
}
```

---

### Phase 3: Screen Integration (Day 3-5)

#### Task 3.1: MyRoomsViewController Tips
**File**: `Envision/Screens/MainTabs/Rooms/MyRoomsViewController.swift`

```swift
// Add these properties
private var tipContainerView: UIView!

// In viewDidLoad()
setupTipContainer()

// Add method
private func setupTipContainer() {
    tipContainerView = UIView()
    tipContainerView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(tipContainerView)
    
    NSLayoutConstraint.activate([
        tipContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
        tipContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        tipContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
    ])
}

// In viewDidAppear()
showContextualTips()

private func showContextualTips() {
    if rooms.isEmpty {
        // Show intro tip
        TipCoordinator.shared.showTip(
            id: AppTips.roomsIntro.id,
            configuration: TipBubbleView.Configuration(
                title: AppTips.roomsIntro.title,
                message: AppTips.roomsIntro.message,
                primaryActionTitle: AppTips.roomsIntro.primaryActionTitle,
                dismissActionTitle: AppTips.roomsIntro.dismissActionTitle,
                arrowEdge: .top,
                arrowOffset: 0
            ),
            in: self,
            containerView: tipContainerView
        ) { [weak self] in
            // Primary action: trigger scan
            self?.scanButtonTapped()
        }
    } else if rooms.count == 1 {
        // Show actions menu tip
        TipCoordinator.shared.showTip(
            id: AppTips.roomActions.id,
            configuration: TipBubbleView.Configuration(
                title: AppTips.roomActions.title,
                message: AppTips.roomActions.message,
                primaryActionTitle: AppTips.roomActions.primaryActionTitle,
                dismissActionTitle: AppTips.roomActions.dismissActionTitle,
                arrowEdge: .top,
                arrowOffset: 0
            ),
            in: self,
            containerView: tipContainerView
        ) { }
    }
}
```

#### Task 3.2: ScanFurnitureViewController Tips
Similar pattern to MyRoomsViewController.

#### Task 3.3: ProfileViewController Tips
Similar pattern, show settings tip on first visit.

---

### Phase 4: Welcome Flow (Day 5-6)

#### Task 4.1: Welcome Tip in SplashViewController
**File**: `Envision/Screens/Onboarding/SplashViewController.swift`

```swift
// After animation completes in goNext()
private func goNext() {
    // ... existing animation code ...
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
        guard let self = self else { return }
        
        if TourManager.shared.hasCompletedTour || TourManager.shared.tourSkipped {
            // Skip onboarding, go straight to main app (if logged in)
            if UserManager.shared.isLoggedIn {
                self.showMainApp()
            } else {
                self.showOnboarding()
            }
        } else {
            // First-time user: show onboarding
            self.showOnboarding()
        }
    }
}
```

#### Task 4.2: Welcome Tip in MainTabBarController
**File**: `Envision/MainTabBarController.swift`

```swift
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    showWelcomeTipIfNeeded()
}

private func showWelcomeTipIfNeeded() {
    guard !TourManager.shared.hasSeen(tipID: AppTips.welcome.id) else { return }
    
    let alert = UIAlertController(
        title: AppTips.welcome.title,
        message: AppTips.welcome.message,
        preferredStyle: .alert
    )
    
    alert.addAction(UIAlertAction(title: "Start Tour", style: .default) { _ in
        TourManager.shared.startTour()
        TourManager.shared.markTipAsSeen(AppTips.welcome.id)
    })
    
    alert.addAction(UIAlertAction(title: "Skip", style: .cancel) { _ in
        TourManager.shared.skipTour()
    })
    
    present(alert, animated: true)
}
```

---

### Phase 5: Testing & Polish (Day 6-7)

#### Task 5.1: Manual Testing
- [ ] Fresh install: welcome tip shows
- [ ] Skip tour: no more tips appear
- [ ] Start tour: tips appear in correct sequence
- [ ] Tip dismissal: "Later" button works
- [ ] Tip action: "Try It" button navigates correctly
- [ ] Restart tour: all tips show again
- [ ] Multiple screens: tips don't leak across tabs
- [ ] Rotation: tips reposition correctly
- [ ] Dark mode: tips use system colors
- [ ] Accessibility: VoiceOver reads tip content

#### Task 5.2: Edge Cases
- [ ] User logs out mid-tour: tour state preserved
- [ ] User deletes all rooms: intro tip shows again
- [ ] App backgrounds mid-tip: tip still visible on return
- [ ] Rapid tab switching: no multiple tips stacked

---

## 5. Visual Design Specs

### 5.1 Colors
```swift
// Light Mode
backgroundColor: .systemBackground (white)
titleColor: .label (black)
messageColor: .secondaryLabel (gray)
primaryButtonBg: .systemBlue
primaryButtonText: .white
dismissButtonText: .secondaryLabel
closeButtonTint: .tertiaryLabel
shadowColor: UIColor.black.withAlphaComponent(0.15)

// Dark Mode (automatic via system colors)
backgroundColor: .systemBackground (dark gray)
titleColor: .label (white)
// ... etc
```

### 5.2 Typography
```swift
title: .systemFont(ofSize: 16, weight: .semibold)
message: .systemFont(ofSize: 14, weight: .regular)
primaryButton: .systemFont(ofSize: 15, weight: .semibold)
dismissButton: .systemFont(ofSize: 15, weight: .regular)
```

### 5.3 Spacing
```swift
containerPadding: 16pt
cornerRadius: 16pt
buttonHeight: 44pt
buttonCornerRadius: 10pt
arrowHeight: 12pt
shadowRadius: 12pt
shadowOffset: (0, 4)
```

### 5.4 Animation
```swift
fadeIn: 0.3s, easeOut, delay 0.2s
fadeOut: 0.2s, easeIn
springAnimation: damping 0.7, velocity 0.5
```

---

## 6. Code Structure

### 6.1 New Files to Create
```
Envision/Tips/
├── TipBubbleView.swift          (350 lines)
├── TipCoordinator.swift         (120 lines)
├── TipDefinitions.swift         (200 lines, all 25 tips)
└── README.md                    (Usage guide)
```

### 6.2 Files to Modify
```
Envision/Managers/
└── TourManager.swift            (Add seenTips, tourSkipped)

Envision/Screens/Onboarding/
└── SplashViewController.swift   (Add tour check in goNext)

Envision/MainTabBarController.swift (Add welcome alert)

Envision/Screens/MainTabs/Rooms/
└── MyRoomsViewController.swift  (Add tipContainerView, showContextualTips)

Envision/Screens/MainTabs/furniture/
└── ScanFurnitureViewController.swift (Add tips)

Envision/Screens/MainTabs/profile/
└── ProfileViewController.swift  (Add tips)
```

### 6.3 Files to Keep Unchanged
```
Envision/Screens/MainTabs/profile/SubScreens/
└── TipsLibraryViewController.swift  (Static tips list, no changes)
```

---

## 7. Testing Plan

### 7.1 Unit Tests
```swift
// TourManagerTests.swift
func testMarkTipAsSeen() {
    TourManager.shared.resetTour()
    TourManager.shared.markTipAsSeen("test_tip")
    XCTAssertTrue(TourManager.shared.seenTips.contains("test_tip"))
}

func testSkipTour() {
    TourManager.shared.skipTour()
    XCTAssertTrue(TourManager.shared.tourSkipped)
}

func testResetTour() {
    TourManager.shared.markTipAsSeen("test_tip")
    TourManager.shared.skipTour()
    TourManager.shared.resetTour()
    XCTAssertFalse(TourManager.shared.tourSkipped)
    XCTAssertEqual(TourManager.shared.seenTips.count, 0)
}
```

### 7.2 UI Tests
```swift
// TipsUITests.swift
func testWelcomeTipAppears() {
    app.launch()
    // Reset tour state first
    XCTAssertTrue(app.alerts["Welcome to EnVision"].waitForExistence(timeout: 3))
}

func testTipDismissal() {
    app.buttons["Later"].tap()
    XCTAssertFalse(app.otherElements["TipBubbleView"].exists)
}

func testSkipTour() {
    app.buttons["Skip"].tap()
    // Verify no more tips appear
}
```

### 7.3 Manual Test Script
```markdown
## Test Case 1: Fresh Install
1. Delete app
2. Clean build & run
3. Verify welcome alert appears after splash
4. Tap "Start Tour"
5. Navigate to My Rooms
6. Verify "Scan Your First Room" tip appears
7. Tap "Try It"
8. Verify tip dismisses and scan starts

## Test Case 2: Skip Tour
1. Fresh install
2. Tap "Skip" on welcome alert
3. Navigate through all tabs
4. Verify NO tips appear
5. Go to Profile → Restart App Tour
6. Verify tips appear again

## Test Case 3: Layout Integrity
1. Show tip in My Rooms
2. Verify tip doesn't overlap search bar
3. Verify collection view scrolls normally
4. Tap on room cell (should work, not blocked by tip)
5. Rotate device (if applicable)
6. Verify tip repositions correctly

## Test Case 4: Dark Mode
1. Enable Dark Mode in Settings
2. Trigger tip
3. Verify colors use system palette
4. Verify text is readable
```

---

## 8. Timeline & Milestones

### Week 1: Foundation
**Day 1-2**: Core Components
- ✅ TipBubbleView with arrow pointer
- ✅ TipCoordinator for lifecycle
- ✅ Enhanced TourManager

**Day 3**: Tip Definitions
- ✅ TipDefinitions.swift with all 25 tips
- ✅ Content review & copywriting

**Day 4-5**: Screen Integration
- ✅ MyRoomsViewController tips
- ✅ ScanFurnitureViewController tips
- ✅ ProfileViewController tips

**Day 6**: Welcome Flow
- ✅ SplashViewController tour check
- ✅ MainTabBarController welcome alert

**Day 7**: Testing & Polish
- ✅ Manual testing all flows
- ✅ Bug fixes
- ✅ Animation tuning

### Week 2: Validation
**Day 8-9**: Beta Testing
- Internal testing (team)
- Edge case discovery
- Accessibility audit

**Day 10**: Final Fixes
- Address beta feedback
- Performance optimization
- Code review

**Day 11**: Documentation
- Update README
- Usage guide for tips
- API documentation

**Day 12**: Release
- Merge to main
- Deploy to TestFlight
- Monitor crash reports

---

## Success Metrics

### Technical
- ✅ Zero SwiftUI dependencies
- ✅ Zero TipKit dependencies
- ✅ No layout constraint errors in console
- ✅ Tips dismiss reliably (100% success rate)
- ✅ Buttons respond to first tap (no double-tap needed)
- ✅ No vertical text artifacts
- ✅ Tips don't block critical UI

### User Experience
- ✅ Tour completion rate > 60%
- ✅ Skip rate < 40%
- ✅ Tip dismissal time < 5 seconds (engaged users read and act)
- ✅ Zero "tips broken" support tickets
- ✅ Positive feedback in App Store reviews mentioning onboarding

---

## Rollback Plan

If new tips system causes issues:
1. Comment out `showContextualTips()` calls (1 line per screen)
2. Tips disappear, app functions normally
3. Investigate issue offline
4. Re-enable when fixed

**Critical**: Tips are non-blocking feature. App must work perfectly without them.

---

## Appendix: Comparison Table

| Aspect | Old (TipKit) | New (UIKit) |
|--------|--------------|-------------|
| Framework | SwiftUI TipView | Pure UIKit |
| Dependencies | TipKit (iOS 17+) | None |
| Layout | SwiftUI auto-layout | UIKit constraints |
| Touch Handling | SwiftUI gestures | UIButton actions |
| Stability | ❌ Unreliable | ✅ Predictable |
| Customization | ⚠️ Limited | ✅ Full control |
| Debugging | ❌ Hard | ✅ Easy |
| Maintenance | ❌ Breaking changes | ✅ Stable |
| Lines of Code | ~500 (with workarounds) | ~700 (clean) |

---

**Document Version**: 1.0  
**Status**: Ready for Implementation  
**Priority**: CRITICAL  
**Estimated Effort**: 7-12 days  
**Risk**: Low (fallback available)  

---

*End of Tips & Tour Improvement Plan*
