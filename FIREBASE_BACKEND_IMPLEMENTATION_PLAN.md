# EnVision - Firebase Backend Implementation Plan
*Comprehensive Guide for Backend Integration*

---

## Table of Contents
1. [Overview](#1-overview)
2. [Firebase Setup](#2-firebase-setup)
3. [Authentication System](#3-authentication-system)
4. [Firestore Database Design](#4-firestore-database-design)
5. [Firebase Storage Structure](#5-firebase-storage-structure)
6. [Code Implementation](#6-code-implementation)
7. [Security Rules](#7-security-rules)
8. [Migration Strategy](#8-migration-strategy)
9. [Testing Plan](#9-testing-plan)
10. [Deployment Checklist](#10-deployment-checklist)

---

## 1. Overview

### 1.1 Goals
- **User Authentication**: Email/password login with password reset
- **Cloud Sync**: Sync user data, rooms, and furniture across devices
- **Cloud Storage**: Store profile pictures and optionally USDZ files
- **Offline Support**: Cache data locally for offline access
- **Security**: User data isolated with Firestore security rules

### 1.2 Firebase Services to Use
- **Firebase Authentication**: Email/Password, (future: Apple Sign-In, Google Sign-In)
- **Cloud Firestore**: NoSQL database for user profiles, rooms, furniture metadata
- **Firebase Storage**: Blob storage for images and 3D models
- **Firebase Analytics** (optional): Track user engagement
- **Crashlytics** (optional): Monitor app stability

### 1.3 Architecture Overview
```
iOS App (UIKit)
    ↓
FirebaseManager (Singleton)
    ├── AuthManager (Firebase Auth)
    ├── FirestoreManager (Firestore CRUD)
    └── StorageManager (Firebase Storage)
    ↓
Local Cache (UserDefaults + FileManager)
    ↓
UI Updates (via completion handlers / delegates)
```

---

## 2. Firebase Setup

### 2.1 Create Firebase Project

**Steps**:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"**
3. Name: `EnVision-Production` (or your preferred name)
4. Enable Google Analytics (optional but recommended)
5. Create project (takes ~30 seconds)

### 2.2 Add iOS App to Firebase

**Steps**:
1. In Firebase Console, click **"Add app"** → iOS
2. **iOS bundle ID**: `com.yourcompany.EnVision` (must match Xcode project)
3. **App nickname**: `EnVision iOS`
4. **App Store ID**: (leave blank for now, add later)
5. Download `GoogleService-Info.plist`
6. **Important**: Add `GoogleService-Info.plist` to Xcode:
   - Drag into Xcode project navigator
   - **Ensure "Copy items if needed" is checked**
   - **Target membership**: Envision ✅

### 2.3 Add Firebase SDK via Swift Package Manager

**Steps**:
1. In Xcode: **File → Add Package Dependencies...**
2. URL: `https://github.com/firebase/firebase-ios-sdk`
3. Version: **10.20.0** or latest
4. Select packages to add:
   - ✅ `FirebaseAuth`
   - ✅ `FirebaseFirestore`
   - ✅ `FirebaseStorage`
   - ✅ `FirebaseAnalytics` (optional)
   - ✅ `FirebaseCrashlytics` (optional)
5. Click **"Add Package"**
6. Wait for SPM to resolve dependencies (~2-3 minutes)

### 2.4 Configure Firebase in AppDelegate

**File**: `Envision/AppDelegate.swift`

```swift
import UIKit
import FirebaseCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, 
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Configure Firebase FIRST (before any Firebase calls)
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
        
        // ... existing theme setup code ...
        
        return true
    }
}
```

### 2.5 Verify Installation

**Quick Test** (add to `SceneDelegate.willConnectTo` temporarily):
```swift
import FirebaseAuth

// In willConnectTo, after window setup
if let currentUser = Auth.auth().currentUser {
    print("✅ Firebase Auth works! User: \(currentUser.uid)")
} else {
    print("✅ Firebase Auth works! No user logged in")
}
```

---

## 3. Authentication System

### 3.1 Create AuthManager

**File**: `Envision/Managers/AuthManager.swift`

```swift
import Foundation
import FirebaseAuth

final class AuthManager {
    static let shared = AuthManager()
    
    private init() {}
    
    // MARK: - Current User
    
    var currentUser: User? {
        return Auth.auth().currentUser
    }
    
    var isLoggedIn: Bool {
        return currentUser != nil
    }
    
    var currentUserID: String? {
        return currentUser?.uid
    }
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, name: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User creation failed"])))
                return
            }
            
            // Update display name
            let changeRequest = user.createProfileChangeRequest()
            changeRequest.displayName = name
            changeRequest.commitChanges { error in
                if let error = error {
                    print("⚠️ Failed to set display name: \(error)")
                }
            }
            
            // Create user document in Firestore
            FirestoreManager.shared.createUserDocument(uid: user.uid, email: email, name: name) { result in
                switch result {
                case .success:
                    completion(.success(user))
                case .failure(let error):
                    print("⚠️ Failed to create user document: \(error)")
                    // Still return success (user created, just doc failed)
                    completion(.success(user))
                }
            }
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String, completion: @escaping (Result<User, Error>) -> Void) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let user = result?.user else {
                completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Sign in failed"])))
                return
            }
            
            completion(.success(user))
        }
    }
    
    // MARK: - Sign Out
    
    func signOut(completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            try Auth.auth().signOut()
            
            // Clear local user data
            UserManager.shared.logout()
            
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: - Password Reset
    
    func sendPasswordReset(email: String, completion: @escaping (Result<Void, Error>) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Delete Account
    
    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = currentUser else {
            completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        let uid = user.uid
        
        // Delete Firestore data first
        FirestoreManager.shared.deleteUserData(uid: uid) { result in
            switch result {
            case .success:
                // Then delete auth account
                user.delete { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        UserManager.shared.logout()
                        completion(.success(()))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Re-authentication (for sensitive operations)
    
    func reauthenticate(password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let user = currentUser, let email = user.email else {
            completion(.failure(NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user logged in"])))
            return
        }
        
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        
        user.reauthenticate(with: credential) { _, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
```

### 3.2 Update UserManager to Use Firebase

**File**: `Envision/Extensions/UserManager.swift`

```swift
import Foundation
import FirebaseAuth

final class UserManager {
    static let shared = UserManager()
    
    // MARK: - Local Cache (for offline access)
    
    var currentUser: UserModel? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "currentUser"),
                  let user = try? JSONDecoder().decode(UserModel.self, from: data) else {
                return nil
            }
            return user
        }
        set {
            if let user = newValue {
                let data = try? JSONEncoder().encode(user)
                UserDefaults.standard.set(data, forKey: "currentUser")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentUser")
            }
        }
    }
    
    var isLoggedIn: Bool {
        return AuthManager.shared.isLoggedIn && currentUser != nil
    }
    
    // MARK: - Login (Firebase)
    
    func login(email: String, password: String, completion: @escaping (Bool) -> Void) {
        AuthManager.shared.signIn(email: email, password: password) { [weak self] result in
            switch result {
            case .success(let user):
                // Fetch user profile from Firestore
                FirestoreManager.shared.fetchUserDocument(uid: user.uid) { fetchResult in
                    switch fetchResult {
                    case .success(let userModel):
                        self?.currentUser = userModel
                        completion(true)
                    case .failure(let error):
                        print("⚠️ Failed to fetch user profile: \(error)")
                        // Create minimal local user
                        let userModel = UserModel(
                            id: user.uid,
                            name: user.displayName ?? "User",
                            email: user.email ?? email,
                            createdAt: Date(),
                            preferences: UserPreferences()
                        )
                        self?.currentUser = userModel
                        completion(true)
                    }
                }
            case .failure(let error):
                print("❌ Login failed: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // MARK: - Signup (Firebase)
    
    func signup(name: String, email: String, password: String, completion: @escaping (Bool) -> Void) {
        AuthManager.shared.signUp(email: email, password: password, name: name) { [weak self] result in
            switch result {
            case .success(let user):
                // Create local user model
                let userModel = UserModel(
                    id: user.uid,
                    name: name,
                    email: email,
                    createdAt: Date(),
                    preferences: UserPreferences()
                )
                self?.currentUser = userModel
                completion(true)
            case .failure(let error):
                print("❌ Signup failed: \(error.localizedDescription)")
                completion(false)
            }
        }
    }
    
    // MARK: - Logout
    
    func logout() {
        AuthManager.shared.signOut { _ in }
        currentUser = nil
        
        // Clear other local data if needed
        TourManager.shared.resetTour()
    }
    
    // MARK: - Update Profile
    
    func updateProfile(name: String? = nil, bio: String? = nil, completion: @escaping (Bool) -> Void) {
        guard var user = currentUser else {
            completion(false)
            return
        }
        
        if let name = name {
            user.name = name
        }
        if let bio = bio {
            user.bio = bio
        }
        
        // Update Firestore
        FirestoreManager.shared.updateUserDocument(uid: user.id, data: [
            "name": user.name,
            "bio": user.bio ?? ""
        ]) { [weak self] result in
            switch result {
            case .success:
                self?.currentUser = user
                completion(true)
            case .failure(let error):
                print("❌ Failed to update profile: \(error)")
                completion(false)
            }
        }
    }
    
    // MARK: - Update Preferences
    
    func updatePreferences(_ preferences: UserPreferences, completion: @escaping (Bool) -> Void) {
        guard var user = currentUser else {
            completion(false)
            return
        }
        
        user.preferences = preferences
        
        // Update Firestore
        FirestoreManager.shared.updateUserDocument(uid: user.id, data: [
            "preferences": [
                "notificationsEnabled": preferences.notificationsEnabled,
                "scanReminders": preferences.scanReminders,
                "newFeatureAlerts": preferences.newFeatureAlerts,
                "theme": preferences.theme
            ]
        ]) { [weak self] result in
            switch result {
            case .success:
                self?.currentUser = user
                completion(true)
            case .failure(let error):
                print("❌ Failed to update preferences: \(error)")
                completion(false)
            }
        }
    }
}
```

### 3.3 Update LoginViewController

**File**: `Envision/Screens/Onboarding/LoginViewController.swift`

```swift
// Update handleLogin method

@objc private func handleLogin() {
    guard let email = emailField.text, !email.isEmpty,
          let password = passwordField.text, !password.isEmpty else {
        showError("Please fill in all fields")
        return
    }
    
    guard email.isValidEmail else {
        showError("Please enter a valid email address")
        return
    }
    
    // Show loading
    continueButton.isEnabled = false
    continueButton.setTitle("Signing In...", for: .normal)
    
    // Firebase login
    UserManager.shared.login(email: email, password: password) { [weak self] success in
        DispatchQueue.main.async {
            self?.continueButton.isEnabled = true
            self?.continueButton.setTitle("Continue", for: .normal)
            
            if success {
                // Navigate to main app
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.switchToMainApp()
                } else {
                    // Fallback
                    let mainVC = MainTabBarController()
                    mainVC.modalPresentationStyle = .fullScreen
                    self?.present(mainVC, animated: true)
                }
            } else {
                self?.showError("Invalid email or password")
            }
        }
    }
}

private func showError(_ message: String) {
    let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
}
```

### 3.4 Update SignupViewController

**File**: `Envision/Screens/Onboarding/SignupViewController.swift`

```swift
// Update handleSignup method

@objc private func handleSignup() {
    guard let name = nameField.text, !name.isEmpty,
          let email = emailField.text, !email.isEmpty,
          let password = passwordField.text, !password.isEmpty,
          let confirmPassword = confirmPasswordField.text, !confirmPassword.isEmpty else {
        showError("Please fill in all fields")
        return
    }
    
    guard email.isValidEmail else {
        showError("Please enter a valid email address")
        return
    }
    
    guard password.isStrongPassword else {
        showError("Password must be at least 8 characters with uppercase, lowercase, and numbers")
        return
    }
    
    guard password == confirmPassword else {
        showError("Passwords do not match")
        return
    }
    
    // Show loading
    signupButton.isEnabled = false
    signupButton.setTitle("Creating Account...", for: .normal)
    
    // Firebase signup
    UserManager.shared.signup(name: name, email: email, password: password) { [weak self] success in
        DispatchQueue.main.async {
            self?.signupButton.isEnabled = true
            self?.signupButton.setTitle("Create Account", for: .normal)
            
            if success {
                // Navigate to main app
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.switchToMainApp()
                } else {
                    // Fallback
                    let mainVC = MainTabBarController()
                    mainVC.modalPresentationStyle = .fullScreen
                    self?.present(mainVC, animated: true)
                }
            } else {
                self?.showError("Failed to create account. Email may already be in use.")
            }
        }
    }
}
```

### 3.5 Update ForgotPasswordViewController

**File**: `Envision/Screens/Onboarding/ForgotPasswordViewController.swift`

```swift
// Update handleReset method

@objc private func handleReset() {
    guard let email = emailField.text, !email.isEmpty else {
        showError("Please enter your email address")
        return
    }
    
    guard email.isValidEmail else {
        showError("Please enter a valid email address")
        return
    }
    
    // Show loading
    resetButton.isEnabled = false
    resetButton.setTitle("Sending...", for: .normal)
    
    // Send password reset email
    AuthManager.shared.sendPasswordReset(email: email) { [weak self] result in
        DispatchQueue.main.async {
            self?.resetButton.isEnabled = true
            self?.resetButton.setTitle("Send Reset Link", for: .normal)
            
            switch result {
            case .success:
                self?.showSuccess("Password reset email sent! Check your inbox.")
            case .failure(let error):
                self?.showError("Failed to send reset email: \(error.localizedDescription)")
            }
        }
    }
}

private func showSuccess(_ message: String) {
    let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
        self?.navigationController?.popViewController(animated: true)
    })
    present(alert, animated: true)
}
```

### 3.6 Add Auto-Login in SplashViewController

**File**: `Envision/Screens/Onboarding/SplashViewController.swift`

```swift
import UIKit
import FirebaseAuth

// Update goNext method

private func goNext() {
    // Check if user is already logged in
    if let firebaseUser = Auth.auth().currentUser {
        print("✅ User already logged in: \(firebaseUser.uid)")
        
        // Fetch user profile from Firestore
        FirestoreManager.shared.fetchUserDocument(uid: firebaseUser.uid) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let userModel):
                    UserManager.shared.currentUser = userModel
                    self?.goToMainApp()
                case .failure(let error):
                    print("⚠️ Failed to fetch user profile: \(error)")
                    // Still go to main app with minimal user data
                    let userModel = UserModel(
                        id: firebaseUser.uid,
                        name: firebaseUser.displayName ?? "User",
                        email: firebaseUser.email ?? "",
                        createdAt: Date(),
                        preferences: UserPreferences()
                    )
                    UserManager.shared.currentUser = userModel
                    self?.goToMainApp()
                }
            }
        }
    } else {
        // No user logged in, show onboarding
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.goToOnboarding()
        }
    }
}

private func goToMainApp() {
    if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
        sceneDelegate.switchToMainApp()
    } else {
        let mainVC = MainTabBarController()
        mainVC.modalPresentationStyle = .fullScreen
        present(mainVC, animated: true)
    }
}

private func goToOnboarding() {
    let onboarding = OnboardingController()
    onboarding.modalPresentationStyle = .fullScreen
    present(onboarding, animated: true)
}
```

---

## 4. Firestore Database Design

### 4.1 Data Model Structure

```
firestore/
├── users/{uid}
│   ├── id: string
│   ├── name: string
│   ├── email: string
│   ├── bio: string
│   ├── profileImageURL: string
│   ├── createdAt: timestamp
│   └── preferences: map
│       ├── notificationsEnabled: boolean
│       ├── scanReminders: boolean
│       ├── newFeatureAlerts: boolean
│       └── theme: number
│
├── users/{uid}/rooms/{roomId}
│   ├── id: string
│   ├── name: string
│   ├── category: string
│   ├── createdAt: timestamp
│   ├── updatedAt: timestamp
│   ├── usdzURL: string (optional, Firebase Storage path)
│   ├── thumbnailURL: string
│   ├── dimensions: map
│   │   ├── width: number
│   │   ├── length: number
│   │   └── height: number
│   └── notes: string
│
└── users/{uid}/furniture/{furnitureId}
    ├── id: string
    ├── name: string
    ├── category: string
    ├── createdAt: timestamp
    ├── updatedAt: timestamp
    ├── usdzURL: string (optional)
    └── thumbnailURL: string
```

### 4.2 Create FirestoreManager

**File**: `Envision/Managers/FirestoreManager.swift`

```swift
import Foundation
import FirebaseFirestore

final class FirestoreManager {
    static let shared = FirestoreManager()
    
    private let db = Firestore.firestore()
    
    private init() {
        // Enable offline persistence
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
    }
    
    // MARK: - User Document
    
    func createUserDocument(uid: String, email: String, name: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection("users").document(uid)
        
        let data: [String: Any] = [
            "id": uid,
            "name": name,
            "email": email,
            "bio": "",
            "profileImageURL": "",
            "createdAt": FieldValue.serverTimestamp(),
            "preferences": [
                "notificationsEnabled": true,
                "scanReminders": true,
                "newFeatureAlerts": true,
                "theme": 0
            ]
        ]
        
        userRef.setData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ User document created: \(uid)")
                completion(.success(()))
            }
        }
    }
    
    func fetchUserDocument(uid: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        let userRef = db.collection("users").document(uid)
        
        userRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = snapshot?.data() else {
                completion(.failure(NSError(domain: "FirestoreManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "User document not found"])))
                return
            }
            
            // Parse user model
            let id = data["id"] as? String ?? uid
            let name = data["name"] as? String ?? "User"
            let email = data["email"] as? String ?? ""
            let bio = data["bio"] as? String
            let profileImagePath = data["profileImageURL"] as? String
            
            let createdAt: Date
            if let timestamp = data["createdAt"] as? Timestamp {
                createdAt = timestamp.dateValue()
            } else {
                createdAt = Date()
            }
            
            let prefsData = data["preferences"] as? [String: Any] ?? [:]
            let preferences = UserPreferences(
                notificationsEnabled: prefsData["notificationsEnabled"] as? Bool ?? true,
                scanReminders: prefsData["scanReminders"] as? Bool ?? true,
                newFeatureAlerts: prefsData["newFeatureAlerts"] as? Bool ?? true,
                theme: prefsData["theme"] as? Int ?? 0
            )
            
            let userModel = UserModel(
                id: id,
                name: name,
                email: email,
                bio: bio,
                profileImagePath: profileImagePath,
                createdAt: createdAt,
                preferences: preferences
            )
            
            completion(.success(userModel))
        }
    }
    
    func updateUserDocument(uid: String, data: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection("users").document(uid)
        
        userRef.updateData(data) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ User document updated: \(uid)")
                completion(.success(()))
            }
        }
    }
    
    func deleteUserData(uid: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection("users").document(uid)
        
        // Delete user document
        userRef.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ User data deleted: \(uid)")
                completion(.success(()))
            }
        }
        
        // Note: Subcollections (rooms, furniture) must be deleted separately
        // For production, use Cloud Functions for recursive delete
    }
    
    // MARK: - Rooms Subcollection
    
    func saveRoom(uid: String, room: RoomModel, metadata: RoomMetadata, completion: @escaping (Result<Void, Error>) -> Void) {
        let roomRef = db.collection("users").document(uid).collection("rooms").document(room.id.uuidString)
        
        let data: [String: Any] = [
            "id": room.id.uuidString,
            "name": room.name,
            "category": room.category.rawValue,
            "createdAt": Timestamp(date: room.createdAt),
            "updatedAt": FieldValue.serverTimestamp(),
            "usdzFilename": room.usdzFilename,
            "thumbnailPath": room.thumbnailPath ?? "",
            "dimensions": metadata.dimensions ?? [:],
            "notes": metadata.notes ?? ""
        ]
        
        roomRef.setData(data, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ Room saved to Firestore: \(room.name)")
                completion(.success(()))
            }
        }
    }
    
    func fetchRooms(uid: String, completion: @escaping (Result<[RoomModel], Error>) -> Void) {
        let roomsRef = db.collection("users").document(uid).collection("rooms")
        
        roomsRef.order(by: "createdAt", descending: true).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            let rooms: [RoomModel] = documents.compactMap { doc in
                let data = doc.data()
                guard let idString = data["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let name = data["name"] as? String,
                      let categoryString = data["category"] as? String,
                      let category = RoomCategory(rawValue: categoryString),
                      let usdzFilename = data["usdzFilename"] as? String else {
                    return nil
                }
                
                let createdAt: Date
                if let timestamp = data["createdAt"] as? Timestamp {
                    createdAt = timestamp.dateValue()
                } else {
                    createdAt = Date()
                }
                
                let thumbnailPath = data["thumbnailPath"] as? String
                
                return RoomModel(
                    id: id,
                    name: name,
                    category: category,
                    createdAt: createdAt,
                    usdzFilename: usdzFilename,
                    thumbnailPath: thumbnailPath
                )
            }
            
            completion(.success(rooms))
        }
    }
    
    func deleteRoom(uid: String, roomID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let roomRef = db.collection("users").document(uid).collection("rooms").document(roomID)
        
        roomRef.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ Room deleted from Firestore: \(roomID)")
                completion(.success(()))
            }
        }
    }
    
    // MARK: - Furniture Subcollection
    
    func saveFurniture(uid: String, furnitureID: String, name: String, category: String, usdzFilename: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let furnitureRef = db.collection("users").document(uid).collection("furniture").document(furnitureID)
        
        let data: [String: Any] = [
            "id": furnitureID,
            "name": name,
            "category": category,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
            "usdzFilename": usdzFilename,
            "thumbnailURL": ""
        ]
        
        furnitureRef.setData(data, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ Furniture saved to Firestore: \(name)")
                completion(.success(()))
            }
        }
    }
    
    func fetchFurniture(uid: String, completion: @escaping (Result<[URL], Error>) -> Void) {
        let furnitureRef = db.collection("users").document(uid).collection("furniture")
        
        furnitureRef.order(by: "createdAt", descending: true).getDocuments { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }
            
            // Convert to file URLs (assuming local storage for now)
            let fileManager = FileManager.default
            let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let furnitureFolder = docsURL.appendingPathComponent("furniture", isDirectory: true)
            
            let urls: [URL] = documents.compactMap { doc in
                let data = doc.data()
                guard let filename = data["usdzFilename"] as? String else { return nil }
                return furnitureFolder.appendingPathComponent(filename)
            }
            
            completion(.success(urls))
        }
    }
    
    func deleteFurniture(uid: String, furnitureID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let furnitureRef = db.collection("users").document(uid).collection("furniture").document(furnitureID)
        
        furnitureRef.delete { error in
            if let error = error {
                completion(.failure(error))
            } else {
                print("✅ Furniture deleted from Firestore: \(furnitureID)")
                completion(.success(()))
            }
        }
    }
}
```

---

## 5. Firebase Storage Structure

### 5.1 Storage Bucket Organization

```
gs://envision-production.appspot.com/
├── users/{uid}/
│   ├── profile/
│   │   └── profile.jpg
│   ├── rooms/
│   │   ├── {roomId}.usdz
│   │   └── {roomId}_thumbnail.jpg
│   └── furniture/
│       ├── {furnitureId}.usdz
│       └── {furnitureId}_thumbnail.jpg
```

### 5.2 Create StorageManager

**File**: `Envision/Managers/StorageManager.swift`

```swift
import Foundation
import FirebaseStorage

final class StorageManager {
    static let shared = StorageManager()
    
    private let storage = Storage.storage()
    
    private init() {}
    
    // MARK: - Profile Picture
    
    func uploadProfilePicture(uid: String, image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])))
            return
        }
        
        let ref = storage.reference().child("users/\(uid)/profile/profile.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        ref.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let urlString = url?.absoluteString {
                    print("✅ Profile picture uploaded: \(urlString)")
                    completion(.success(urlString))
                } else {
                    completion(.failure(NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                }
            }
        }
    }
    
    func downloadProfilePicture(url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let ref = storage.reference(forURL: url)
        
        ref.getData(maxSize: 5 * 1024 * 1024) { data, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"])))
                return
            }
            
            completion(.success(image))
        }
    }
    
    // MARK: - Room USDZ (optional - can stay local)
    
    func uploadRoomUSDZ(uid: String, roomID: String, localURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let ref = storage.reference().child("users/\(uid)/rooms/\(roomID).usdz")
        
        ref.putFile(from: localURL, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let urlString = url?.absoluteString {
                    print("✅ Room USDZ uploaded: \(urlString)")
                    completion(.success(urlString))
                } else {
                    completion(.failure(NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                }
            }
        }
    }
    
    // MARK: - Thumbnail Upload
    
    func uploadThumbnail(uid: String, type: String, itemID: String, image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])))
            return
        }
        
        let ref = storage.reference().child("users/\(uid)/\(type)/\(itemID)_thumbnail.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        ref.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            ref.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                } else if let urlString = url?.absoluteString {
                    print("✅ Thumbnail uploaded: \(urlString)")
                    completion(.success(urlString))
                } else {
                    completion(.failure(NSError(domain: "StorageManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                }
            }
        }
    }
}
```

---

## 6. Code Implementation

### 6.1 Integration Points

**When to sync with Firebase:**

1. **Room saved** (in `RoomPreviewViewController`):
```swift
// After saving locally
if let uid = AuthManager.shared.currentUserID {
    FirestoreManager.shared.saveRoom(uid: uid, room: room, metadata: metadata) { result in
        switch result {
        case .success:
            print("✅ Room synced to cloud")
        case .failure(let error):
            print("⚠️ Cloud sync failed (offline?): \(error)")
            // Still works offline, will sync later
        }
    }
}
```

2. **Furniture saved** (in `ObjectCapturePreviewController`):
```swift
// After saving USDZ locally
if let uid = AuthManager.shared.currentUserID {
    FirestoreManager.shared.saveFurniture(
        uid: uid,
        furnitureID: furnitureID,
        name: filename,
        category: category.rawValue,
        usdzFilename: "\(furnitureID).usdz"
    ) { result in
        // Handle result
    }
}
```

3. **Profile updated** (in `EditProfileViewController`):
```swift
// After user edits profile
UserManager.shared.updateProfile(name: newName, bio: newBio) { success in
    if success {
        print("✅ Profile synced")
    }
}
```

### 6.2 Offline Support

Firestore automatically caches data. To handle offline scenarios:

```swift
// Check if online before showing sync indicator
func isOnline() -> Bool {
    // Simple check (can be improved with Reachability)
    return true // Firestore handles offline automatically
}

// Show sync status in UI
func showSyncStatus(synced: Bool) {
    // Add cloud icon to nav bar
    let icon = synced ? "checkmark.icloud.fill" : "icloud.slash.fill"
    let color = synced ? UIColor.systemGreen : UIColor.systemGray
    // Update UI
}
```

---

## 7. Security Rules

### 7.1 Firestore Security Rules

**In Firebase Console → Firestore → Rules**:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection
    match /users/{userId} {
      // User can read/write their own document
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Rooms subcollection
      match /rooms/{roomId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Furniture subcollection
      match /furniture/{furnitureId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    // Deny all other access
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### 7.2 Storage Security Rules

**In Firebase Console → Storage → Rules**:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    
    // Users folder
    match /users/{userId}/{allPaths=**} {
      // User can read/write their own files
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Deny all other access
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

### 7.3 Test Security Rules

```swift
// Try to access another user's data (should fail)
func testSecurityRules() {
    let otherUID = "some_other_user_id"
    
    FirestoreManager.shared.fetchUserDocument(uid: otherUID) { result in
        switch result {
        case .success:
            print("❌ Security rules are broken!")
        case .failure:
            print("✅ Security rules working correctly")
        }
    }
}
```

---

## 8. Migration Strategy

### 8.1 Phase 1: Add Firebase (No Breaking Changes)

**Week 1**:
- Add Firebase SDK
- Create manager classes
- Keep local storage as primary
- Firebase as "backup sync" only

### 8.2 Phase 2: Dual Sync (Local + Cloud)

**Week 2**:
- Every save operation writes to both local + Firestore
- On app launch, compare timestamps and merge
- Show "Syncing..." indicator

### 8.3 Phase 3: Cloud-First (Optional)

**Week 3+**:
- Firestore becomes source of truth
- Local storage as cache only
- Implement "Export to Files" for backup

### 8.4 Data Migration Script

```swift
func migrateLocalDataToFirebase(completion: @escaping () -> Void) {
    guard let uid = AuthManager.shared.currentUserID else {
        completion()
        return
    }
    
    print("🔄 Starting data migration...")
    
    let group = DispatchGroup()
    
    // Migrate rooms
    let roomsMetadata = MetadataManager.shared.loadMetadata()
    for (filename, metadata) in roomsMetadata.rooms {
        group.enter()
        
        // Create RoomModel from metadata
        let room = RoomModel(
            id: UUID(),
            name: metadata.name,
            category: RoomCategory(rawValue: metadata.category) ?? .other,
            createdAt: ISO8601DateFormatter().date(from: metadata.createdAt) ?? Date(),
            usdzFilename: filename,
            thumbnailPath: nil
        )
        
        FirestoreManager.shared.saveRoom(uid: uid, room: room, metadata: metadata) { _ in
            group.leave()
        }
    }
    
    // Wait for all migrations to complete
    group.notify(queue: .main) {
        print("✅ Data migration complete!")
        completion()
    }
}
```

---

## 9. Testing Plan

### 9.1 Unit Tests

```swift
import XCTest
@testable import Envision

class FirebaseTests: XCTestCase {
    
    func testAuthSignup() {
        let expectation = XCTestExpectation(description: "Signup completes")
        
        AuthManager.shared.signUp(email: "test@example.com", password: "Test1234", name: "Test User") { result in
            switch result {
            case .success(let user):
                XCTAssertNotNil(user)
                expectation.fulfill()
            case .failure(let error):
                XCTFail("Signup failed: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFirestoreSaveRoom() {
        // Test saving a room
    }
    
    func testStorageUpload() {
        // Test uploading an image
    }
}
```

### 9.2 Integration Tests

**Test Scenarios**:
1. Sign up → Create room → Logout → Login → Verify room exists
2. Offline mode → Create room → Go online → Verify sync
3. Profile picture upload → Verify URL in Firestore
4. Password reset → Verify email sent

### 9.3 Manual Testing Checklist

- [ ] Fresh install → Signup → Create room → Logout → Login → Room still there
- [ ] Airplane mode → Create room → Toggle off → Room syncs
- [ ] Delete account → Verify Firestore data deleted
- [ ] Password reset → Receive email → Reset works
- [ ] Profile picture upload → Shows in app
- [ ] Multiple devices → Changes sync

---

## 10. Deployment Checklist

### 10.1 Pre-Launch

- [ ] Firebase project created (production)
- [ ] `GoogleService-Info.plist` added to Xcode
- [ ] Security rules deployed and tested
- [ ] Error handling added to all Firebase calls
- [ ] Loading indicators for async operations
- [ ] Offline caching enabled
- [ ] Analytics events configured (optional)
- [ ] Crashlytics configured (optional)

### 10.2 App Store Submission

- [ ] Update privacy policy (mention cloud storage)
- [ ] Add "Sign in with Apple" (if using social auth)
- [ ] Test on multiple iOS versions (17.0+)
- [ ] Test on different devices (iPhone SE, Pro Max, iPad)
- [ ] Beta test via TestFlight (50+ users)

### 10.3 Post-Launch Monitoring

- [ ] Monitor Firebase Console → Usage
- [ ] Check Firestore read/write counts (cost optimization)
- [ ] Monitor Storage usage (cost optimization)
- [ ] Set up billing alerts
- [ ] Review Crashlytics reports weekly

---

## Appendix: Cost Estimation

### Firebase Free Tier (Spark Plan)

**Firestore**:
- 50k reads/day
- 20k writes/day
- 20k deletes/day
- 1 GB storage

**Storage**:
- 5 GB storage
- 1 GB/day downloads

**Authentication**:
- Unlimited (free)

### When to Upgrade (Blaze Plan)

- 1000+ daily active users
- Heavy USDZ file uploads (>5 GB/month)
- Need phone authentication

**Estimated Cost** (10k users, moderate usage):
- $25-50/month

---

**Document Version**: 1.0  
**Last Updated**: January 21, 2026  
**Estimated Implementation Time**: 10-14 days  
**Priority**: High  

---

*End of Firebase Backend Implementation Plan*
