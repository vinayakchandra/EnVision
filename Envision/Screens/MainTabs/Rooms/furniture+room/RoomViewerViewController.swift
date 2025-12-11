import RealityKit
import UIKit

final class RoomViewerViewController: UIViewController {

    // MARK: - Inputs
    private let roomURL: URL
    private var placedFurniture: [ModelEntity] = []

    // MARK: - Views
    private let objectView = ARView(frame: .zero)  // 3D renderer only

    // MARK: - State
    private var roomModel: ModelEntity?

    // Orbit Camera
    private var orbitCamera: PerspectiveCamera?
    private var cameraAnchor = AnchorEntity()
    private var cameraPitch: Float = .pi / 6
    private var cameraYaw: Float = .pi / 4
    private var cameraDistance: Float = 1.5
    private var controlPanel: FurnitureControlPanel?
    // MARK: - Parametric Features
    private var isParametricModel = false

    private var showLabels = false
    private var colorToggleIsOn = false

    private var originalMaterials: [ModelEntity: [Material]] = [:]
    private var labelStorage: [Entity: Entity] = [:]

    private var selectedModel: ModelEntity?
    private var displayedModel: ModelEntity?


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
        setupTapGesture()
    }

    // MARK: - Layout
    private func setupLayout() {
        objectView.translatesAutoresizingMaskIntoConstraints = false
        objectView.cameraMode = .nonAR
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addFurnitureTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .systemGreen

    }
    private func setupParametricToggles() {
        guard isParametricModel else { return }

        let labelToggle = UISwitch()
        labelToggle.isOn = false
        labelToggle.addTarget(self, action: #selector(toggleLabels(_:)), for: .valueChanged)
        labelToggle.translatesAutoresizingMaskIntoConstraints = false

        let labelText = UILabel()
        labelText.text = "Show Labels"
        labelText.textColor = .white
        labelText.translatesAutoresizingMaskIntoConstraints = false

        let colorToggle = UISwitch()
        colorToggle.isOn = false
        colorToggle.addTarget(self, action: #selector(toggleColors(_:)), for: .valueChanged)
        colorToggle.translatesAutoresizingMaskIntoConstraints = false

        let colorText = UILabel()
        colorText.text = "Enable Colors"
        colorText.textColor = .white
        colorText.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(labelToggle)
        view.addSubview(labelText)
        view.addSubview(colorToggle)
        view.addSubview(colorText)

        NSLayoutConstraint.activate([
                                        labelToggle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
                                        labelToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                                        labelText.centerYAnchor.constraint(equalTo: labelToggle.centerYAnchor),
                                        labelText.leadingAnchor.constraint(equalTo: labelToggle.trailingAnchor, constant: 10),

                                        colorToggle.topAnchor.constraint(equalTo: labelToggle.bottomAnchor, constant: 10),
                                        colorToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                                        colorText.centerYAnchor.constraint(equalTo: colorToggle.centerYAnchor),
                                        colorText.leadingAnchor.constraint(equalTo: colorToggle.trailingAnchor, constant: 10),
                                    ])
    }

    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        objectView.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isParametricModel else { return }

        let loc = gesture.location(in: objectView)
        if let entity = objectView.entity(at: loc) as? ModelEntity {
            selectedModel = entity
            presentColorPicker()
        }
    }

    private func presentColorPicker() {
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.supportsAlpha = true
        present(picker, animated: true)
    }

    private func applyMaterialRules(to root: Entity) {
        root.visit { entity in
            guard let model = entity as? ModelEntity else { return }

            if originalMaterials[model] == nil {
                originalMaterials[model] = model.model?.materials ?? []
            }

            guard colorToggleIsOn else {
                // Restore original material
                if let original = originalMaterials[model] {
                    model.model?.materials = original
                }
                return
            }

            let name = model.name.lowercased()

            switch true {
            case name.starts(with: "wall"):
                model.model?.materials = [SimpleMaterial(color: .systemBlue, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 1.5)

            case name.starts(with: "floor"):
                model.model?.materials = [SimpleMaterial(color: .gray, roughness: 0.6, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.05)

            case name.starts(with: "chair"):
                model.model?.materials = [SimpleMaterial(color: .black, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.15)

            case name.starts(with: "table"):
                model.model?.materials = [SimpleMaterial(color: .systemPink, roughness: 0.4, isMetallic: true)]
                attachLabel(to: model, text: name, yOffset: 0.5)

            default:
                break
            }
        }
    }

    private func attachLabel(to entity: Entity, text: String, yOffset: Float) {
        labelStorage[entity]?.removeFromParent()

        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.12)
        )

        let label = ModelEntity(
            mesh: mesh,
            materials: [SimpleMaterial(color: .white, isMetallic: false)])

        label.position = [0, yOffset, 0]
        label.components.set(BillboardComponent())
        label.isEnabled = showLabels

        entity.addChild(label)
        labelStorage[entity] = label
    }

    @objc private func toggleLabels(_ sender: UISwitch) {
        showLabels = sender.isOn

        for (_, label) in labelStorage {
            label.isEnabled = showLabels
        }
    }


    @objc private func toggleColors(_ sender: UISwitch) {
        colorToggleIsOn = sender.isOn

        if let model = displayedModel {
            applyMaterialRules(to: model)
        }
    }


    // MARK: - Load Model (FIXED)
    private func loadRoom() {
        Task {
            let rootEntity = try await Entity.load(contentsOf: roomURL)
            rootEntity.generateCollisionShapes(recursive: true)

            // Wrap in ModelEntity if needed (RealityKit-compatible)
            let model: ModelEntity
            if let m = rootEntity as? ModelEntity {
                model = m
            } else {
                let wrapper = ModelEntity()
                wrapper.addChild(rootEntity)
                model = wrapper
            }

            self.roomModel = model

            // FIX 2: Correct mesh detection
            var meshCount = 0
            var foundNames: [String] = []

            model.visit { entity in
                guard entity.components[ModelComponent.self] != nil else { return }

                meshCount += 1
                let name = entity.name.isEmpty ? "(unnamed)" : entity.name
                foundNames.append(name)

                let bounds = entity.visualBounds(relativeTo: nil)
                let size = bounds.extents
            }

            print("🧱 Found mesh names:", foundNames)
            print("🔢 Mesh count:", meshCount)

            self.isParametricModel = foundNames.count > 2
            print(self.isParametricModel ? "✅ PARAMETRIC" : "❌ NOT PARAMETRIC")

            DispatchQueue.main.async {
                if self.isParametricModel {
                    self.setupParametricToggles()
                }
            }
            setupObjectScene()
        }
    }

    // MARK: - Object Viewer Scene
    private func setupObjectScene() {
        guard let roomModel else { return }

        objectView.scene.anchors.removeAll()

        let anchor = AnchorEntity(world: .zero)
        let clone = roomModel.clone(recursive: true)
        self.displayedModel = clone

        fitToScreen(clone)
        anchor.addChild(clone)
        objectView.scene.addAnchor(anchor)

        // ---- IMPORTANT FIX ----
        if isParametricModel {
            applyMaterialRules(to: clone)   // initializes materials + labels
        }
        // ------------------------

        setupOrbitCamera(target: clone)
        enableOrbitGestures()
    }

    private func fitToScreen(_ model: ModelEntity) {
        let bounds = model.visualBounds(relativeTo: nil)
        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        guard maxDim > 0 else { return }
        model.scale = SIMD3<Float>(repeating: 0.6 / maxDim)
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

    // MARK: - Furniture Management
    @objc private func addFurnitureTapped() {
        let picker = FurniturePicker()
        picker.onModelSelected = { [weak self] url in
            self?.insertFurniture(url: url)
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func insertFurniture(url: URL) {
        Task {
            guard let model = try? await ModelEntity(contentsOf: url) else { return }

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
                                        panel.heightAnchor.constraint(equalToConstant: 170),
                                    ])
    }
}
extension RoomViewerViewController: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        guard let selectedModel else { return }

        selectedModel.model?.materials = [
            SimpleMaterial(color: viewController.selectedColor, roughness: 0.4, isMetallic: false)
        ]
    }
}
