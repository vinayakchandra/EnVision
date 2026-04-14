import RealityKit
import UIKit

enum ColorTarget {
    case walls
    case doors
    case tables
    case chairs
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
    private var isRulerVisible = false
    private var hiddenEntityPrefixes: Set<String> = []
    private var forceWhiteSurfacePrefixes: Set<String> = []
    private var collisionsEnabled = false
    private var hasGeneratedBaseCollisionShapes = false
    private var collisionGestures: [EntityGestureRecognizer] = []

    private var originalMaterials: [ModelEntity: [Material]] = [:]
    private var labels: [Entity: Entity] = [:]
    private var selectedModel: ModelEntity?
    private var roomBoundingBox: BoundingBoxEntity?

    // MARK: - Camera
    private let cameraAnchor = AnchorEntity()
    private let orbitCamera = PerspectiveCamera()
    private var cameraPitch: Float = .pi / 6
    private var cameraYaw: Float = .pi / 4
    private var cameraDistance: Float = 1.5

    // MARK: - Floating Menu
    private var floatingMenuButton: UIButton!
    private var viewDockButton: UIButton!
    private var colorDockButton: UIButton!
    private var textureDockButton: UIButton!
    private var hideDockButton: UIButton!
    private var labelsDockButton: UIButton!

    // MARK: - Views
    private let arView: ARView = {
        let view = ARView(frame: .zero)
        view.cameraMode = .nonAR
        view.environment.background = .color(.systemGray6)
        return view
    }()

