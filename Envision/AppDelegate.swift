//
//  AppDelegate.swift
//  Envision
//
//  Created by user@78 on 10/11/25.
//

import UIKit


    import UIKit

    @main
    class AppDelegate: UIResponder, UIApplicationDelegate {

        func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        ) -> Bool {
            return true
        }

        // Required for SceneDelegate lifecycle
        func application(_ application: UIApplication,
                         configurationForConnecting connectingSceneSession: UISceneSession,
                         options: UIScene.ConnectionOptions) -> UISceneConfiguration {
            return UISceneConfiguration(name: "Default Configuration",
                                        sessionRole: connectingSceneSession.role)
        }
      


    // MARK: UISceneSession Lifecycle

  

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

