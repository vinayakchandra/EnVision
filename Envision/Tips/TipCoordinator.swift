import UIKit

final class TipCoordinator {
    static let shared = TipCoordinator()

    private init() {}

    func showTip(
        id: String,
        configuration: TipBubbleView.Configuration,
        in viewController: UIViewController,
        containerView: UIView,
        onPrimaryAction: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil,
        onPresented: ((CGFloat) -> Void)? = nil
    ) {
        guard viewController.isViewLoaded else { return }
        guard !hasSeen(tipID: id), !TourManager.shared.tourSkipped else { return }
        guard containerView.subviews.first(where: { $0 is TipBubbleView }) == nil else { return }

        let tipView = TipBubbleView(configuration: configuration)
        tipView.alpha = 0

        tipView.onPrimaryAction = { [weak self] in
            self?.markAsSeen(tipID: id)
            self?.dismissTip(from: containerView) {
                onPrimaryAction()
                onDismiss?()
            }
        }

        tipView.onDismiss = { [weak self] in
            self?.markAsSeen(tipID: id)
            self?.dismissTip(from: containerView) {
                onDismiss?()
            }
        }

        containerView.addSubview(tipView)
        NSLayoutConstraint.activate([
            tipView.topAnchor.constraint(equalTo: containerView.topAnchor),
            tipView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tipView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            // Critical: without this the container stays zero-height and touches don't register
            tipView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        containerView.superview?.bringSubviewToFront(containerView)
        containerView.layoutIfNeeded()
        let measuredHeight = tipView.systemLayoutSizeFitting(
            CGSize(
                width: max(1, containerView.bounds.width),
                height: UIView.layoutFittingCompressedSize.height
            ),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        onPresented?(measuredHeight)

        UIView.animate(withDuration: 0.28, delay: 0.08, options: [.curveEaseOut]) {
            tipView.alpha = 1
        }
    }

    func dismissTip(from containerView: UIView, completion: (() -> Void)? = nil) {
        guard let tipView = containerView.subviews.first(where: { $0 is TipBubbleView }) else {
            completion?()
            return
        }
        UIView.animate(withDuration: 0.2, animations: {
            tipView.alpha = 0
        }) { _ in
            tipView.removeFromSuperview()
            completion?()
        }
    }

    private func hasSeen(tipID: String) -> Bool {
        TourManager.shared.hasSeen(tipID: tipID)
    }

    private func markAsSeen(tipID: String) {
        TourManager.shared.markTipAsSeen(tipID)
    }
}
