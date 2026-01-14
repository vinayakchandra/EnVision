//
//  TourManager.swift
//  Envision
//
//  Created for EnVision Tips & Tour System
//  Version: 1.0
//

import Foundation
import TipKit

/// Centralized manager for tour state, progress tracking, and tour lifecycle
final class TourManager {
    
    // MARK: - Singleton
    
    static let shared = TourManager()
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let tourCompletedKey = "app_tour_completed"
    private let tourStepKey = "current_tour_step"
    private let hasSeenWelcomeKey = "has_seen_welcome"
    private let firstLaunchKey = "is_first_launch"
    
    // MARK: - Public Properties
    
    /// Whether the tour has been completed
    var isTourCompleted: Bool {
        get { userDefaults.bool(forKey: tourCompletedKey) }
        set { userDefaults.set(newValue, forKey: tourCompletedKey) }
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
    
    /// Whether this is the first app launch
    var isFirstLaunch: Bool {
        get { !userDefaults.bool(forKey: firstLaunchKey) }
        set { userDefaults.set(!newValue, forKey: firstLaunchKey) }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Check if first launch
        if isFirstLaunch {
            print("📱 First launch detected - Tour will be shown")
        }
    }
    
    // MARK: - Tour Control Methods
    
    /// Determines if the tour should be shown
    /// - Returns: Bool indicating if tour should be shown
    func shouldShowTour() -> Bool {
        // Don't show if already completed
        if isTourCompleted {
            return false
        }
        
        // Show for first-time users or users who haven't completed
        return isFirstLaunch || !hasSeenWelcome
    }
    
    /// Initiates the tour sequence
    func startTour() {
        currentTourStep = 0
        isTourCompleted = false
        hasSeenWelcome = true
        isFirstLaunch = false
        print("🎬 Tour started")
    }
    
    /// Marks the tour as completed
    func completeTour() {
        isTourCompleted = true
        currentTourStep = 0
        print("✅ Tour completed")
    }
    
    /// Resets all tour progress and tips
    func resetTour() {
        isTourCompleted = false
        currentTourStep = 0
        hasSeenWelcome = false
        
        // Reset TipKit datastore (iOS 17+)
        if #available(iOS 17.0, *) {
            do {
                try Tips.resetDatastore()
                print("🔄 Tips datastore reset")
            } catch {
                print("❌ Failed to reset tips: \(error)")
            }
        }
        
        print("🔄 Tour reset complete")
    }
    
    /// Advances to the next tour step
    func nextStep() {
        currentTourStep += 1
        print("➡️ Tour step: \(currentTourStep)")
    }
    
    /// Skips to a specific step
    /// - Parameter step: The step number to skip to
    func skipToStep(_ step: Int) {
        currentTourStep = step
        print("⏭️ Skipped to step: \(step)")
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
        Current Step: \(currentTourStep)
        Has Seen Welcome: \(hasSeenWelcome)
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
        print("✅ Tour forced to show")
    }
    #endif
}
