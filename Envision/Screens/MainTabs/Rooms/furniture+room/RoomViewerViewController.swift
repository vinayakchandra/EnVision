import UIKit
import RealityKit

final class RoomViewerViewController: UIViewController {

    // MARK: - Inputs
    private let roomURL: URL
    private var placedFurniture: [ModelEntity] = []

    // MARK: - Views
    private let objectView = ARView(frame: .zero)   // 3D renderer only

    // MARK: - State
    private var roomModel: ModelEntity?

    // Orbit Camera
    private var orbitCamera: PerspectiveCamera?
    private var cameraAnchor = AnchorEntity()
    private var cameraPitch: Float = .pi / 6
    private var cameraYaw: Float = .pi / 4
    private var cameraDistance: Float = 1.5
    private var controlPanel: FurnitureControlPanel?


    // MARK: - Init
    init(roomURL: URL) {
        self.roomURL = roomURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init coder")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Room Viewer"
        navigationController?.navigationBar.prefersLargeTitles = false
        setupLayout()
        setupUI()
        loadRoom()
    }

    // MARK: - Layout
    private func setupLayout() {
        objectView.translatesAutoresizingMaskIntoConstraints = false
        objectView.cameraMode = .nonAR    // No AR

        objectView.environment.background = .color(.systemGray6)
        view.addSubview(objectView)

        NSLayoutConstraint.activate([
                                        objectView.topAnchor.constraint(equalTo: view.topAnchor),
                                        objectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        objectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        objectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                                    ])
    }

    // MARK: - UI
    private func setupUI() {
        // Remove segmented control entirely — nothing added to nav bar
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addFurnitureTapped)
        )

        navigationItem.rightBarButtonItem?.tintColor = .systemGreen
    }

    // MARK: - Load Model
    private func loadRoom() {
        Task {
            guard let model = try? await ModelEntity(contentsOf: roomURL) else {
                return
            }
            roomModel = model
            model.generateCollisionShapes(recursive: true)
            setupObjectScene()
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

    // MARK: - Furniture
    @objc private func addFurnitureTapped() {
        let picker = FurniturePicker()
        picker.onModelSelected = { [weak self] url in
            self?.insertFurniture(url: url)
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func insertFurniture(url: URL) {
        Task {
            guard let model = try? await ModelEntity(contentsOf: url) else {
                return
            }

            model.scale = [0.1, 0.1, 0.1]
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
        panel.attach(to: model)

        view.addSubview(panel)
        controlPanel = panel

        NSLayoutConstraint.activate([
                                        panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        panel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                                        panel.heightAnchor.constraint(equalToConstant: 170)
                                    ])
    }
}
