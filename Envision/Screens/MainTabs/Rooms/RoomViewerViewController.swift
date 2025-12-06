import UIKit
import RealityKit

enum ViewerMode {
    case object
    case ar
}

// object view working
final class RoomViewerViewController: UIViewController {

    // MARK: - Inputs
    private let roomURL: URL
    private var viewerMode: ViewerMode
    private var placedFurniture: [ModelEntity] = []

    // MARK: - Views
    private let objectView = ARView(frame: .zero)   // Only used as a 3D renderer
    private let arScreen = UILabel()

    // MARK: - State
    private var roomModel: ModelEntity?

    // Orbit Camera
    private var orbitCamera: PerspectiveCamera?
    private var cameraAnchor = AnchorEntity()
    private var cameraPitch: Float = .pi / 6
    private var cameraYaw: Float = .pi / 4
    private var cameraDistance: Float = 1.5
    private var controlPanel: FurnitureControlPanel?

    // UI
    private let modeToggle = UISegmentedControl(items: ["AR", "Object"])
    private let addFurnitureButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Init
    init(roomURL: URL, mode: ViewerMode = .object) {
        self.roomURL = roomURL
        self.viewerMode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init coder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Room Viewer"
        setupLayout()
        setupUI()
        loadRoom()
    }

    // MARK: - Layout
    private func setupLayout() {
        objectView.translatesAutoresizingMaskIntoConstraints = false
        objectView.cameraMode = .nonAR  // ❗ No AR mode, no camera

        arScreen.text = "AR SCREEN"
        arScreen.textAlignment = .center
        arScreen.backgroundColor = .gray
        arScreen.textColor = .white
        objectView.environment.background = .color(.systemGray6)

        arScreen.font = .boldSystemFont(ofSize: 30)
        arScreen.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(objectView)
        view.addSubview(arScreen)

        NSLayoutConstraint.activate([
                                        objectView.topAnchor.constraint(equalTo: view.topAnchor),
                                        objectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        objectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        objectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                                        arScreen.topAnchor.constraint(equalTo: view.topAnchor),
                                        arScreen.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        arScreen.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        arScreen.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                                    ])
    }

    // MARK: - UI
    private func setupUI() {
        modeToggle.selectedSegmentIndex = viewerMode == .ar ? 1 : 0
        modeToggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        navigationItem.titleView = modeToggle

        // 🟦 Add the button to the view
        view.addSubview(addFurnitureButton)
        addFurnitureButton.addTarget(self, action: #selector(addFurnitureTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
                                        addFurnitureButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
                                        addFurnitureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
                                        addFurnitureButton.widthAnchor.constraint(equalToConstant: 54),
                                        addFurnitureButton.heightAnchor.constraint(equalToConstant: 54)
                                    ])
    }


    // MARK: - Load Model
    private func loadRoom() {
        Task {
            guard let model = try? await ModelEntity(contentsOf: roomURL) else {
                return
            }
            model.generateCollisionShapes(recursive: true)
            roomModel = model

            if viewerMode == .object {
                setupObjectScene()
            }
        }
    }

    // MARK: - Object Viewer Mode
    private func setupObjectScene() {
        guard let roomModel else {
            return
        }

        objectView.scene.anchors.removeAll()

        let anchor = AnchorEntity(world: .zero)
        let model = roomModel.clone(recursive: true)

        fitToScreen(model)
        anchor.addChild(model)
        objectView.scene.addAnchor(anchor)

        setupOrbitCamera(target: model)
        enableOrbitGestures()
    }

    private func fitToScreen(_ model: ModelEntity) {
        let bounds = model.visualBounds(relativeTo: nil)
        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        guard maxDim > 0 else {
            return
        }
        model.scale = SIMD3(repeating: 0.6 / maxDim)
    }

    // MARK: - Orbit Camera
    private func setupOrbitCamera(target: ModelEntity) {
        orbitCamera?.removeFromParent()
        orbitCamera = PerspectiveCamera()

        cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(orbitCamera!)
        objectView.scene.addAnchor(cameraAnchor)

        updateCamera()
    }

    private func enableOrbitGestures() {
        objectView.gestureRecognizers?.forEach {
            objectView.removeGestureRecognizer($0)
        }
        objectView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan)))
        objectView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch)))
    }

    @objc private func pan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: objectView)
        cameraYaw += Float(t.x) * 0.005
        cameraPitch = max(-1.4, min(1.4, cameraPitch + Float(t.y) * 0.005))
        g.setTranslation(.zero, in: objectView)
        updateCamera()
    }

    @objc private func pinch(_ g: UIPinchGestureRecognizer) {
        cameraDistance = max(0.3, min(8, cameraDistance * Float(1 / g.scale)))
        g.scale = 1
        updateCamera()
    }

    private func updateCamera() {
        let x = cameraDistance * cos(cameraPitch) * cos(cameraYaw)
        let y = cameraDistance * sin(cameraPitch)
        let z = cameraDistance * cos(cameraPitch) * sin(cameraYaw)
        orbitCamera?.position = [x, y, z]
        orbitCamera?.look(at: .zero, from: orbitCamera!.position, relativeTo: nil)
    }

    // MARK: - Mode Change
    @objc private func toggleChanged() {
        viewerMode = modeToggle.selectedSegmentIndex == 0 ? .ar : .object
        applyMode()
    }

    private func applyMode() {
        objectView.isHidden = viewerMode == .ar
        arScreen.isHidden = viewerMode == .object

        if viewerMode == .object {
            setupObjectScene()
        }
    }

    // MARK: - Furniture
    @objc private func addFurnitureTapped() {
        let picker = FurniturePickerViewController()
        picker.onModelSelected = { [weak self] url in
            self?.insertFurniture(url: url)
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    // MARK: - Gestures
    private func addGestures(to entity: ModelEntity, in view: ARView) {
        entity.generateCollisionShapes(recursive: true)
        // view.installGestures([.translation, .rotation, .scale], for: entity)
        view.installGestures([.rotation, .scale], for: entity)
    }

    private func insertFurniture(url: URL) {
        Task {
            guard let model = try? await ModelEntity(contentsOf: url) else {
                return
            }

            model.scale = [0.5, 0.5, 0.5]
            model.position = [0, 0, 0]
            model.generateCollisionShapes(recursive: true)

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(model)
            objectView.scene.addAnchor(anchor)

            placedFurniture.append(model)

            DispatchQueue.main.async {
                self.showControls(for: model)
            }
        }
    }

    private func showControls(for model: ModelEntity) {
        controlPanel?.removeFromSuperview()

        let panel = FurnitureControlPanel()
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        panel.attach(to: model)

        view.addSubview(panel)
        controlPanel = panel

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            panel.heightAnchor.constraint(equalToConstant: 330)
        ])
    }


}
