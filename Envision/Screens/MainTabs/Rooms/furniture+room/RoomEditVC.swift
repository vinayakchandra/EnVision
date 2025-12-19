import RealityKit
import UIKit

// MARK: - RoomEditVC
final class RoomEditVC: UIViewController {

    // MARK: - Inputs
    private let roomURL: URL

    // MARK: - Scene State
    private var roomModel: ModelEntity?
    private var displayedModel: ModelEntity?
    private var placedFurniture: [ModelEntity] = []

    // MARK: - Parametric State
    private var isParametricModel = false
    private var showLabels = false
    private var enableColors = false

    private var originalMaterials: [ModelEntity: [Material]] = [:]
    private var labels: [Entity: Entity] = [:]
    private var selectedModel: ModelEntity?

    // MARK: - Camera
    private let cameraAnchor = AnchorEntity()
    private let orbitCamera = PerspectiveCamera()
    private var cameraPitch: Float = .pi / 6
    private var cameraYaw: Float = .pi / 4
    private var cameraDistance: Float = 1.5

    // MARK: - Floating Menu
    private var floatingMenuButton: UIButton!

    // MARK: - Views
    private let arView: ARView = {
        let view = ARView(frame: .zero)
        view.cameraMode = .nonAR
        view.environment.background = .color(.systemGray6)
        return view
    }()

    private var orbitJoystick: OrbitJoystick?
    private var controlPanel: FurnitureControlPanel?

    // MARK: - Init
    init(roomURL: URL) {
        self.roomURL = roomURL
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Edit"
        navigationController?.navigationBar.prefersLargeTitles = true

        setupLayout()
        setupNavigation()
        setupGestures()
        setupFloatingMenu()
        loadRoom()
    }