    private var orbitJoystick: OrbitJoystick?
    private var controlPanel: FurnitureControlPanel?
    private var loadingOverlay: UIVisualEffectView?
    private var loadingIndicator: UIActivityIndicatorView?
    private var loadingLabel: UILabel?

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
        setupLoadingOverlay()
        setupNavigation()
        setupGestures()
        setupFloatingMenu()
        RoomColorManager.shared.ensureBundledTexturesAvailable()
        hiddenEntityPrefixes = RoomColorManager.shared.getHiddenEntityPrefixes(for: roomURL)
        forceWhiteSurfacePrefixes = RoomColorManager.shared.getForceWhiteSurfacePrefixes(for: roomURL)
        enableColors = RoomColorManager.shared.isEnableColorsEnabled(for: roomURL)
        loadRoom()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        cleanupLabels()
        hideRoomRuler()
        disableCollisionFeatures()
        RoomColorManager.shared.saveHiddenEntityPrefixes(hiddenEntityPrefixes, roomURL: roomURL)
        RoomColorManager.shared.saveForceWhiteSurfacePrefixes(forceWhiteSurfacePrefixes, roomURL: roomURL)
        RoomColorManager.shared.saveEnableColorsEnabled(enableColors, roomURL: roomURL)
        saveColoredThumbnail()
    }

    // MARK: - Thumbnail Capture

    // Guards against the snapshot callback firing after the VC is gone or a second
    // save being triggered while the first async callback is still in-flight.
    private var isSavingThumbnail = false

    private func saveColoredThumbnail() {
        guard !isSavingThumbnail else { return }
        isSavingThumbnail = true

        // Capture a strong reference to roomURL before the view might be deallocated.
        let url = roomURL

        arView.snapshot(saveToHDR: false) { [weak self] image in
            defer { self?.isSavingThumbnail = false }

            guard let image else {
                print("⚠️ ARView snapshot returned nil — thumbnail not updated")
                return
            }

            RoomColorManager.saveThumbnail(image, for: url)

            NotificationCenter.default.post(
                name: Notification.Name("RoomThumbnailDidUpdate"),
                object: nil,
                userInfo: ["roomURL": url]
            )
        }
    }

    // MARK: - Floating Menu
    private func setupLoadingOverlay() {
        let blur = UIBlurEffect(style: .systemMaterial)
        let overlay = UIVisualEffectView(effect: blur)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.layer.cornerRadius = 12
        overlay.clipsToBounds = true
        overlay.isHidden = true

        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Loading room..."
        label.font = .preferredFont(forTextStyle: .body)
        label.textAlignment = .center

        overlay.contentView.addSubview(indicator)
        overlay.contentView.addSubview(label)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            overlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            overlay.widthAnchor.constraint(equalToConstant: UIDevice.current.userInterfaceIdiom == .pad ? 260 : 220),
            overlay.heightAnchor.constraint(equalToConstant: 120),

            indicator.topAnchor.constraint(equalTo: overlay.contentView.topAnchor, constant: 18),
            indicator.centerXAnchor.constraint(equalTo: overlay.contentView.centerXAnchor),

            label.topAnchor.constraint(equalTo: indicator.bottomAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: overlay.contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: overlay.contentView.trailingAnchor, constant: -12),
        ])

        loadingOverlay = overlay
        loadingIndicator = indicator
        loadingLabel = label
    }

    private func showLoadingOverlay(message: String = "Loading room...") {
        loadingLabel?.text = message
        loadingOverlay?.isHidden = false
        loadingIndicator?.startAnimating()
        view.isUserInteractionEnabled = false
    }

    private func hideLoadingOverlay() {
        loadingIndicator?.stopAnimating()
        loadingOverlay?.isHidden = true
        view.isUserInteractionEnabled = true
    }

    // MARK: - Floating Menu
    private func setupFloatingMenu() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        container.layer.cornerRadius = 24
        container.layer.cornerCurve = .continuous
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.25
        container.layer.shadowRadius = 12
        container.layer.shadowOffset = CGSize(width: 0, height: 6)
        view.addSubview(container)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .fillEqually
        stack.spacing = 4
        container.addSubview(stack)

        let viewButton = makeDockItemButton(title: "View", systemImage: "view.3d", action: nil)
        viewButton.showsMenuAsPrimaryAction = true
        viewButton.menu = makeViewMenu()
        stack.addArrangedSubview(viewButton)
        viewDockButton = viewButton

        let colorButton = makeDockItemButton(title: "Color", systemImage: "paintpalette", action: nil)
        colorButton.showsMenuAsPrimaryAction = true
        colorButton.menu = makeColorMenu()
        stack.addArrangedSubview(colorButton)
        colorDockButton = colorButton

        let textureButton = makeDockItemButton(title: "Texture", systemImage: "photo.on.rectangle", action: #selector(textureDockTapped))
        stack.addArrangedSubview(textureButton)
        textureDockButton = textureButton

        let hideButton = makeDockItemButton(title: "Hide", systemImage: "eye.slash", action: nil)
        hideButton.showsMenuAsPrimaryAction = true
        hideButton.menu = makeHideMenu()
        stack.addArrangedSubview(hideButton)
        hideDockButton = hideButton

        let labelsButton = makeDockItemButton(title: "Labels", systemImage: "tag", action: #selector(toggleLabelsTapped))
        stack.addArrangedSubview(labelsButton)
        labelsDockButton = labelsButton

        let menuButton = makeDockItemButton(title: "More", systemImage: "ellipsis", action: nil)
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = makeFloatingMenu()
        menuButton.accessibilityLabel = "More edit options"
        stack.addArrangedSubview(menuButton)
        floatingMenuButton = menuButton

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            container.heightAnchor.constraint(equalToConstant: 74),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 18),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -18),

            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])

        updateDockButtonStates()
    }

    private func makeDockItemButton(title: String, systemImage: String, action: Selector?) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .clear
        button.tintColor = .white
        button.layer.cornerRadius = 14
        button.layer.cornerCurve = .continuous

        var config = UIButton.Configuration.plain()
        config.image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        )
        config.title = title
        config.imagePlacement = .top
        config.imagePadding = 4
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
            return out
        }
        button.configuration = config

        if let action {
            button.addTarget(self, action: action, for: .touchUpInside)
        }
        return button
    }

    private enum CameraPreset {
        case isometric
        case top
        case bottom
        case left
        case right
        case front
        case back
    }

    private func makeViewMenu() -> UIMenu {
        UIMenu(
            title: "Camera Views",
            children: [
                UIAction(title: "Top", image: UIImage(systemName: "arrow.up.to.line")) { [weak self] _ in
                    self?.applyCameraPreset(.top)
                },
                UIAction(title: "Bottom", image: UIImage(systemName: "arrow.down.to.line")) { [weak self] _ in
                    self?.applyCameraPreset(.bottom)
                },
                UIAction(title: "Left Side", image: UIImage(systemName: "arrow.left.to.line")) { [weak self] _ in
                    self?.applyCameraPreset(.left)
                },
                UIAction(title: "Right Side", image: UIImage(systemName: "arrow.right.to.line")) { [weak self] _ in
                    self?.applyCameraPreset(.right)
                },
                UIAction(title: "Front", image: UIImage(systemName: "viewfinder")) { [weak self] _ in
                    self?.applyCameraPreset(.front)
                },
                UIAction(title: "Back", image: UIImage(systemName: "arrow.backward")) { [weak self] _ in
                    self?.applyCameraPreset(.back)
                },
                UIAction(title: "Isometric", image: UIImage(systemName: "cube")) { [weak self] _ in
                    self?.applyCameraPreset(.isometric)
                },
            ]
        )
    }

    private func makeColorMenu() -> UIMenu {
        UIMenu(
            title: "Change Color",
            children: [
                UIAction(title: "Walls", image: UIImage(systemName: "square.on.square")) { [weak self] _ in
                    self?.presentColorPicker(for: .walls)
                },
                UIAction(title: "Floors", image: UIImage(systemName: "square.grid.3x3")) { [weak self] _ in
                    self?.presentColorPicker(for: .floors)
                },
                UIAction(title: "Doors", image: UIImage(systemName: "door.left.hand.open")) { [weak self] _ in
                    self?.presentColorPicker(for: .doors)
                },
                UIAction(title: "Windows", image: UIImage(systemName: "window.vertical.closed")) { [weak self] _ in
                    self?.presentColorPicker(for: .windows)
                },
                UIAction(title: "Tables", image: UIImage(systemName: "table.furniture")) { [weak self] _ in
                    self?.presentColorPicker(for: .tables)
                },
                UIAction(title: "Chairs", image: UIImage(systemName: "chair")) { [weak self] _ in
                    self?.presentColorPicker(for: .chairs)
                },
                UIAction(title: "Storage", image: UIImage(systemName: "archivebox")) { [weak self] _ in
                    self?.presentColorPicker(for: .storage)
                }
            ]
        )
    }

    private func makeHideMenu() -> UIMenu {
        let hideableTypes: [(title: String, prefix: String, icon: String)] = [
            ("Walls", "wall", "square.on.square"),
            ("Floors", "floor", "square.grid.3x3"),
            ("Doors", "door", "door.left.hand.open"),
            ("Windows", "window", "window.vertical.closed"),
            ("Tables", "table", "table.furniture"),
            ("Chairs", "chair", "chair"),
            ("Storage", "storage", "archivebox")
        ]

        let actions = hideableTypes.map { item in
            UIAction(
                title: "Hide \(item.title)",
                image: UIImage(systemName: item.icon),
                state: hiddenEntityPrefixes.contains(item.prefix) ? .on : .off
            ) { [weak self] _ in
                self?.toggleEntityTypeHidden(prefix: item.prefix)
            }
        }

        let showAllAction = UIAction(
            title: "Show All",
            image: UIImage(systemName: "eye"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.hiddenEntityPrefixes.removeAll()
            self?.applyEntityVisibilityRules()
            if let self {
                RoomColorManager.shared.saveHiddenEntityPrefixes(self.hiddenEntityPrefixes, roomURL: self.roomURL)
            }
            self?.refreshFloatingMenu()
            self?.updateDockButtonStates()
        }

        return UIMenu(title: "Hide Entities", children: actions + [showAllAction])
    }

    private func applyCameraPreset(_ preset: CameraPreset) {
        let fallbackDistance: Float = 1.5
        if let model = displayedModel {
            let bounds = model.visualBounds(relativeTo: nil)
            let maxDim = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
            cameraDistance = max(0.8, maxDim * 2.2)
        } else {
            cameraDistance = fallbackDistance
        }

        switch preset {
        case .isometric:
            cameraPitch = .pi / 6
            cameraYaw = .pi / 4
        case .top:
            cameraPitch = (.pi / 2) - 0.01
            cameraYaw = 0
        case .bottom:
            cameraPitch = -(.pi / 2) + 0.01
            cameraYaw = 0
        case .left:
            cameraPitch = 0
            cameraYaw = .pi
        case .right:
            cameraPitch = 0
            cameraYaw = 0
        case .front:
            cameraPitch = 0
            cameraYaw = .pi / 2
        case .back:
            cameraPitch = 0
            cameraYaw = -(.pi / 2)
        }
        updateCamera()
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

                UIAction(title: "Chairs", image: UIImage(systemName: "chair")) { [weak self] _ in
                    self?.presentColorPicker(for: .chairs)
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
            self?.updateDockButtonStates()
        }

        let colorsAction = UIAction(
            title: "Enable Colors",
            image: UIImage(systemName: "paintpalette"),
            state: enableColors ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.enableColors.toggle()
            RoomColorManager.shared.saveEnableColorsEnabled(self.enableColors, roomURL: self.roomURL)
            if self.enableColors {
                // Reset "force white" override so color mode can render immediately.
                self.forceWhiteSurfacePrefixes.removeAll()
                RoomColorManager.shared.saveForceWhiteSurfacePrefixes(self.forceWhiteSurfacePrefixes, roomURL: self.roomURL)
                self.saveSemanticColorsAsCurrentTheme()
            }
            if let model = self.displayedModel {
                self.applyMaterialRules(to: model)
            }
            self.refreshFloatingMenu()
        }

        let rulerAction = UIAction(
            title: "Ruler",
            image: UIImage(systemName: "ruler"),
            state: isRulerVisible ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.rulerTapped()
            self.refreshFloatingMenu()
        }
        
        let collisionsAction = UIAction(
            title: "Enable Collision",
            image: UIImage(systemName: "cube.transparent"),
            state: collisionsEnabled ? .on : .off
        ) { [weak self] _ in
            guard let self else { return }
            self.collisionsEnabled.toggle()
            if self.collisionsEnabled {
                self.enableCollisionFeatures()
            } else {
                self.disableCollisionFeatures()
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
            self.collisionsEnabled = false
            self.disableCollisionFeatures()
            self.hiddenEntityPrefixes.removeAll()
            self.forceWhiteSurfacePrefixes = Set(RoomColorManager.surfaceConfigs.map { $0.prefix })
            self.labels.values.forEach { $0.isEnabled = false }

            // Clear all texture selections explicitly so reset survives reopen.
            for config in RoomColorManager.surfaceConfigs {
                RoomColorManager.shared.clearTexture(for: config.textureKey, roomURL: self.roomURL)
            }

            self.resetRoomAppearanceToPlainWhite()
            self.applyEntityVisibilityRules()
            RoomColorManager.shared.saveHiddenEntityPrefixes(self.hiddenEntityPrefixes, roomURL: self.roomURL)
            RoomColorManager.shared.saveForceWhiteSurfacePrefixes(self.forceWhiteSurfacePrefixes, roomURL: self.roomURL)
            RoomColorManager.shared.saveEnableColorsEnabled(self.enableColors, roomURL: self.roomURL)
            self.refreshFloatingMenu()
            self.updateDockButtonStates()
        }

        return UIMenu(children: [resetAction, rulerAction, changeColorMenu, labelsAction, colorsAction, collisionsAction])
    }

    private func refreshFloatingMenu() {
        floatingMenuButton.menu = makeFloatingMenu()
        colorDockButton?.menu = makeColorMenu()
        hideDockButton?.menu = makeHideMenu()
        viewDockButton?.menu = makeViewMenu()
    }

    private func updateDockButtonStates() {
        setDockButtonSelection(hideDockButton, isSelected: !hiddenEntityPrefixes.isEmpty)
        setDockButtonSelection(labelsDockButton, isSelected: showLabels)
    }

    private func toggleEntityTypeHidden(prefix: String) {
        if hiddenEntityPrefixes.contains(prefix) {
            hiddenEntityPrefixes.remove(prefix)
        } else {
            hiddenEntityPrefixes.insert(prefix)
        }
        applyEntityVisibilityRules()
        RoomColorManager.shared.saveHiddenEntityPrefixes(hiddenEntityPrefixes, roomURL: roomURL)
        refreshFloatingMenu()
        updateDockButtonStates()
    }

    private func applyEntityVisibilityRules() {
        guard let root = displayedModel else { return }

        root.visit {
            guard let model = $0 as? ModelEntity else { return }
            let name = model.name.lowercased()

            if let prefix = self.entityPrefix(for: name) {
                model.isEnabled = !self.hiddenEntityPrefixes.contains(prefix)
            }
        }
    }

    private func entityPrefix(for name: String) -> String? {
        let prefixes = ["wall", "floor", "door", "window", "table", "chair", "storage"]
        return prefixes.first(where: { name.starts(with: $0) })
    }

    private func enableCollisionFeatures() {
        guard let root = displayedModel else { return }
        disableCollisionFeatures()
        ensureBaseCollisionShapesGenerated(for: root)
        
        var installed = Set<ObjectIdentifier>()
        root.visit { entity in
            guard entity !== root else { return }
            guard self.belongsToMovableGroup(entity) else { return }
            guard let collisionEntity = entity as? (Entity & HasCollision) else { return }
            
            let id = ObjectIdentifier(entity)
            guard !installed.contains(id) else { return }
            installed.insert(id)
            
            collisionGestures.append(
                contentsOf: arView.installGestures([.scale, .rotation, .translation], for: collisionEntity)
            )
        }
    }
    
    private func ensureBaseCollisionShapesGenerated(for root: ModelEntity) {
        guard !hasGeneratedBaseCollisionShapes else { return }
        root.generateCollisionShapes(recursive: true)
        hasGeneratedBaseCollisionShapes = true
    }

    private func disableCollisionFeatures() {
        collisionGestures.forEach { arView.removeGestureRecognizer($0) }
        collisionGestures.removeAll()
    }
    
    private func belongsToMovableGroup(_ entity: Entity) -> Bool {
        var current: Entity? = entity
        while let node = current {
            let name = node.name.lowercased()
            if name.contains("chair") || name.contains("table") || name.contains("storage") {
                return true
            }
            current = node.parent
        }
        return false
    }

    private func setDockButtonSelection(_ button: UIButton?, isSelected: Bool) {
        guard let button else { return }
        button.backgroundColor = isSelected ? UIColor.white.withAlphaComponent(0.2) : .clear
        var config = button.configuration
        config?.baseForegroundColor = isSelected ? .systemYellow : .white
        button.configuration = config
    }

    @objc private func rulerTapped() {
        isRulerVisible ? hideRoomRuler() : showRoomRuler()
        updateDockButtonStates()
    }

    private func showRoomRuler() {
        guard let model = displayedModel else { return }
        hideRoomRuler()
        
        let boundingBox = BoundingBoxEntity.forRoom(entity: model)
        boundingBox.position = model.position(relativeTo: nil)

        if let anchor = arView.scene.anchors.first {
            anchor.addChild(boundingBox)
        } else {
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(boundingBox)
            arView.scene.addAnchor(anchor)
        }

        roomBoundingBox = boundingBox
        isRulerVisible = true
    }

    private func hideRoomRuler() {
        roomBoundingBox?.removeFromParent()
        roomBoundingBox = nil
        isRulerVisible = false
    }

    @objc private func toggleLabelsTapped() {
        showLabels.toggle()
        labels.values.forEach { $0.isEnabled = showLabels }
        refreshFloatingMenu()
        updateDockButtonStates()
    }

    @objc private func textureDockTapped() {
        let picker = TexturePickerViewController()
        picker.currentTextureNames = [
            .floor: RoomColorManager.shared.getTextureName(for: RoomColorManager.floorTextureKey, roomURL: roomURL) ?? "",
            .wall: RoomColorManager.shared.getTextureName(for: RoomColorManager.wallTextureKey, roomURL: roomURL) ?? "",
            .door: RoomColorManager.shared.getTextureName(for: RoomColorManager.doorTextureKey, roomURL: roomURL) ?? "",
            .window: RoomColorManager.shared.getTextureName(for: RoomColorManager.windowTextureKey, roomURL: roomURL) ?? "",
            .table: RoomColorManager.shared.getTextureName(for: RoomColorManager.tableTextureKey, roomURL: roomURL) ?? "",
            .chair: RoomColorManager.shared.getTextureName(for: RoomColorManager.chairTextureKey, roomURL: roomURL) ?? "",
            .storage: RoomColorManager.shared.getTextureName(for: RoomColorManager.storageTextureKey, roomURL: roomURL) ?? ""
        ]
        picker.delegate = self
        if let sheet = picker.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(picker, animated: true)
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
            style: .prominent,
            target: self,
            action: #selector(saveAndGoBack)
        )
        saveButton.tintColor = .systemGreen
        
        // Only Save button in Edit mode (no add furniture button)
        navigationItem.rightBarButtonItems = [saveButton]
    }
    
    @objc private func saveAndGoBack() {
        RoomColorManager.shared.saveHiddenEntityPrefixes(hiddenEntityPrefixes, roomURL: roomURL)
        RoomColorManager.shared.saveForceWhiteSurfacePrefixes(forceWhiteSurfacePrefixes, roomURL: roomURL)
        RoomColorManager.shared.saveEnableColorsEnabled(enableColors, roomURL: roomURL)
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
        showLoadingOverlay()
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let entity = try await Entity(contentsOf: self.roomURL)
                await MainActor.run {
                    self.prepareModel(entity)
                    self.hideLoadingOverlay()
                }
            } catch {
                await MainActor.run {
                    self.hideLoadingOverlay()
                    print("❌ Failed to load room model: \(error.localizedDescription)")
                }
            }
        }
    }

    private func prepareModel(_ entity: Entity) {
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

        displayedModel = model
        hasGeneratedBaseCollisionShapes = false

        fitToScreen(model)

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(model)
        arView.scene.addAnchor(anchor)

        if isParametricModel {
            applyMaterialRules(to: model)
        }
        applyEntityVisibilityRules()
        
        if collisionsEnabled {
            enableCollisionFeatures()
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
        if collisionsEnabled {
            let first = g.location(ofTouch: 0, in: arView)
            let second = g.numberOfTouches > 1 ? g.location(ofTouch: 1, in: arView) : first
            let midpoint = CGPoint(x: (first.x + second.x) * 0.5, y: (first.y + second.y) * 0.5)
            
            // If pinch started over an entity, let collision gesture scaling handle it.
            if arView.entity(at: midpoint) != nil {
                return
            }
        }
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

    // MARK: - Texture Materials

    private func textureIsActive(key: String) -> Bool {
        guard let name = RoomColorManager.shared.getTextureName(for: key, roomURL: roomURL) else {
            return false
        }
        return RoomColorManager.shared.textureResource(named: name) != nil
    }

    private func makeTexturedMaterial(textureKey: String, fallbackColor: UIColor, roughness: Float) -> RealityKit.Material {
        let savedName = RoomColorManager.shared.getTextureName(for: textureKey, roomURL: roomURL)
        guard let textureName = savedName, !textureName.isEmpty else {
            return SimpleMaterial(color: fallbackColor, roughness: .float(roughness), isMetallic: false)
        }

        guard let textureResource = RoomColorManager.shared.textureResource(named: textureName) else {
            return SimpleMaterial(color: fallbackColor, roughness: .float(roughness), isMetallic: false)
        }

        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(texture: .init(textureResource))
        mat.roughness = .init(floatLiteral: roughness)
        mat.metallic = .init(floatLiteral: 0.0)
        return mat
    }

    private func makeFloorMaterial() -> RealityKit.Material {
        makeTexturedMaterial(
            textureKey: RoomColorManager.floorTextureKey,
            fallbackColor: .init(white: 0.76, alpha: 1),
            roughness: 0.85
        )
    }

    private func makeWallMaterial() -> RealityKit.Material {
        makeTexturedMaterial(
            textureKey: RoomColorManager.wallTextureKey,
            fallbackColor: .init(white: 0.92, alpha: 1),
            roughness: 0.75
        )
    }

    private func makeDoorMaterial() -> RealityKit.Material {
        makeTexturedMaterial(
            textureKey: RoomColorManager.doorTextureKey,
            fallbackColor: .systemCyan.withAlphaComponent(0.3),
            roughness: 0.4
        )
    }

    private func makeWindowMaterial() -> RealityKit.Material {
        makeTexturedMaterial(
            textureKey: RoomColorManager.windowTextureKey,
            fallbackColor: .lightGray.withAlphaComponent(0.3),
            roughness: 0.4
        )
    }

    private func makeTableMaterial() -> RealityKit.Material {
        makeTexturedMaterial(
            textureKey: RoomColorManager.tableTextureKey,
            fallbackColor: .systemRed,
            roughness: 0.4
        )
    }

    private func makeChairMaterial() -> RealityKit.Material {
        makeTexturedMaterial(
            textureKey: RoomColorManager.chairTextureKey,
            fallbackColor: .black,
            roughness: 0.4
        )
    }

    private func makeStorageMaterial() -> RealityKit.Material {
        makeTexturedMaterial(
            textureKey: RoomColorManager.storageTextureKey,
            fallbackColor: .systemOrange,
            roughness: 0.4
        )
    }

    // MARK: - Materials & Labels
    private func applyMaterialRules(to root: Entity) {
        let savedColors = RoomColorManager.shared.getAllColors(for: roomURL)
        let floorTextureActive = textureIsActive(key: RoomColorManager.floorTextureKey)
        let wallTextureActive = textureIsActive(key: RoomColorManager.wallTextureKey)
        let doorTextureActive = textureIsActive(key: RoomColorManager.doorTextureKey)
        let windowTextureActive = textureIsActive(key: RoomColorManager.windowTextureKey)
        let tableTextureActive = textureIsActive(key: RoomColorManager.tableTextureKey)
        let chairTextureActive = textureIsActive(key: RoomColorManager.chairTextureKey)
        let storageTextureActive = textureIsActive(key: RoomColorManager.storageTextureKey)
        
        func semanticPrefix(for entity: Entity) -> String? {
            let prefixes = ["wall", "floor", "door", "window", "table", "chair", "storage"]
            var current: Entity? = entity
            while let node = current {
                let lower = node.name.lowercased()
                if let matched = prefixes.first(where: { lower.contains($0) }) {
                    return matched
                }
                current = node.parent
            }
            return nil
        }

        root.visit {
            guard let model = $0 as? ModelEntity else { return }

            if originalMaterials[model] == nil {
                originalMaterials[model] = model.model?.materials
            }

            let name = model.name.lowercased()
            let semantic = semanticPrefix(for: model)

            if let yOffset = labelYOffset(for: name) {
                attachLabel(to: model, text: name, yOffset: yOffset)
            }

            if let semantic, forceWhiteSurfacePrefixes.contains(semantic) {
                model.model?.materials = [SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)]
                return
            }

            // 🔴 Enable Colors OFF → saved colours or textures
            guard enableColors else {
                if semantic == "wall" {
                    if wallTextureActive {
                        model.model?.materials = [makeWallMaterial()]
                    } else if let color = savedColors[RoomColorManager.wallKey] {
                        model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                    } else {
                        model.model?.materials = [SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)]
                    }
                } else if semantic == "floor" {
                    if floorTextureActive {
                        model.model?.materials = [makeFloorMaterial()]
                    } else if let color = savedColors[RoomColorManager.floorKey] {
                        model.model?.materials = [SimpleMaterial(color: color, roughness: 0.6, isMetallic: false)]
                    } else {
                        model.model?.materials = [SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)]
                    }
                } else if semantic == "door" {
                    if doorTextureActive {
                        model.model?.materials = [makeDoorMaterial()]
                    } else if let color = savedColors[RoomColorManager.doorKey] {
                        model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                    } else {
                        model.model?.materials = [SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)]
                    }
                } else if semantic == "window" {
                    if windowTextureActive {
                        model.model?.materials = [makeWindowMaterial()]
                    } else if let color = savedColors[RoomColorManager.windowKey] {
                        model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                    } else {
                        model.model?.materials = [SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)]
                    }
                } else if semantic == "table" {
                    if tableTextureActive {
                        model.model?.materials = [makeTableMaterial()]
                    } else if let color = savedColors[RoomColorManager.tableKey] {
                        model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                    } else {
                        model.model?.materials = [SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)]
                    }
                } else if semantic == "chair" {
                    if chairTextureActive {
                        model.model?.materials = [makeChairMaterial()]
                    } else if let color = savedColors[RoomColorManager.chairKey] {
                        model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                    } else {
                        model.model?.materials = [SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)]
                    }
                } else if semantic == "storage" {
                    if storageTextureActive {
                        model.model?.materials = [makeStorageMaterial()]
                    } else if let color = savedColors[RoomColorManager.storageKey] {
                        model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                    } else {
                        model.model?.materials = [SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)]
                    }
                } else {
                    model.model?.materials = [SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)]
                }
                return
            }

            // 🟢 Enable Colors ON → textures win, then saved colours, then semantic defaults
            switch true {
            case semantic == "wall":
                if wallTextureActive {
                    model.model?.materials = [makeWallMaterial()]
                } else {
                    let color = savedColors[RoomColorManager.wallKey] ?? .systemBlue
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                }

            case semantic == "floor":
                if floorTextureActive {
                    model.model?.materials = [makeFloorMaterial()]
                } else if let color = savedColors[RoomColorManager.floorKey] {
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.6, isMetallic: false)]
                } else {
                    model.model?.materials = [SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)]
                }

            case semantic == "chair":
                if chairTextureActive {
                    model.model?.materials = [makeChairMaterial()]
                } else {
                    let color = savedColors[RoomColorManager.chairKey] ?? .black
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                }

            case semantic == "table":
                if tableTextureActive {
                    model.model?.materials = [makeTableMaterial()]
                } else {
                    let color = savedColors[RoomColorManager.tableKey] ?? .systemRed
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                }

            case semantic == "door":
                if doorTextureActive {
                    model.model?.materials = [makeDoorMaterial()]
                } else {
                    let color = savedColors[RoomColorManager.doorKey] ?? .systemCyan.withAlphaComponent(0.3)
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                }

            case semantic == "window":
                if windowTextureActive {
                    model.model?.materials = [makeWindowMaterial()]
                } else {
                    let color = savedColors[RoomColorManager.windowKey] ?? .lightGray.withAlphaComponent(0.3)
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                }

            case semantic == "storage":
                if storageTextureActive {
                    model.model?.materials = [makeStorageMaterial()]
                } else {
                    let color = savedColors[RoomColorManager.storageKey] ?? .systemOrange
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                }

            default:
                // break
                // fallback → original materials
                if let original = originalMaterials[model] {
                    model.model?.materials = original
                }
            }
        }
    }
    
    private func labelYOffset(for name: String) -> Float? {
        switch true {
        case name.contains("wall"): return 1.5
        case name.contains("floor"): return 0.05
        case name.contains("chair"): return 0.15
        case name.contains("table"): return 0.5
        case name.contains("door"): return 0.8
        case name.contains("window"), name.contains("storage"): return 0.4
        default: return nil
        }
    }

    private func saveSemanticColorsAsCurrentTheme() {
        let semanticColors: [(String, UIColor)] = [
            (RoomColorManager.wallKey, .systemBlue),
            (RoomColorManager.floorKey, .gray),
            (RoomColorManager.doorKey, .systemCyan.withAlphaComponent(0.3)),
            (RoomColorManager.windowKey, .lightGray.withAlphaComponent(0.3)),
            (RoomColorManager.tableKey, .systemRed),
            (RoomColorManager.chairKey, .black),
            (RoomColorManager.storageKey, .systemOrange)
        ]

        semanticColors.forEach { key, color in
            RoomColorManager.shared.saveColor(color, for: key, roomURL: roomURL)
        }
    }
    
    private func resetRoomAppearanceToPlainWhite() {
        RoomColorManager.shared.clearColors(for: roomURL)
        guard let root = displayedModel else { return }
        
        root.visit {
            guard let model = $0 as? ModelEntity else { return }
            model.model?.materials = [
                SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)
            ]
        }
    }

    private func setColorForAllWalls(_ color: UIColor) {
        guard let root = displayedModel else { return }

        root.visit {
            guard let model = $0 as? ModelEntity else { return }
            let name = model.name.lowercased()

            if name.contains("wall") {
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
            .chairs: "chair",
            .floors: "floor",
            .windows: "window",
            .storage: "storage"
        ]

        guard let prefix = prefixes[target] else { return }

        // If a surface texture is active, bulk colour changes must not override it.
        // The user must tap a specific entity directly to explicitly override with colour.
        func textureActive(key: String) -> Bool {
            textureIsActive(key: key)
        }
        if target == .floors && textureActive(key: RoomColorManager.floorTextureKey) { return }
        if target == .walls  && textureActive(key: RoomColorManager.wallTextureKey)  { return }
        if target == .doors  && textureActive(key: RoomColorManager.doorTextureKey)  { return }
        if target == .windows && textureActive(key: RoomColorManager.windowTextureKey) { return }
        if target == .tables && textureActive(key: RoomColorManager.tableTextureKey) { return }
        if target == .chairs && textureActive(key: RoomColorManager.chairTextureKey) { return }
        if target == .storage && textureActive(key: RoomColorManager.storageTextureKey) { return }

        // Bulk color edits should also clear any forced-white override for that target.
        forceWhiteSurfacePrefixes.remove(prefix)
        RoomColorManager.shared.saveForceWhiteSurfacePrefixes(forceWhiteSurfacePrefixes, roomURL: roomURL)

        root.visit {
            guard let model = $0 as? ModelEntity else { return }
            if model.name.lowercased().starts(with: prefix) {
                model.model?.materials = [
                    SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)
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
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        // Add native Cancel button (left side)
        let cancelButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelColorPicker)
        )
        picker.navigationItem.leftBarButtonItem = cancelButton

        // Add native Done button (right side)
        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .prominent,
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

    private func isDescendant(_ entity: Entity, of parent: Entity) -> Bool {
        var current = entity.parent
        while let node = current {
            if node == parent { return true }
            current = node.parent
        }
        return false
    }

    // MARK: - Selection
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        if let tappedEntity = arView.entity(at: location) {
            for furniture in placedFurniture where tappedEntity == furniture || isDescendant(tappedEntity, of: furniture) {
                showControls(for: furniture)
                return
            }
        }

        guard isParametricModel else { return }
        guard !collisionsEnabled else { return }
        if let root = displayedModel {
            ensureBaseCollisionShapesGenerated(for: root)
        }
        selectedModel = arView.entity(at: location) as? ModelEntity
        guard selectedModel != nil else { return }
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
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }

        // Add native Cancel button (left side)
        let cancelButton = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelColorPicker)
        )
        picker.navigationItem.leftBarButtonItem = cancelButton

        // Add native Done button (right side)
        let doneButton = UIBarButtonItem(
            title: "Done",
            style: .prominent,
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
            if let elementType = getElementType(from: selectedModel) {
                RoomColorManager.shared.saveColor(selectedColor, for: elementType, roomURL: roomURL)
                // Direct tap on a textured surface: clear the texture so colour wins going forward.
                if let textureKey = textureKey(forElementType: elementType) {
                    RoomColorManager.shared.saveTextureName(nil, for: textureKey, roomURL: roomURL)
                }
                forceWhiteSurfacePrefixes.remove(elementType)
                RoomColorManager.shared.saveForceWhiteSurfacePrefixes(forceWhiteSurfacePrefixes, roomURL: roomURL)
            }

        default:
            setColor(for: colorTarget, color: selectedColor)
            // Only persist the colour when no texture is guarding this surface type.
            func hasTexture(key: String) -> Bool {
                textureIsActive(key: key)
            }
            let blocked = (colorTarget == .floors && hasTexture(key: RoomColorManager.floorTextureKey))
                       || (colorTarget == .walls  && hasTexture(key: RoomColorManager.wallTextureKey))
                       || (colorTarget == .doors && hasTexture(key: RoomColorManager.doorTextureKey))
                       || (colorTarget == .windows && hasTexture(key: RoomColorManager.windowTextureKey))
                       || (colorTarget == .tables && hasTexture(key: RoomColorManager.tableTextureKey))
                       || (colorTarget == .chairs && hasTexture(key: RoomColorManager.chairTextureKey))
                       || (colorTarget == .storage && hasTexture(key: RoomColorManager.storageTextureKey))
            if !blocked, let elementType = colorTargetToElementType(colorTarget) {
                RoomColorManager.shared.saveColor(selectedColor, for: elementType, roomURL: roomURL)
                forceWhiteSurfacePrefixes.remove(elementType)
                RoomColorManager.shared.saveForceWhiteSurfacePrefixes(forceWhiteSurfacePrefixes, roomURL: roomURL)
            }
        }
    }
    
    private func getElementType(from entity: Entity?) -> String? {
        var current = entity
        while let node = current {
            if let type = getElementType(fromName: node.name.lowercased()) {
                return type
            }
            current = node.parent
        }
        return nil
    }

    private func getElementType(fromName name: String) -> String? {
        if name.contains("wall") { return RoomColorManager.wallKey }
        if name.contains("floor") { return RoomColorManager.floorKey }
        if name.contains("door") { return RoomColorManager.doorKey }
        if name.contains("window") { return RoomColorManager.windowKey }
        if name.contains("table") { return RoomColorManager.tableKey }
        if name.contains("chair") { return RoomColorManager.chairKey }
        if name.contains("storage") { return RoomColorManager.storageKey }
        return nil
    }
    
    private func colorTargetToElementType(_ target: ColorTarget) -> String? {
        switch target {
        case .walls: return RoomColorManager.wallKey
        case .floors: return RoomColorManager.floorKey
        case .doors: return RoomColorManager.doorKey
        case .windows: return RoomColorManager.windowKey
        case .tables: return RoomColorManager.tableKey
        case .chairs: return RoomColorManager.chairKey
        case .storage: return RoomColorManager.storageKey
        case .selected: return nil
        }
    }

    private func textureKey(forElementType elementType: String) -> String? {
        switch elementType {
        case RoomColorManager.wallKey: return RoomColorManager.wallTextureKey
        case RoomColorManager.floorKey: return RoomColorManager.floorTextureKey
        case RoomColorManager.doorKey: return RoomColorManager.doorTextureKey
        case RoomColorManager.windowKey: return RoomColorManager.windowTextureKey
        case RoomColorManager.tableKey: return RoomColorManager.tableTextureKey
        case RoomColorManager.chairKey: return RoomColorManager.chairTextureKey
        case RoomColorManager.storageKey: return RoomColorManager.storageTextureKey
        default: return nil
        }
    }
}

