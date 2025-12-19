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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.titleView = segmentedControl
        showVisualize()
    }

    // MARK: - Actions
    @objc private func modeChanged() {
        segmentedControl.selectedSegmentIndex == 0
            ? showVisualize()
            : showEdit()
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

        // Add new child
        addChild(vc)
        view.addSubview(vc.view)
        vc.view.frame = view.bounds
        vc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.didMove(toParent: self)

        // Forward nav items
        navigationItem.rightBarButtonItem = vc.navigationItem.rightBarButtonItem
        navigationItem.leftBarButtonItem  = vc.navigationItem.leftBarButtonItem

        currentChild = vc
    }
}