    // MARK: - Floating Menu
    private func setupFloatingMenu() {
        let button = UIButton(type: .system)

        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: "pencil",     withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .medium))
        config.cornerStyle = .capsule
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white

        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false

        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowRadius = 6
        button.layer.shadowOffset = CGSize(width: 0, height: 4)

        button.showsMenuAsPrimaryAction = true
        button.menu = makeFloatingMenu()

        view.addSubview(button)
        floatingMenuButton = button

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            button.widthAnchor.constraint(equalToConstant: 56),
            button.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    private func makeFloatingMenu() -> UIMenu {

        let labelsAction = UIAction(
            title: "Show Labels",
            image: UIImage(systemName: "tag"),
            state: showLabels ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.showLabels.toggle()
            self.labels.values.forEach { $0.isEnabled = self.showLabels }
            self.refreshFloatingMenu()
        }

        let colorsAction = UIAction(
            title: "Enable Colors",
            image: UIImage(systemName: "paintpalette"),
            state: enableColors ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.enableColors.toggle()
            if let model = self.displayedModel {
                self.applyMaterialRules(to: model)
            }
            self.refreshFloatingMenu()
        }

        let resetAction = UIAction(
            title: "Reset",
            image: UIImage(systemName: "arrow.counterclockwise"),
            attributes: .destructive
        ) { [weak self] _ in
            guard let self else { return }
            self.showLabels = false
            self.enableColors = false
            self.labels.values.forEach { $0.isEnabled = false }
            if let model = self.displayedModel {
                self.applyMaterialRules(to: model)
            }
            self.refreshFloatingMenu()
        }

        return UIMenu(children: [resetAction, labelsAction, colorsAction]) // ending is first
    }

    private func refreshFloatingMenu() {
        floatingMenuButton.menu = makeFloatingMenu()
    }

    // MARK: - Layout
    private func setupLayout() {
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)

        NSLayoutConstraint.activate([
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Navigation
    private func setupNavigation() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addFurnitureTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .systemGreen
    }

    // MARK: - Gestures
    private func setupGestures() {
        arView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinch)))
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }

    // MARK: - Loading
    private func loadRoom() {
        Task {
            let entity = try await Entity.load(contentsOf: roomURL)
            await MainActor.run {
                prepareModel(entity)
            }
        }
    }

    private func prepareModel(_ entity: Entity) {
        entity.generateCollisionShapes(recursive: true)

        let model: ModelEntity = {
            if let m = entity as? ModelEntity { return m }
            let wrapper = ModelEntity()
            wrapper.addChild(entity)
            return wrapper
        }()

        roomModel = model
        detectParametricModel(model)
        setupScene(with: model)
    }

    private func detectParametricModel(_ model: ModelEntity) {
        var meshCount = 0
        model.visit {
            if $0.components[ModelComponent.self] != nil {
                meshCount += 1
            }
        }
        isParametricModel = meshCount > 2
    }

    // MARK: - Scene
    private func setupScene(with model: ModelEntity) {
        arView.scene.anchors.removeAll()

        let clone = model.clone(recursive: true)
        displayedModel = clone

        fitToScreen(clone)

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(clone)
        arView.scene.addAnchor(anchor)

        if isParametricModel {
            applyMaterialRules(to: clone)
        }

        setupCamera()
        setupOrbitJoystick()
    }

    private func fitToScreen(_ model: ModelEntity) {
        let bounds = model.visualBounds(relativeTo: nil)
        let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        guard maxDim > 0 else { return }
        model.scale = .init(repeating: 0.6 / maxDim)
    }

    // MARK: - Camera
    private func setupCamera() {
        cameraAnchor.children.removeAll()
        cameraAnchor.addChild(orbitCamera)
        arView.scene.addAnchor(cameraAnchor)
        updateCamera()
    }

    private func updateCamera() {
        let x = cameraDistance * cos(cameraPitch) * cos(cameraYaw)
        let y = cameraDistance * sin(cameraPitch)
        let z = cameraDistance * cos(cameraPitch) * sin(cameraYaw)

        orbitCamera.position = [x, y, z]
        orbitCamera.look(at: .zero, from: orbitCamera.position, relativeTo: nil)
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        cameraDistance = max(0.3, min(8, cameraDistance / Float(g.scale)))
        g.scale = 1
        updateCamera()
    }

    // MARK: - Orbit Joystick
    private func setupOrbitJoystick() {
        let joystick = OrbitJoystick()
        joystick.translatesAutoresizingMaskIntoConstraints = false
        joystick.onMove = { [weak self] dx, dy in
            guard let self else { return }
            self.cameraYaw += dx * 0.05
            self.cameraPitch = max(-1.4, min(1.4, self.cameraPitch + dy * 0.05))
            self.updateCamera()
        }

        view.addSubview(joystick)
        orbitJoystick = joystick

        NSLayoutConstraint.activate([
            joystick.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            joystick.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -180),
            joystick.widthAnchor.constraint(equalToConstant: 120),
            joystick.heightAnchor.constraint(equalToConstant: 120),
        ])
    }

    // MARK: - Materials & Labels
    private func applyMaterialRules(to root: Entity) {
        root.visit {
            guard let model = $0 as? ModelEntity else { return }

            if originalMaterials[model] == nil {
                originalMaterials[model] = model.model?.materials
            }

            guard enableColors else {
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
                model.model?.materials = [SimpleMaterial(color: .systemRed, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.5)

            case name.starts(with: "door"):
                model.model?.materials = [SimpleMaterial(color: .systemCyan.withAlphaComponent(0.3), roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.8)

            case name.starts(with: "window"):
                model.model?.materials = [SimpleMaterial(color: .lightGray.withAlphaComponent(0.3), roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.4)

            default:
                break
            }
        }
    }

    private func attachLabel(to entity: Entity, text: String, yOffset: Float) {
        labels[entity]?.removeFromParent()

        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.12)
        )

        let label = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
        label.position = [0, yOffset, 0]
        label.components.set(BillboardComponent())
        label.isEnabled = showLabels

        entity.addChild(label)
        labels[entity] = label
    }

    // MARK: - Furniture
    @objc private func addFurnitureTapped() {
        let picker = FurniturePicker()
        picker.onModelSelected = { [weak self] url in
            self?.insertFurniture(from: url)
        }
        present(UINavigationController(rootViewController: picker), animated: true)
    }

    private func insertFurniture(from url: URL) {
        Task {
            let model = try await ModelEntity(contentsOf: url)
            model.scale = .init(repeating: 0.1)
            model.generateCollisionShapes(recursive: true)

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(model)
            arView.scene.addAnchor(anchor)

            placedFurniture.append(model)
            showControls(for: model)
        }
    }

    private func showControls(for model: ModelEntity) {
        controlPanel?.removeFromSuperview()

        let panel = FurnitureControlPanel()
        panel.attach(to: model)
        panel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(panel)
        controlPanel = panel

        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            panel.heightAnchor.constraint(equalToConstant: 170),
        ])
    }

    // MARK: - Selection
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard isParametricModel else { return }
        let location = gesture.location(in: arView)
        selectedModel = arView.entity(at: location) as? ModelEntity
        presentColorPicker()
    }

    private func presentColorPicker() {
        let picker = UIColorPickerViewController()
        picker.delegate = self
        present(picker, animated: true)
    }
}

// MARK: - Color Picker
extension RoomEditVC: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        selectedModel?.model?.materials = [
            SimpleMaterial(color: viewController.selectedColor, roughness: 0.4, isMetallic: false)
        ]
    }
}
