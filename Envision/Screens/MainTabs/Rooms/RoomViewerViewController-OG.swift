//import UIKit
//import RealityKit
//import ARKit
//
//enum ViewerMode {
//    case object
//    case ar
//}
//
//final class RoomViewerViewController: UIViewController {
//
//    // MARK: - Inputs
//    private let roomURL: URL
//    private var viewerMode: ViewerMode
//
//    // MARK: - Views
//    private let arView = ARView(frame: .zero)
//    private let objectView = ARView(frame: .zero)
////    private let objectView = RealityView(frame: .zero)
//
//
//    // MARK: - State
//    private var roomModel: ModelEntity?
//    private var placedFurniture: [ModelEntity] = []
//
//    // MARK: - Buttons
//    private let modeToggle = UISegmentedControl(items: ["AR", "Object"])
//    private let addFurnitureButton = UIButton(type: .system)
//
//    // MARK: - Init
//    init(roomURL: URL, mode: ViewerMode = .object) {
//        self.roomURL = roomURL
//        self.viewerMode = mode
//        super.init(nibName: nil, bundle: nil)
//    }
//
//    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
//
//    // MARK: - Lifecycle
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .systemBackground
//        setupViews()
//        setupUI()
//        loadRoom()
//        applyInitialMode()
//    }
//
//    // MARK: - Setup Views
//    private func setupViews() {
//        arView.translatesAutoresizingMaskIntoConstraints = false
//        objectView.translatesAutoresizingMaskIntoConstraints = false
//
//        objectView.environment.sceneUnderstanding.options = [] // not AR mode
//
//        view.addSubview(arView)
//        view.addSubview(objectView)
//
//        NSLayoutConstraint.activate([
//            arView.topAnchor.constraint(equalTo: view.topAnchor),
//            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//
//            objectView.topAnchor.constraint(equalTo: view.topAnchor),
//            objectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            objectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            objectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//        ])
//
//        objectView.backgroundColor = .systemGray6
//    }
//
//    private func setupUI() {
//        modeToggle.selectedSegmentIndex = viewerMode == .ar ? 0 : 1
//        modeToggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
//
//        navigationItem.titleView = modeToggle
//
//        let shareButton = UIBarButtonItem(systemItem: .action, primaryAction: nil)
//        shareButton.target = self
//        shareButton.action = #selector(exportTapped)
//        navigationItem.rightBarButtonItem = shareButton
//
//        // Add furniture button
//        addFurnitureButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
//        addFurnitureButton.translatesAutoresizingMaskIntoConstraints = false
//        addFurnitureButton.addTarget(self, action: #selector(addFurnitureTapped), for: .touchUpInside)
//
//        view.addSubview(addFurnitureButton)
//
//        NSLayoutConstraint.activate([
//            addFurnitureButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
//            addFurnitureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
//            addFurnitureButton.widthAnchor.constraint(equalToConstant: 54),
//            addFurnitureButton.heightAnchor.constraint(equalToConstant: 54)
//        ])
//    }
//
//    // MARK: - Load Room
//    private func loadRoom() {
//        Task {
//            do {
//                let model = try await ModelEntity(contentsOf: roomURL)
//                model.generateCollisionShapes(recursive: true)
//                roomModel = model
//                applyInitialMode() // Ensure it loads when finished
//            } catch {
//                print("❌ Failed to load room:", error)
//            }
//        }
//    }
//
//    // MARK: - Mode Handling
//    private func applyInitialMode() {
//        viewerMode == .ar ? switchToAR() : switchToObject()
//    }
//
//    private func switchToObject1() {
//        guard let roomModel else { return }
//
//        objectView.isHidden = false
//        arView.isHidden = true
//
//        objectView.scene.anchors.removeAll()
//
//        let anchor = AnchorEntity(world: .zero)
//        let instance = roomModel.clone(recursive: true)
//
//        anchor.addChild(instance)
//        objectView.scene.addAnchor(anchor)
//
//        addGestures(to: instance, in: objectView)
//    }
//    
//    private func switchToObject() {
//        guard let roomModel else { return }
//
//        objectView.isHidden = false
//        arView.isHidden = true
//
//        // 🔧 Disable AR camera feed
//        objectView.cameraMode = .nonAR
//        objectView.session.pause()
//
//        objectView.scene.anchors.removeAll()
//
//        let anchor = AnchorEntity(world: .zero)
//        let instance = roomModel.clone(recursive: true)
//
//        anchor.addChild(instance)
//        objectView.scene.addAnchor(anchor)
//
//        addGestures(to: instance, in: objectView)
//
//        // Optional: give a clean background instead of transparency
//        objectView.environment.background = .color(.systemGray6)
//    }
//
//    private func switchToAR() {
//        guard let roomModel else { return }
//
//        arView.isHidden = false
//        objectView.isHidden = true
//
//        let config = ARWorldTrackingConfiguration()
//        config.planeDetection = [.horizontal, .vertical]
//
//        // 🧠 Safely enable mesh reconstruction only if the device supports it
//        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
//            config.sceneReconstruction = .mesh
//        }
//
//        arView.session.run(config, options: [.removeExistingAnchors, .resetTracking])
//        arView.scene.anchors.removeAll()
//
//        let anchor = AnchorEntity(plane: .horizontal)
//        let instance = roomModel.clone(recursive: true)
//        instance.position = SIMD3(0, 0, -1)
//
//        anchor.addChild(instance)
//        arView.scene.addAnchor(anchor)
//
//        addGestures(to: instance, in: arView)
//    }
//
//
//    // MARK: - Gestures
//    private func addGestures(to entity: ModelEntity, in view: ARView) {
//        entity.generateCollisionShapes(recursive: true)
//        view.installGestures([.translation, .rotation, .scale], for: entity)
//    }
//
//    // MARK: - Furniture
//    @objc private func addFurnitureTapped() {
//        let picker = FurniturePickerViewController()
//        picker.onModelSelected = { [weak self] url in
//            self?.insertFurniture(url: url)
//        }
//        present(UINavigationController(rootViewController: picker), animated: true)
//    }
//
//    private func insertFurniture(url: URL) {
//        Task {
//            guard let model = try? await ModelEntity(contentsOf: url) else { return }
//            model.scale = [0.5, 0.5, 0.5]
//            model.generateCollisionShapes(recursive: true)
//
//            let view = (viewerMode == .ar) ? arView : objectView
//            let anchor = viewerMode == .ar ? AnchorEntity(plane: .horizontal) : AnchorEntity(world: .zero)
//
//            model.position = viewerMode == .ar ? [0, 0, -0.6] : [0, 0, 0]
//
//            anchor.addChild(model)
//            view.scene.addAnchor(anchor)
//
//            placedFurniture.append(model)
//            addGestures(to: model, in: view)
//        }
//    }
//
//    // MARK: - Actions
//    @objc private func toggleChanged() {
//        viewerMode = modeToggle.selectedSegmentIndex == 0 ? .ar : .object
//        applyInitialMode()
//    }
//
//    @objc private func exportTapped() {
//        // TODO: Implement snapshot export
//        print("📤 Share tapped")
//    }
//}
