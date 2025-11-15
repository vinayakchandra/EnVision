import UIKit

extension UIViewController {

    // MARK: - Slide Up Transition (used in Onboarding → Login)
    func presentSlideUp(_ viewController: UIViewController) {
        viewController.modalPresentationStyle = .pageSheet
        viewController.modalTransitionStyle = .coverVertical
        if let sheet = viewController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(viewController, animated: true, completion: nil)
    }

    // MARK: - Replace root view controller (used on logout)
    func setAsRoot(_ viewController: UIViewController) {
        guard let window = view.window ?? UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.windows.first }).first else {
            present(viewController, animated: true)
            return
        }
        window.rootViewController = UINavigationController(rootViewController: viewController)
        UIView.transition(with: window,
                          duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: nil)
    }
}
