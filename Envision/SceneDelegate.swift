//
//  SceneDelegate.swift
//  Envision
//
//  Created by user@78 on 10/11/25.
//

import UIKit


class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
       window.rootViewController = SplashViewController()
        // window.rootViewController = MainTabBarController()
//        window.rootViewController = RoomFurniture()
        self.window = window
        window.makeKeyAndVisible()
        
        let saved = UserDefaults.standard.integer(forKey: "selectedTheme")
        let style: UIUserInterfaceStyle

        switch saved {
        case 0: style = .light
        case 1: style = .dark
        default: style = .unspecified
        }
//        saveTestFile()
        
        if let windowScene = scene as? UIWindowScene,
           let window = windowScene.windows.first {
            window.overrideUserInterfaceStyle = style
        }
    }
    
    // Optional if you later handle login persistence
    func switchToMainApp() {
        let tabBar = MainTabBarController()
        window?.rootViewController = tabBar
    }

    func switchToLogin() {
        let loginVC = LoginViewController()
        let nav = UINavigationController(rootViewController: loginVC)
        nav.setNavigationBarHidden(true, animated: false)
        window?.rootViewController = nav
    }
    
//    func saveTestFile() {
//        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let fileURL = docs.appendingPathComponent("example.txt")
//
//        do {
//            try "Hello from SceneDelegate!".write(to: fileURL,
//                                                  atomically: true,
//                                                  encoding: .utf8)
//            print("Saved file to: \(fileURL)")
//        } catch {
//            print("Failed to write file: \(error)")
//        }
//    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
    
    
    
    
    
}
