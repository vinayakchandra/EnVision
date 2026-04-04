//
//  TourManager.swift
//  Envision
//
//  Created for EnVision Tips & Tour System
//  Version: 1.0
//

import Foundation

/// Centralized manager for tour state, progress tracking, and tour lifecycle
final class TourManager {
    
    // MARK: - Singleton
    
    static let shared = TourManager()
    private let tipsEnabled = true
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let tourCompletedKey = "app_tour_completed"
    private let tourStepKey = "current_tour_step"
    private let hasSeenWelcomeKey = "has_seen_welcome"
    private let firstLaunchKey = "is_first_launch"
    private let seenTipsKey = "seen_tips"
    private let tourSkippedKey = "tour_skipped"
    private let roomToFurnitureHandoffShownKey = "room_to_furniture_handoff_shown"
    
    // MARK: - Public Properties
    
    /// Whether the tour has been completed
    var isTourCompleted: Bool {
        get { userDefaults.bool(forKey: tourCompletedKey) }
        set { userDefaults.set(newValue, forKey: tourCompletedKey) }
    }

    /// Alias used by tips flow documentation.
    var hasCompletedTour: Bool {
        get { isTourCompleted }
        set { isTourCompleted = newValue }
    }
    
    /// Current step in the tour sequence (0-based)
    var currentTourStep: Int {
        get { userDefaults.integer(forKey: tourStepKey) }
        set { userDefaults.set(newValue, forKey: tourStepKey) }
    }
    
    /// Whether user has seen the welcome tip
    var hasSeenWelcome: Bool {
        get { userDefaults.bool(forKey: hasSeenWelcomeKey) }
        set { userDefaults.set(newValue, forKey: hasSeenWelcomeKey) }
    }

    /// Whether user skipped the tour explicitly.
    var tourSkipped: Bool {
        get { userDefaults.bool(forKey: tourSkippedKey) }
        set { userDefaults.set(newValue, forKey: tourSkippedKey) }
    }

    /// Set of tip IDs that have already been shown/dismissed.
    var seenTips: Set<String> {
        get {
            let ids = userDefaults.stringArray(forKey: seenTipsKey) ?? []
            return Set(ids)
        }
        set {
            userDefaults.set(Array(newValue), forKey: seenTipsKey)
        }
    }
    
    /// Whether this is the first app launch
    var isFirstLaunch: Bool {
        get { !userDefaults.bool(forKey: firstLaunchKey) }
        set { userDefaults.set(!newValue, forKey: firstLaunchKey) }
    }

    /// Whether the room-tour completion handoff to furniture tab has already been shown.
    var roomToFurnitureHandoffShown: Bool {
        get { userDefaults.bool(forKey: roomToFurnitureHandoffShownKey) }
        set { userDefaults.set(newValue, forKey: roomToFurnitureHandoffShownKey) }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Check if first launch
        if isFirstLaunch {
            print(" First launch detected - Tour will be shown")
        }
    }
    
    // MARK: - Tour Control Methods
    
    /// Determines if the tour should be shown
    /// - Returns: Bool indicating if tour should be shown
    func shouldShowTour() -> Bool {
        if !tipsEnabled {
            return false
        }

        // Don't show if already completed
        if isTourCompleted || tourSkipped {
            return false
        }
        
        // Show for first-time users or users who haven't completed
        return isFirstLaunch || !hasSeenWelcome
    }
    
    /// Initiates the tour sequence
    func startTour() {
        guard tipsEnabled else { return }
        currentTourStep = 0
        isTourCompleted = false
        tourSkipped = false
        roomToFurnitureHandoffShown = false
        hasSeenWelcome = true
        isFirstLaunch = false
        print("🎬 Tour started")
    }
    
    /// Marks the tour as completed
    func completeTour() {
        guard tipsEnabled else { return }
        isTourCompleted = true
        currentTourStep = 0
        tourSkipped = false
        print(" Tour completed")
    }
    
    /// Resets all tour progress and tips. Always executes — not blocked by tipsEnabled,
    /// because this is a user-initiated action from Profile → Restart Tour.
    func resetTour() {
        isTourCompleted = false
        currentTourStep = 0
        hasSeenWelcome = false
        tourSkipped = false
        roomToFurnitureHandoffShown = false
        seenTips = []
        print("🔄 Tour reset complete")
    }

    func skipTour() {
        guard tipsEnabled else { return }
        tourSkipped = true
        print(" Tour skipped")
    }
    
    /// Advances to the next tour step
    func nextStep() {
        guard tipsEnabled else { return }
        currentTourStep += 1
        print(" Tour step: \(currentTourStep)")
    }
    
    /// Skips to a specific step
    /// - Parameter step: The step number to skip to
    func skipToStep(_ step: Int) {
        guard tipsEnabled else { return }
        currentTourStep = step
        print(" Skipped to step: \(step)")
    }

    // MARK: - Tip Persistence

    func hasSeen(tipID: String) -> Bool {
        if !tipsEnabled {
            return true
        }
        return seenTips.contains(tipID)
    }

    func markTipAsSeen(_ tipID: String) {
        guard tipsEnabled else { return }
        var seen = seenTips
        seen.insert(tipID)
        seenTips = seen
    }
    
    // MARK: - Helper Methods
    
    /// Checks if user has any rooms
    func hasRooms() -> Bool {
        return !SaveManager.shared.getSavedModels(type: .room).isEmpty
    }
    
    /// Checks if user has any furniture
    func hasFurniture() -> Bool {
        return !SaveManager.shared.getSavedModels(type: .furniture).isEmpty
    }
    
    /// Checks if user has both rooms and furniture
    func hasRoomsAndFurniture() -> Bool {
        return hasRooms() && hasFurniture()
    }
    
    /// Gets the count of rooms
    func roomCount() -> Int {
        return SaveManager.shared.getSavedModels(type: .room).count
    }
    
    /// Gets the count of furniture
    func furnitureCount() -> Int {
        return SaveManager.shared.getSavedModels(type: .furniture).count
    }
    
    // MARK: - Debug Methods
    
    #if DEBUG
    func debugPrintState() {
        print("""
        ═══════════════════════════════════
        TOUR DEBUG STATE
        ═══════════════════════════════════
        Is First Launch: \(isFirstLaunch)
        Tour Completed: \(isTourCompleted)
        Tour Skipped: \(tourSkipped)
        Current Step: \(currentTourStep)
        Has Seen Welcome: \(hasSeenWelcome)
        Seen Tips Count: \(seenTips.count)
        Should Show Tour: \(shouldShowTour())
        Has Rooms: \(hasRooms())
        Has Furniture: \(hasFurniture())
        Room Count: \(roomCount())
        Furniture Count: \(furnitureCount())
        ═══════════════════════════════════
        """)
    }
    
    func forceShowTour() {
        resetTour()
        print(" Tour forced to show")
    }
    #endif
}
