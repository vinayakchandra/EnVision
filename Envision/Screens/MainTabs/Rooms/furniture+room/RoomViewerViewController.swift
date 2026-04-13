import UIKit

final class RoomViewerViewController: UIViewController {

    // MARK: - Inputs
    private let roomURL: URL

    // MARK: - State
    private var currentChild: UIViewController?

    // MARK: - UI
    private lazy var segmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Visualize", "Edit"])
        control.selectedSegmentIndex = 0
        control.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        return control
    }()

    // MARK: - Init
    init(roomURL: URL) {
        self.roomURL = roomURL
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.titleView = segmentedControl
        // On iPad we are presented as a full-screen modal (no tab bar) so we
        // need a close button instead of the navigation-stack back button.
        if UIDevice.current.userInterfaceIdiom == .pad {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeTapped)
            )
        }
        showVisualize()
    }

    // MARK: - Actions
    @objc private func modeChanged() {
        segmentedControl.selectedSegmentIndex == 0
            ? showVisualize()
            : showEdit()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Child Management
    private func showVisualize() {
        switchTo(RoomVisualizeVC(roomURL: roomURL))
    }

    private func showEdit() {
        switchTo(RoomEditVC(roomURL: roomURL))
    }

    private func switchTo(_ vc: UIViewController) {
        // Remove old child
        if let current = currentChild {
            current.willMove(toParent: nil)
            current.view.removeFromSuperview()
            current.removeFromParent()
        }

        // Add new child — use Auto Layout so the frame is always correct,
        // even on iPad where view.bounds at viewDidLoad time may not be final.
        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: view.topAnchor),
            vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        vc.didMove(toParent: self)

        // Forward right nav items from the child (share, add, etc.)
        navigationItem.rightBarButtonItems = vc.navigationItem.rightBarButtonItems
        // Only forward left items on iPhone (on iPad the close button owns the left side)
        if UIDevice.current.userInterfaceIdiom != .pad {
            navigationItem.leftBarButtonItems = vc.navigationItem.leftBarButtonItems
        }

        currentChild = vc
    }
}