// MARK: - TexturePickerDelegate
extension RoomEditVC: TexturePickerDelegate {
    private func semanticPrefix(for entity: Entity) -> String? {
        let prefixes = ["wall", "floor", "door", "window", "table", "chair", "storage"]
        var current: Entity? = entity
        while let node = current {
            let lower = node.name.lowercased()
            if let matched = prefixes.first(where: { lower.contains($0) }) {
                return matched
            }
            current = node.parent
        }
        return nil
    }

    private func applyDefaultWhiteForSurface(_ surface: TextureSurface) {
        guard let root = displayedModel else { return }

        let targetPrefix: String
        switch surface {
        case .floor: targetPrefix = "floor"
        case .wall: targetPrefix = "wall"
        case .door: targetPrefix = "door"
        case .window: targetPrefix = "window"
        case .table: targetPrefix = "table"
        case .chair: targetPrefix = "chair"
        case .storage: targetPrefix = "storage"
        }

        root.visit { entity in
            guard let model = entity as? ModelEntity else { return }
            guard semanticPrefix(for: model) == targetPrefix else { return }
            model.model?.materials = [
                SimpleMaterial(color: .white, roughness: 0.8, isMetallic: false)
            ]
        }
    }

    func texturePicker(_ picker: TexturePickerViewController,
                       didSelect option: TextureOption,
                       for surface: TextureSurface) {
        let nameToSave: String? = RoomColorManager.shared.normalizedTextureName(option.name)
        let targetPrefix: String
        let key: String
        switch surface {
        case .floor:
            key = RoomColorManager.floorTextureKey
            targetPrefix = RoomColorManager.floorKey
        case .wall:
            key = RoomColorManager.wallTextureKey
            targetPrefix = RoomColorManager.wallKey
        case .door:
            key = RoomColorManager.doorTextureKey
            targetPrefix = RoomColorManager.doorKey
        case .window:
            key = RoomColorManager.windowTextureKey
            targetPrefix = RoomColorManager.windowKey
        case .table:
            key = RoomColorManager.tableTextureKey
            targetPrefix = RoomColorManager.tableKey
        case .chair:
            key = RoomColorManager.chairTextureKey
            targetPrefix = RoomColorManager.chairKey
        case .storage:
            key = RoomColorManager.storageTextureKey
            targetPrefix = RoomColorManager.storageKey
        }

        // Explicit product rule:
        // Choosing "None" for a texture should reset that surface to default white.
        if nameToSave == nil {
            RoomColorManager.shared.clearTexture(for: key, roomURL: roomURL)
            forceWhiteSurfacePrefixes.insert(targetPrefix)
            let colorKey: String
            switch surface {
            case .floor: colorKey = RoomColorManager.floorKey
            case .wall: colorKey = RoomColorManager.wallKey
            case .door: colorKey = RoomColorManager.doorKey
            case .window: colorKey = RoomColorManager.windowKey
            case .table: colorKey = RoomColorManager.tableKey
            case .chair: colorKey = RoomColorManager.chairKey
            case .storage: colorKey = RoomColorManager.storageKey
            }
            RoomColorManager.shared.saveColor(.white, for: colorKey, roomURL: roomURL)
            applyDefaultWhiteForSurface(surface)
        } else {
            RoomColorManager.shared.saveTextureName(nameToSave, for: key, roomURL: roomURL)
            forceWhiteSurfacePrefixes.remove(targetPrefix)
        }
        RoomColorManager.shared.saveForceWhiteSurfacePrefixes(forceWhiteSurfacePrefixes, roomURL: roomURL)

        if let root = displayedModel {
            applyMaterialRules(to: root)
        }
    }
}
