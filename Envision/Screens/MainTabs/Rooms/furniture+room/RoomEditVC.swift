import RealityKit
import UIKit

enum ColorTarget {
    case walls
    case doors
    case tables
    case floors
    case windows
    case storage
    case selected
}

private var colorTarget: ColorTarget = .selected

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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Cleanup labels
        cleanupLabels()
        
        // Save thumbnail of the colored room when leaving
        saveColoredThumbnail()
    }
    
    // MARK: - Thumbnail Capture
    private func saveColoredThumbnail() {
        // Always save thumbnail, even if no colors have been applied yet
        // This ensures newly scanned rooms get thumbnails on first view
        
        // Capture snapshot from ARView
        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let self = self, let image = image else {
                print("⚠️ Failed to capture ARView snapshot for thumbnail")
                return
            }
            
            // Save the thumbnail
            RoomColorManager.saveThumbnail(image, for: self.roomURL)
            
            // Post notification to refresh thumbnails in MyRooms
            NotificationCenter.default.post(
                name: Notification.Name("RoomThumbnailDidUpdate"),
                object: nil,
                userInfo: ["roomURL": self.roomURL]
            )
            
            print("✅ Saved room thumbnail via ARView snapshot")
        }
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
        let changeColorMenu = UIMenu(
            title: "Change Color",
            image: UIImage(systemName: "paintbrush.pointed"),
            children: [
                UIAction(title: "Walls", image: UIImage(systemName: "square.on.square")) { [weak self] _ in
                    self?.presentColorPicker(for: .walls)
                },

                UIAction(title: "Doors", image: UIImage(systemName: "door.left.hand.open")) { [weak self] _ in
                    self?.presentColorPicker(for: .doors)
                },

                UIAction(title: "Tables", image: UIImage(systemName: "table.furniture")) { [weak self] _ in
                    self?.presentColorPicker(for: .tables)
                },

                UIAction(title: "Floors", image: UIImage(systemName: "square.grid.3x3")) { [weak self] _ in
                    self?.presentColorPicker(for: .floors)
                },

                UIAction(title: "Windows", image: UIImage(systemName: "window.vertical.closed")) { [weak self] _ in
                    self?.presentColorPicker(for: .windows)
                },

                UIAction(title: "Storage", image: UIImage(systemName: "archivebox")) { [weak self] _ in
                    self?.presentColorPicker(for: .storage)
                },
            ]
        )

        let labelsAction = UIAction(
            title: "Show Labels",
            image: UIImage(systemName: "tag"),
            state: showLabels ? .on : .off
        ) { [weak self] _ in
            self?.showLabels.toggle()
            self?.labels.values.forEach { $0.isEnabled = self?.showLabels ?? false }
            self?.refreshFloatingMenu()
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

        return UIMenu(children: [resetAction, changeColorMenu, labelsAction, colorsAction]) // ending is first
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
        // Save button to save colors and go back
        let saveButton = UIBarButtonItem(
            title: "Save",
            style: .done,
            target: self,
            action: #selector(saveAndGoBack)
        )
        saveButton.tintColor = .systemGreen
        
        // Only Save button in Edit mode (no add furniture button)
        navigationItem.rightBarButtonItems = [saveButton]
    }
    
    @objc private func saveAndGoBack() {
        // Save thumbnail using ARView snapshot before going back
        saveColoredThumbnail()
        
        // Show success feedback
        let alert = UIAlertController(
            title: "Saved",
            message: "Room colors have been saved successfully.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            // Navigate back to home (My Rooms)
            self?.navigationController?.popToRootViewController(animated: true)
        })
        present(alert, animated: true)
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
        var entitiesFound:[String] = []
        let savedColors = RoomColorManager.shared.getAllColors(for: roomURL)
        
        root.visit {
            guard let model = $0 as? ModelEntity else { return }

            // Cache original materials once
            if originalMaterials[model] == nil {
                originalMaterials[model] = model.model?.materials
            }

            // 🔴 Enable Colors OFF → apply saved colors or white
            guard enableColors else {
                let name = model.name.lowercased()
                
                // Check for saved colors first
                if name.starts(with: "wall"), let color = savedColors[RoomColorManager.wallKey] {
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                } else if name.starts(with: "floor"), let color = savedColors[RoomColorManager.floorKey] {
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.6, isMetallic: false)]
                } else if name.starts(with: "door"), let color = savedColors[RoomColorManager.doorKey] {
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                } else if name.starts(with: "window"), let color = savedColors[RoomColorManager.windowKey] {
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                } else if name.starts(with: "table"), let color = savedColors[RoomColorManager.tableKey] {
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                } else if name.starts(with: "chair"), let color = savedColors[RoomColorManager.chairKey] {
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                } else if name.starts(with: "storage"), let color = savedColors[RoomColorManager.storageKey] {
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                } else {
                    model.model?.materials = [SimpleMaterial(color: .white.withAlphaComponent(0.9), roughness: 0.8, isMetallic: false)]
                }
                return
            }

            // 🟢 Enable Colors ON → apply saved colors or default semantic colors
            let name = model.name.lowercased()
            entitiesFound.append(name)

            switch true {
            case name.starts(with: "wall"):
                let color = savedColors[RoomColorManager.wallKey] ?? .systemBlue
                model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 1.5)

            case name.starts(with: "floor"):
                let color = savedColors[RoomColorManager.floorKey] ?? .gray
                model.model?.materials = [SimpleMaterial(color: color, roughness: 0.6, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.05)

            case name.starts(with: "chair"):
                let color = savedColors[RoomColorManager.chairKey] ?? .black
                model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.15)

            case name.starts(with: "table"):
                let color = savedColors[RoomColorManager.tableKey] ?? .systemRed
                model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.5)

            case name.starts(with: "door"):
                let color = savedColors[RoomColorManager.doorKey] ?? .systemCyan.withAlphaComponent(0.3)
                model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.8)

            case name.starts(with: "window"):
                let color = savedColors[RoomColorManager.windowKey] ?? .lightGray.withAlphaComponent(0.3)
                model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.4)

            case name.starts(with: "storage"):
                let color = savedColors[RoomColorManager.storageKey] ?? .systemOrange
                model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.4)

            default:
                // break
                // fallback → original materials
                if let original = originalMaterials[model] {
                    model.model?.materials = original
                }
            }
        }
        // print(entitiesFound)
    }

    private func setColorForAllWalls(_ color: UIColor) {
        guard let root = displayedModel else { return }

        root.visit {
            guard let model = $0 as? ModelEntity else { return }
            let name = model.name.lowercased()

            if name.starts(with: "wall") {
                model.model?.materials = [
                    SimpleMaterial(
                        color: color,
                        roughness: 0.4,
                        isMetallic: false
                    )
                ]
            }
        }
    }
    private func setColor(for target: ColorTarget, color: UIColor) {
        guard let root = displayedModel else { return }

        let prefixes: [ColorTarget: String] = [
            .walls: "wall",
            .doors: "door",
            .tables: "table",
            .floors: "floor",
            .windows: "window",
            .storage: "storage"
        ]

        guard let prefix = prefixes[target] else { return }

        root.visit {
            guard let model = $0 as? ModelEntity else { return }
            if model.name.lowercased().starts(with: prefix) {
                model.model?.materials = [
                    SimpleMaterial(
                        color: color,
                        roughness: 0.4,
                        isMetallic: false
                    )
                ]
            }
        }
    }
    private func presentColorPicker(for target: ColorTarget) {
        colorTarget = target
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.supportsAlpha = true
        
        // Wrap in navigation controller to add custom buttons
        let navController = UINavigationController(rootViewController: picker)
        navController.modalPresentationStyle = .pageSheet
        
        // Add native Cancel button (left side)
        let cancelButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelColorPicker)
        )
        picker.navigationItem.leftBarButtonItem = cancelButton
        
        // Add native Done button (right side)
        let doneButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissColorPicker)
        )
        picker.navigationItem.rightBarButtonItem = doneButton
        picker.navigationItem.title = "Choose Color"
        
        present(navController, animated: true)
    }
    
    @objc private func cancelColorPicker() {
        // Restore original materials when cancelling
        if let model = displayedModel {
            applyMaterialRules(to: model)
        }
        dismiss(animated: true)
    }
    
    @objc private func dismissColorPicker() {
        dismiss(animated: true)
    }

    private func attachLabel(to entity: Entity, text: String, yOffset: Float) {
        // Remove existing label safely
        if let existingLabel = labels[entity] {
            existingLabel.components.remove(BillboardComponent.self)
            existingLabel.removeFromParent()
            labels[entity] = nil
        }

        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.12)
        )

        let label = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])
        label.position = [0, yOffset, 0]
        label.isEnabled = showLabels
        
        // Add to parent first, then set BillboardComponent on main thread
        entity.addChild(label)
        labels[entity] = label
        
        // Set BillboardComponent after a brief delay to avoid crash
        DispatchQueue.main.async { [weak label] in
            guard let label = label, label.parent != nil else { return }
            label.components.set(BillboardComponent())
        }
    }
    
    // MARK: - Cleanup
    private func cleanupLabels() {
        for (_, label) in labels {
            label.components.remove(BillboardComponent.self)
            label.removeFromParent()
        }
        labels.removeAll()
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
        colorTarget = .selected
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.supportsAlpha = true
        
        // Wrap in navigation controller to add custom buttons
        let navController = UINavigationController(rootViewController: picker)
        navController.modalPresentationStyle = .pageSheet
        
        // Add native Cancel button (left side)
        let cancelButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelColorPicker)
        )
        picker.navigationItem.leftBarButtonItem = cancelButton
        
        // Add native Done button (right side)
        let doneButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissColorPicker)
        )
        picker.navigationItem.rightBarButtonItem = doneButton
        picker.navigationItem.title = "Choose Color"
        
        present(navController, animated: true)
    }
}

