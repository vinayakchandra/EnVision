import UIKit

struct TipDefinition {
    let id: String
    let title: String
    let message: String
    let primaryActionTitle: String
    let dismissActionTitle: String
    let arrowEdge: TipBubbleView.ArrowEdge
    let arrowOffset: CGFloat

    init(
        id: String,
        title: String,
        message: String,
        primaryActionTitle: String,
        dismissActionTitle: String,
        arrowEdge: TipBubbleView.ArrowEdge = .top,
        arrowOffset: CGFloat = 0
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.primaryActionTitle = primaryActionTitle
        self.dismissActionTitle = dismissActionTitle
        self.arrowEdge = arrowEdge
        self.arrowOffset = arrowOffset
    }
}

enum AppTips {

    // MARK: - Getting Started
    static let welcome = TipDefinition(
        id: "welcome",
        title: "Welcome to EnVision",
        message: "Take a quick tour to learn room scanning and furniture capture.",
        primaryActionTitle: "Start Tour",
        dismissActionTitle: "Skip"
    )

    static let profileIntro = TipDefinition(
        id: "profile_intro",
        title: "Set Up Your Profile",
        message: "Customize your profile and app preferences to get started.",
        primaryActionTitle: "Open Profile",
        dismissActionTitle: "Later"
    )

    // MARK: - My Rooms (8)
    static let roomsIntro = TipDefinition(
        id: "rooms_intro",
        title: "Scan Your First Room",
        message: "Tap the camera button to start scanning with LiDAR.",
        primaryActionTitle: "Try It",
        dismissActionTitle: "Later"
    )

    static let roomScanSlowly = TipDefinition(
        id: "room_scan_slowly",
        title: "Scan Slowly",
        message: "Move your device slowly and keep walls in view for better accuracy.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let roomImport = TipDefinition(
        id: "room_import",
        title: "Import Existing Models",
        message: "Already have USDZ files? Import them from Files.",
        primaryActionTitle: "Import",
        dismissActionTitle: "Later"
    )

