//
//  UserManager.swift
//  Envision
//
//  Singleton for managing user data persistence
//

import UIKit

final class UserManager {

    static let shared = UserManager()

    private let userDefaultsKey = "currentUser"
    private let profileImageFileName = "profile_image.jpg"

    private init() {}

    // MARK: - Current User

    var currentUser: UserModel? {
        get {
            guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
            return try? JSONDecoder().decode(UserModel.self, from: data)
        }
        set {
            if let user = newValue {
                if let data = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(data, forKey: userDefaultsKey)
                }
            } else {
                UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            }
        }
    }

    var isLoggedIn: Bool {
        return currentUser != nil
    }

    // MARK: - Authentication

    func login(email: String, password: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        // For local-only auth, we just check if a user exists with this email
        // In a real app, you'd validate against a backend

        if let existingUser = currentUser, existingUser.email.lowercased() == email.lowercased() {
            completion(.success(existingUser))
        } else {
            // Create a new user session (simulating login)
            let user = UserModel(
                name: email.components(separatedBy: "@").first?.capitalized ?? "User",
                email: email
            )
            currentUser = user
            completion(.success(user))
        }
    }

    func signup(name: String, email: String, password: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        // Create new user
        let user = UserModel(
            name: name,
            email: email
        )
        currentUser = user
        completion(.success(user))
    }

    func logout() {
        // Clear user data
        currentUser = nil
        // Optionally clear profile image
        deleteProfileImage()
    }

    // MARK: - Profile Updates

    func updateProfile(name: String? = nil, email: String? = nil, bio: String? = nil) {
        guard var user = currentUser else { return }

        if let name = name { user.name = name }
        if let email = email { user.email = email }
        if let bio = bio { user.bio = bio }

        currentUser = user
    }

    func updatePreferences(_ preferences: UserPreferences) {
        guard var user = currentUser else { return }
        user.preferences = preferences
        currentUser = user
    }

    // MARK: - Profile Image

    private var profileImageURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent(profileImageFileName)
    }

    func saveProfileImage(_ image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return false }

        do {
            try data.write(to: profileImageURL)

            // Update user model with image path
            if var user = currentUser {
                user.profileImagePath = profileImageURL.path
                currentUser = user
            }
            return true
        } catch {
            print("❌ Failed to save profile image: \(error)")
            return false
        }
    }

    func loadProfileImage() -> UIImage? {
        guard FileManager.default.fileExists(atPath: profileImageURL.path) else { return nil }
        return UIImage(contentsOfFile: profileImageURL.path)
    }

    func deleteProfileImage() {
        try? FileManager.default.removeItem(at: profileImageURL)

        if var user = currentUser {
            user.profileImagePath = nil
            currentUser = user
        }
    }

    // MARK: - Notification Preferences

    func setNotificationsEnabled(_ enabled: Bool) {
        guard var user = currentUser else { return }
        user.preferences.notificationsEnabled = enabled
        currentUser = user
    }

    func setScanReminders(_ enabled: Bool) {
        guard var user = currentUser else { return }
        user.preferences.scanReminders = enabled
        currentUser = user
    }

    func setNewFeatureAlerts(_ enabled: Bool) {
        guard var user = currentUser else { return }
        user.preferences.newFeatureAlerts = enabled
        currentUser = user
    }

    func setTheme(_ theme: Int) {
        guard var user = currentUser else { return }
        user.preferences.theme = theme
        currentUser = user
        UserDefaults.standard.set(theme, forKey: "selectedTheme")
    }
}