// MARK: - Color Picker
extension RoomEditVC: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        let selectedColor = viewController.selectedColor

        switch colorTarget {
        case .selected:
            selectedModel?.model?.materials = [
                SimpleMaterial(color: selectedColor, roughness: 0.4, isMetallic: false)
            ]
            // Save color for selected element type
            if let modelName = selectedModel?.name.lowercased() {
                let elementType = getElementType(from: modelName)
                if let type = elementType {
                    RoomColorManager.shared.saveColor(selectedColor, for: type, roomURL: roomURL)
                }
            }

        default:
            setColor(for: colorTarget, color: selectedColor)
            // Save color for the target type
            if let elementType = colorTargetToElementType(colorTarget) {
                RoomColorManager.shared.saveColor(selectedColor, for: elementType, roomURL: roomURL)
            }
        }
    }
    
    private func getElementType(from name: String) -> String? {
        if name.starts(with: "wall") { return RoomColorManager.wallKey }
        if name.starts(with: "floor") { return RoomColorManager.floorKey }
        if name.starts(with: "door") { return RoomColorManager.doorKey }
        if name.starts(with: "window") { return RoomColorManager.windowKey }
        if name.starts(with: "table") { return RoomColorManager.tableKey }
        if name.starts(with: "chair") { return RoomColorManager.chairKey }
        if name.starts(with: "storage") { return RoomColorManager.storageKey }
        return nil
    }
    
    private func colorTargetToElementType(_ target: ColorTarget) -> String? {
        switch target {
        case .walls: return RoomColorManager.wallKey
        case .floors: return RoomColorManager.floorKey
        case .doors: return RoomColorManager.doorKey
        case .windows: return RoomColorManager.windowKey
        case .tables: return RoomColorManager.tableKey
        case .storage: return RoomColorManager.storageKey
        case .selected: return nil
        }
    }
}