    static let roomActions = TipDefinition(
        id: "room_actions",
        title: "Manage Multiple Rooms",
        message: "Use the actions menu to select, delete, or share rooms in bulk.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let roomCategories = TipDefinition(
        id: "room_categories",
        title: "Organize by Category",
        message: "Filter rooms by type like living room, bedroom, and kitchen.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let roomSearch = TipDefinition(
        id: "room_search",
        title: "Search Faster",
        message: "Use search to quickly find a room by model name.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let roomDetail = TipDefinition(
        id: "room_detail",
        title: "Room Details",
        message: "Open a room to inspect metadata and manage your model.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let roomARPreview = TipDefinition(
        id: "room_ar_preview",
        title: "AR Preview",
        message: "Preview scanned rooms with furniture in augmented reality.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let roomLongPress = TipDefinition(
        id: "room_long_press",
        title: "Long-Press for Quick Actions",
        message: "Hold any room thumbnail to rename, share, view in AR, change its category, or delete — all without opening it.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    // MARK: - My Furniture (9)
    static let furnitureIntro = TipDefinition(
        id: "furniture_intro",
        title: "Capture Furniture",
        message: "Use 360° capture to create a furniture model.",
        primaryActionTitle: "Try It",
        dismissActionTitle: "Later"
    )

    static let furnitureAutomaticCapture = TipDefinition(
        id: "furniture_auto_capture",
        title: "Automatic Capture",
        message: "Walk around the object while the app guides capture quality.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let furniturePhotoCount = TipDefinition(
        id: "furniture_photo_count",
        title: "Capture Enough Photos",
        message: "Aim for 30-50 photos for high-quality reconstruction.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let furnitureQuality = TipDefinition(
        id: "furniture_quality",
        title: "Best Results",
        message: "Walk slowly around the object with stable lighting for cleaner meshes.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let furnitureLighting = TipDefinition(
        id: "furniture_lighting",
        title: "Use Good Lighting",
        message: "Prefer even lighting and avoid harsh shadows.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let furnitureCoverage = TipDefinition(
        id: "furniture_coverage",
        title: "Capture Full 360°",
        message: "Cover all sides and heights of the object before finishing.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let furnitureFromPhotos = TipDefinition(
        id: "furniture_from_photos",
        title: "Create From Photos",
        message: "Build models from an existing photo set when needed.",
        primaryActionTitle: "Try It",
        dismissActionTitle: "Later"
    )

    static let furnitureImportUSDZ = TipDefinition(
        id: "furniture_import_usdz",
        title: "Import USDZ Models",
        message: "Bring furniture models from Files into your library.",
        primaryActionTitle: "Import",
        dismissActionTitle: "Later"
    )

    static let furnitureLongPress = TipDefinition(
        id: "furniture_long_press",
        title: "Long-Press for Quick Actions",
        message: "Hold any furniture thumbnail to rename, share, preview, recategorize, or delete without opening it.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let furnitureCategories = TipDefinition(
        id: "furniture_categories",
        title: "Organize Furniture",
        message: "Assign categories to keep your model library easy to browse.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    // MARK: - Profile (7)
    static let profileSettings = TipDefinition(
        id: "profile_settings",
        title: "Customize Settings",
        message: "Adjust appearance, notifications, and preferences.",
        primaryActionTitle: "Open Settings",
        dismissActionTitle: "Later"
    )

    static let profileTheme = TipDefinition(
        id: "profile_theme",
        title: "Choose Theme",
        message: "Pick light, dark, or system mode in Appearance settings.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let profileNotifications = TipDefinition(
        id: "profile_notifications",
        title: "Notification Preferences",
        message: "Enable reminders to keep your scans and captures on track.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let profileTipsLibrary = TipDefinition(
        id: "profile_tips_library",
        title: "Tips Library",
        message: "Open Tips & Tutorials anytime for guidance.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let profileRestartTour = TipDefinition(
        id: "profile_restart_tour",
        title: "Restart Tour",
        message: "Use Restart App Tour to replay onboarding tips.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let profileExportData = TipDefinition(
        id: "profile_export_data",
        title: "Export Data",
        message: "Back up your scans and models to keep your work safe.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let profileSupport = TipDefinition(
        id: "profile_support",
        title: "Need Help?",
        message: "Check App Info and policies for support resources.",
        primaryActionTitle: "Got It",
        dismissActionTitle: "Later"
    )

    static let allTipIDs: [String] = [
        welcome.id,
        profileIntro.id,
        // Rooms
        roomsIntro.id,
        roomScanSlowly.id,
        roomImport.id,
        roomActions.id,
        roomLongPress.id,
        roomCategories.id,
        roomSearch.id,
        roomDetail.id,
        roomARPreview.id,
        // Furniture
        furnitureIntro.id,
        furnitureAutomaticCapture.id,
        furniturePhotoCount.id,
        furnitureQuality.id,
        furnitureLighting.id,
        furnitureCoverage.id,
        furnitureFromPhotos.id,
        furnitureImportUSDZ.id,
        furnitureLongPress.id,
        furnitureCategories.id,
        // Profile
        profileSettings.id,
        profileTheme.id,
        profileNotifications.id,
        profileTipsLibrary.id,
        profileRestartTour.id,
        profileExportData.id,
        profileSupport.id,
    ]

    static let roomTourTipIDs: [String] = [
        roomsIntro.id,
        roomScanSlowly.id,
        roomImport.id,
        roomActions.id,
        roomLongPress.id,
        roomCategories.id,
        roomSearch.id,
        roomDetail.id,
        roomARPreview.id,
    ]

    static let furnitureTourTipIDs: [String] = [
        furnitureIntro.id,
        furnitureAutomaticCapture.id,
        furniturePhotoCount.id,
        furnitureQuality.id,
        furnitureFromPhotos.id,
        furnitureImportUSDZ.id,
        furnitureLongPress.id,
        furnitureCategories.id,
    ]

    /// Tips that define completion of the core onboarding journey.
    /// Data-shape-dependent tips (e.g. empty library states) are intentionally excluded.
    static let completionTipIDs: [String] = [
        welcome.id,
        profileIntro.id,
        profileSettings.id,
        profileTheme.id,
        profileNotifications.id,
        profileTipsLibrary.id,
        profileRestartTour.id,
        profileExportData.id,
        profileSupport.id,
    ]
}
