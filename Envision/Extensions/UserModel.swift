//
//  UserModel.swift
//  Envision
//
//  Created on 10/12/25.
//

import Foundation

struct UserModel: Codable {
    var id: String
    var name: String
    var email: String
    var bio: String?
    var profileImagePath: String?
    var createdAt: Date
    var preferences: UserPreferences
    
    init(id: String = UUID().uuidString,
         name: String,
         email: String,
         bio: String? = nil,
         profileImagePath: String? = nil,
         createdAt: Date = Date(),
         preferences: UserPreferences = UserPreferences()) {
        self.id = id
        self.name = name
        self.email = email
        self.bio = bio
        self.profileImagePath = profileImagePath
        self.createdAt = createdAt
        self.preferences = preferences
    }
}

struct UserPreferences: Codable {
    var notificationsEnabled: Bool
    var scanReminders: Bool
    var newFeatureAlerts: Bool
    var theme: Int // 0 = light, 1 = dark, 2 = system
    
    init(notificationsEnabled: Bool = true,
         scanReminders: Bool = true,
         newFeatureAlerts: Bool = true,
         theme: Int = 2) {
        self.notificationsEnabled = notificationsEnabled
        self.scanReminders = scanReminders
        self.newFeatureAlerts = newFeatureAlerts
        self.theme = theme
    }
}
