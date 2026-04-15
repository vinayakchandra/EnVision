import UIKit
import RealityKit
import QuickLook

final class RoomVisualizeVC: UIViewController {

    // MARK: - Inputs
    private let roomURL: URL

    // MARK: - State
    private var roomModel: ModelEntity?
    private var displayedModel: ModelEntity?
    private var placedFurniture: [ModelEntity] = []
    private var isMeasuringMode = false
    private var measurementPoints: [SIMD3<Float>] = []
    private var measurementLabel: UILabel?
    private var measurementLine: ModelEntity?
    private var previewURL: URL?
    
    // MARK: - Measurement State
    private let measurementManager = MeasurementManager.shared
    private let proximitySystem = ProximityMeasurementSystem.shared
    private let scaleManager = RealWorldScaleManager.shared
    private var activeBoundingBoxes: [BoundingBoxEntity] = []
    private var selectedFurnitureForMeasurement: ModelEntity?
    private var measurementModeType: MeasurementModeType = .pointToPoint
    
    // Proximity measurement - persistent & dynamic
    private var proximityUpdateTimer: Timer?
    private var isProximityModeActive = false
    private var trackedFurnitureForProximity: [ModelEntity] = []
    
    private enum MeasurementModeType {
        case pointToPoint    // Original: tap two points
        case furniture       // Show furniture dimensions
        case room           // Show room dimensions
        case proximity      // Auto-show distances to walls/objects
    }

    // MARK: - Camera
    private let cameraAnchor = AnchorEntity()
    private let orbitCamera = PerspectiveCamera()
    private var cameraPitch: Float = .pi / 6
    private var cameraYaw: Float = .pi / 4
    private var cameraDistance: Float = 1.5

    // MARK: - Views
    private let arView: ARView = {
        let view = ARView(frame: .zero)
        view.cameraMode = .nonAR
        view.environment.background = .color(.systemGray6)
        return view
    }()

    private var controlPanel: FurnitureControlPanel?
    private var furnitureSelectionTapGesture: UITapGestureRecognizer?
    private var loadingOverlay: UIVisualEffectView?
    private var loadingIndicator: UIActivityIndicatorView?
    private var loadingLabel: UILabel?
    private var rightDockContainer: UIView?
    private var measureDockButton: UIButton?
    
    private var measurementTextColor: UIColor {
        traitCollection.userInterfaceStyle == .dark ? .white : .black
    }

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
        title = "Visualize"
        navigationController?.navigationBar.prefersLargeTitles = true

        setupLayout()
        setupLoadingOverlay()
        setupNavigation()
        setupGestures()
        RoomColorManager.shared.ensureBundledTexturesAvailable()
        loadRoom()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopProximityUpdatesOnLifecycleExit()
    }

    deinit {
        stopProximityUpdatesOnLifecycleExit()
    }

    // MARK: - Layout
    private func setupLayout() {
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)

        NSLayoutConstraint.activate([
                                        arView.topAnchor.constraint(equalTo: view.topAnchor),
                                        arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                                        arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                        arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                                    ])
    }

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

    // MARK: - Navigation
    private func setupNavigation() {
        let addButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addFurnitureTapped)
        )
        addButton.tintColor = .systemGreen
        navigationItem.rightBarButtonItem = addButton
        setupRightDock()
    }

    private func setupRightDock() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.black.withAlphaComponent(0.68)
        container.layer.cornerRadius = 24
        container.layer.cornerCurve = .continuous
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.22
        container.layer.shadowRadius = 10
        container.layer.shadowOffset = CGSize(width: 0, height: 4)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 8
        container.addSubview(stack)

        let arButton = makeDockButton(systemImage: "arkit", action: #selector(viewInARTapped))
        let exportButton = makeDockButton(systemImage: "square.and.arrow.up", action: #selector(shareTapped))
        let measureButton = makeDockButton(systemImage: "ruler", action: #selector(rulerTapped))
        measureDockButton = measureButton

        [arButton, exportButton, measureButton].forEach { stack.addArrangedSubview($0) }

        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 112),
            container.widthAnchor.constraint(equalToConstant: 56),

            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])

        rightDockContainer = container
    }

    private func makeDockButton(systemImage: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemImage), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = 16
        button.layer.cornerCurve = .continuous
        button.addTarget(self, action: action, for: .touchUpInside)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 40),
        ])
        return button
    }
    
    // MARK: - Share Action
    @objc private func shareTapped() {
        presentShareOptions()
    }
    
    private func presentShareOptions() {
        let alert = UIAlertController(title: "Export Room", message: "Choose export format", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "📷 Image (PNG)", style: .default) { [weak self] _ in
            self?.exportAsImage()
        })
        
        alert.addAction(UIAlertAction(title: "📦 3D Model (USDZ)", style: .default) { [weak self] _ in
            self?.exportAsUSDZ()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popover = alert.popoverPresentationController {
            anchorDockPopover(popover)
        }
        
        present(alert, animated: true)
    }
    
    private func exportAsImage() {
        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let self = self, let image = image else {
                self?.showExportError("Failed to capture image")
                return
            }
            
            DispatchQueue.main.async {
                let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    self.anchorDockPopover(popover)
                }
                self.present(activityVC, animated: true)
            }
        }
    }
    
    private func exportAsUSDZ() {
        guard let model = displayedModel else {
            showExportError("No room model to export")
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = roomURL.deletingPathExtension().lastPathComponent
        let exportURL = tempDir.appendingPathComponent("\(fileName)_export.usdz")
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: exportURL)
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: nil, message: "Exporting...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        Task {
            do {
                if #available(iOS 15.0, *) {
                    try await model.exportAsUSDZAsync(to: exportURL)
                } else {
                    try model.exportAsUSDZ(to: exportURL)
                }
                
                await MainActor.run {
                    loadingAlert.dismiss(animated: true) { [weak self] in
                        guard let self = self else { return }
                        let activityVC = UIActivityViewController(activityItems: [exportURL], applicationActivities: nil)
                        if let popover = activityVC.popoverPresentationController {
                            self.anchorDockPopover(popover)
                        }
                        self.present(activityVC, animated: true)
                    }
                }
            } catch {
                await MainActor.run {
                    loadingAlert.dismiss(animated: true) { [weak self] in
                        self?.showExportError("Export failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    private func showExportError(_ message: String) {
        let alert = UIAlertController(title: "Export Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func rulerTapped() {
        if isMeasuringMode {
            // Turn off measurement mode
            exitMeasurementMode()
        } else {
            // Show measurement options
            showMeasurementOptions()
        }
    }
    
    private func showMeasurementOptions() {
        let alert = UIAlertController(title: "Measurement Mode", message: "Choose what to measure", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Room Dimensions", style: .default) { [weak self] _ in
            self?.enterMeasurementMode(type: .room)
        })
        
        if !placedFurniture.isEmpty {
            alert.addAction(UIAlertAction(title: "Furniture Dimensions", style: .default) { [weak self] _ in
                self?.enterMeasurementMode(type: .furniture)
            })
            
            alert.addAction(UIAlertAction(title: "Furniture Proximity (Auto)", style: .default) { [weak self] _ in
                self?.enterMeasurementMode(type: .proximity)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popover = alert.popoverPresentationController {
            anchorDockPopover(popover)
        }
        
        present(alert, animated: true)
    }
    
    private func enterMeasurementMode(type: MeasurementModeType) {
        isMeasuringMode = true
        measurementModeType = type
        measurementManager.enable()
        
        // Update button appearance
        updateRulerButtonAppearance(active: true)
        
        switch type {
        case .pointToPoint:
            showMeasurementInstructions()
            setupMeasurementTapGesture()
            
        case .room:
            showRoomMeasurements()
            
        case .furniture:
            showFurnitureMeasurementInstructions()
            setupFurnitureTapGesture()
            
        case .proximity:
            showProximityMeasurements()
        }
    }
    
    private func exitMeasurementMode() {
        isMeasuringMode = false
        measurementManager.disable()
        
        // Stop proximity updates
        stopProximityUpdates()
        isProximityModeActive = false
        trackedFurnitureForProximity.removeAll()
        
        // Update button appearance
        updateRulerButtonAppearance(active: false)
        
        // Clear all measurements
        clearMeasurement()
        clearBoundingBoxes()
        proximitySystem.clearIndicators()
        removeMeasurementTapGesture()
        removeFurnitureTapGesture()
        removeProximityTapGesture()
    }
    
    // MARK: - Proximity Update Timer
    
    private func startProximityUpdates() {
        stopProximityUpdates() // Stop any existing timer
        
        // Update every 0.033 seconds (30fps) for smooth real-time tracking
        proximityUpdateTimer = Timer.scheduledTimer(withTimeInterval: 0.0333333, repeats: true) { [weak self] _ in
            self?.updateProximityMeasurements()
        }
    }
    
    private func stopProximityUpdates() {
        proximityUpdateTimer?.invalidate()
        proximityUpdateTimer = nil
    }

    private func stopProximityUpdatesOnLifecycleExit() {
        stopProximityUpdates()
        isProximityModeActive = false
        trackedFurnitureForProximity.removeAll()
        proximitySystem.clearIndicators()
    }
    
    private func updateProximityMeasurements() {
        guard isProximityModeActive, !trackedFurnitureForProximity.isEmpty else { return }
        
        // Use the batch update method that clears once and adds all
        proximitySystem.showProximityForAllFurniture(
            trackedFurnitureForProximity,
            roomModel: displayedModel,
            in: arView.scene
        )
    }
    
    private func updateRulerButtonAppearance(active: Bool) {
        measureDockButton?.tintColor = active ? .systemOrange : .white
        measureDockButton?.backgroundColor = active ? UIColor.systemOrange.withAlphaComponent(0.22) : UIColor.white.withAlphaComponent(0.12)
    }

    @objc private func viewInARTapped() {
        let url = roomURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            showExportError("Room file not found for AR preview.")
            return
        }

        previewURL = url
        let preview = QLPreviewController()
        preview.dataSource = self
        present(preview, animated: true)
    }

    private func anchorDockPopover(_ popover: UIPopoverPresentationController) {
        if let dock = rightDockContainer {
            popover.sourceView = dock
            popover.sourceRect = dock.bounds
            popover.permittedArrowDirections = [.right, .left, .up, .down]
        } else {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
    }
    
    // MARK: - Room Measurements
    private func showRoomMeasurements() {
        guard let model = displayedModel else { return }
        
        // Clear existing bounding boxes
        clearBoundingBoxes()
        
        // Create bounding box for the room
        let boundingBox = BoundingBoxEntity.forRoom(
            entity: model,
            unit: measurementManager.currentUnit
        )
        boundingBox.position = model.position(relativeTo: nil)
        
        if let anchor = arView.scene.anchors.first {
            anchor.addChild(boundingBox)
            activeBoundingBoxes.append(boundingBox)
        }
        
        // Show room dimensions toast
        showRoomDimensionsToast(for: model)
    }
    
    private func showRoomDimensionsToast(for model: Entity) {
        // Use RealWorldScaleManager for accurate real-world dimensions
        let realDimensions = scaleManager.originalRoomDimensions
        
        let toast = UILabel()
        toast.numberOfLines = 0
        toast.text = """
        Room Dimensions (Real-World)
        W: \(scaleManager.formatRealWorldDistance(realDimensions.x))
        H: \(scaleManager.formatRealWorldDistance(realDimensions.y))
        D: \(scaleManager.formatRealWorldDistance(realDimensions.z))
        """
        toast.font = .systemFont(ofSize: 14, weight: .medium)
        toast.textColor = measurementTextColor
        toast.backgroundColor = AppColors.accent.withAlphaComponent(0.95)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 12
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toast)
        measurementLabel = toast
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])
    }
    
    // MARK: - Furniture Measurements
    private func showFurnitureMeasurementInstructions() {
        let toast = UILabel()
        toast.text = "Tap a furniture item to see dimensions"
        toast.font = .systemFont(ofSize: 15, weight: .medium)
        toast.textColor = measurementTextColor
        toast.backgroundColor = AppColors.accent.withAlphaComponent(0.9)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 12
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toast)
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            toast.heightAnchor.constraint(equalToConstant: 40),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])
        
        UIView.animate(withDuration: 0.3, delay: 2.5) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
    
    private var furnitureTapGesture: UITapGestureRecognizer?
    
    private func setupFurnitureTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFurnitureTap(_:)))
        arView.addGestureRecognizer(tap)
        furnitureTapGesture = tap
    }
    
    private func removeFurnitureTapGesture() {
        if let gesture = furnitureTapGesture {
            arView.removeGestureRecognizer(gesture)
            furnitureTapGesture = nil
        }
    }
    
    @objc private func handleFurnitureTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        
        guard let tappedEntity = arView.entity(at: location) else { return }
        
        // Find if this entity is part of placed furniture
        for furniture in placedFurniture {
            if tappedEntity == furniture || isDescendant(tappedEntity, of: furniture) {
                showFurnitureMeasurement(for: furniture)
                return
            }
        }
    }
    
    private func isDescendant(_ entity: Entity, of parent: Entity) -> Bool {
        var current = entity.parent
        while let p = current {
            if p == parent { return true }
            current = p.parent
        }
        return false
    }
    
    private func showFurnitureMeasurement(for furniture: ModelEntity) {
        // Clear previous measurement
        clearBoundingBoxes()
        measurementLabel?.removeFromSuperview()
        
        selectedFurnitureForMeasurement = furniture
        
        // Create bounding box for furniture
        let boundingBox = BoundingBoxEntity.forFurniture(
            entity: furniture,
            unit: measurementManager.currentUnit
        )
        boundingBox.position = furniture.position(relativeTo: nil)
        
        if let anchor = arView.scene.anchors.first {
            anchor.addChild(boundingBox)
            activeBoundingBoxes.append(boundingBox)
        }
        
        // Show dimensions toast
        showFurnitureDimensionsToast(for: furniture)
        
        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func showFurnitureDimensionsToast(for furniture: Entity) {
        // Use RealWorldScaleManager for accurate real-world dimensions
        let realDimensions = furniture.realWorldDimensions
        
        let toast = UILabel()
        toast.numberOfLines = 0
        toast.text = """
        Furniture Dimensions (Real-World)
        W: \(scaleManager.formatRealWorldDistance(realDimensions.x))
        H: \(scaleManager.formatRealWorldDistance(realDimensions.y))
        D: \(scaleManager.formatRealWorldDistance(realDimensions.z))
        """
        toast.font = .systemFont(ofSize: 14, weight: .medium)
        toast.textColor = measurementTextColor
        toast.backgroundColor = AppColors.accent.withAlphaComponent(0.95)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 12
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toast)
        measurementLabel = toast
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])
    }
    
    // MARK: - Proximity Measurements (Auto-Distance)
    
    private var proximityTapGesture: UITapGestureRecognizer?
    
    private func showProximityMeasurements() {
        guard !placedFurniture.isEmpty else {
            showNoFurnitureAlert()
            exitMeasurementMode()
            return
        }
        
        // Enable proximity mode
        isProximityModeActive = true
        
        // Track all placed furniture for dynamic updates
        trackedFurnitureForProximity = placedFurniture
        
        // Show initial proximity measurements for all furniture
        showAllFurnitureProximity()
        
        // Start the update timer for dynamic tracking
        startProximityUpdates()
        
        // Setup tap gesture to select specific furniture
        setupProximityTapGesture()
    }
    
    private func showNoFurnitureAlert() {
        let alert = UIAlertController(
            title: "No Furniture",
            message: "Place some furniture first to measure distances",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showProximityInstructions() {
        let toast = UILabel()
        toast.text = "Tap furniture to see distances to walls & objects"
        toast.font = .systemFont(ofSize: 15, weight: .medium)
        toast.textColor = measurementTextColor
        toast.backgroundColor = AppColors.accent.withAlphaComponent(0.9)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 12
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toast)
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            toast.heightAnchor.constraint(equalToConstant: 40),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])
        
        UIView.animate(withDuration: 0.3, delay: 3.0) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
        
        // Also show all furniture proximity measurements immediately
        showAllFurnitureProximity()
    }
    
    private func setupProximityTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleProximityTap(_:)))
        arView.addGestureRecognizer(tap)
        proximityTapGesture = tap
    }
    
    private func removeProximityTapGesture() {
        if let gesture = proximityTapGesture {
            arView.removeGestureRecognizer(gesture)
            proximityTapGesture = nil
        }
    }
    
    @objc private func handleProximityTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        
        guard let tappedEntity = arView.entity(at: location) else { return }
        
        // Find if this entity is part of placed furniture
        for furniture in placedFurniture {
            if tappedEntity == furniture || isDescendant(tappedEntity, of: furniture) {
                showProximityForFurniture(furniture)
                return
            }
        }
    }
    
    private func showProximityForFurniture(_ furniture: ModelEntity) {
        // Clear previous indicators
        proximitySystem.clearIndicators()
        measurementLabel?.removeFromSuperview()
        
        // Get other furniture (excluding selected one)
        let otherFurniture = placedFurniture.filter { $0 !== furniture }
        
        // Show proximity measurements
        proximitySystem.showProximityForFurniture(
            furniture,
            roomModel: displayedModel,
            otherFurniture: otherFurniture,
            in: arView.scene
        )
        
        // Show info toast
        showProximityInfoToast(for: furniture)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func showAllFurnitureProximity() {
        proximitySystem.showProximityForAllFurniture(
            placedFurniture,
            roomModel: displayedModel,
            in: arView.scene
        )
    }
    
    private func showProximityInfoToast(for furniture: Entity) {
        measurementLabel?.removeFromSuperview()
        
        let toast = UILabel()
        toast.numberOfLines = 0
        toast.text = "📐 Distances update in real-time as you move furniture\nTap 📏 again to exit"
        toast.font = .systemFont(ofSize: 13, weight: .medium)
        toast.textColor = .white
        toast.backgroundColor = AppColors.accent.withAlphaComponent(0.95)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 12
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toast)
        measurementLabel = toast
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            toast.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])
    }
    
    // MARK: - Bounding Box Management
    private func clearBoundingBoxes() {
        for box in activeBoundingBoxes {
            box.remove()
        }
        activeBoundingBoxes.removeAll()
        selectedFurnitureForMeasurement = nil
    }
    
    // MARK: - Point-to-Point Measurement
    private func showMeasurementInstructions() {
        let toast = UILabel()
        toast.text = "Tap two points to measure distance"
        toast.font = .systemFont(ofSize: 15, weight: .medium)
        toast.textColor = .white
        toast.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.9)
        toast.textAlignment = .center
        toast.layer.cornerRadius = 12
        toast.clipsToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(toast)
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            toast.heightAnchor.constraint(equalToConstant: 40),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 250)
        ])
        
        UIView.animate(withDuration: 0.3, delay: 2.5) {
            toast.alpha = 0
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
    
    private var measurementTapGesture: UITapGestureRecognizer?
    
    private func setupMeasurementTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleMeasurementTap(_:)))
        arView.addGestureRecognizer(tap)
        measurementTapGesture = tap
    }
    
    private func removeMeasurementTapGesture() {
        if let gesture = measurementTapGesture {
            arView.removeGestureRecognizer(gesture)
            measurementTapGesture = nil
        }
    }
    
    @objc private func handleMeasurementTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)
        
        guard let worldPosition = resolveMeasurementWorldPosition(from: location) else { return }
        measurementPoints.append(worldPosition)
        
        // Add visual marker at tap point
        addMeasurementMarker(at: worldPosition)
        
        if measurementPoints.count == 2 {
            calculateAndDisplayDistance()
        } else if measurementPoints.count > 2 {
            // Reset and start new measurement
            clearMeasurement()
            measurementPoints.append(worldPosition)
            addMeasurementMarker(at: worldPosition)
        }
    }

    private func resolveMeasurementWorldPosition(from screenPoint: CGPoint) -> SIMD3<Float>? {
        // Preferred: collision raycast hit point on scene geometry.
        if let ray = arView.ray(through: screenPoint),
           let hit = arView.scene.raycast(origin: ray.origin, direction: ray.direction).first {
            return hit.position
        }

        // Fallback: entity origin if no collision hit is available.
        if let entity = arView.entity(at: screenPoint) {
            return entity.position(relativeTo: nil)
        }

        return nil
    }
    
    private func addMeasurementMarker(at position: SIMD3<Float>) {
        let sphere = MeshResource.generateSphere(radius: 0.02)
        let material = SimpleMaterial(color: .systemOrange, isMetallic: false)
        let marker = ModelEntity(mesh: sphere, materials: [material])
        marker.position = position
        marker.name = "measurementMarker"
        
        if let anchor = arView.scene.anchors.first {
            anchor.addChild(marker)
        }
    }
    
    private func calculateAndDisplayDistance() {
        guard measurementPoints.count >= 2 else { return }
        
        let point1 = measurementPoints[0]
        let point2 = measurementPoints[1]
        
        // Calculate distance
        let displayedDistance = simd_distance(point1, point2)
        
        // Convert using room scale manager for real-world meters.
        let realDistance = scaleManager.toRealWorldMeters(displayedDistance)
        
        // Create line between points
        drawMeasurementLine(from: point1, to: point2)
        
        // Display distance
        showDistanceLabel(distance: realDistance)
    }
    
    private func drawMeasurementLine(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        // Remove existing line
        measurementLine?.removeFromParent()
        
        let distance = simd_distance(start, end)
        let midPoint = (start + end) / 2
        
        let mesh = MeshResource.generateBox(size: [0.005, 0.005, distance])
        let material = SimpleMaterial(color: .systemOrange, isMetallic: false)
        let line = ModelEntity(mesh: mesh, materials: [material])
        
        line.position = midPoint
        line.look(at: end, from: midPoint, relativeTo: nil)
        line.name = "measurementLine"
        
        if let anchor = arView.scene.anchors.first {
            anchor.addChild(line)
        }
        measurementLine = line
    }
    
    private func showDistanceLabel(distance: Float) {
        measurementLabel?.removeFromSuperview()
        
        let label = UILabel()
        let distanceInMeters = distance
        let distanceInCm = distance * 100
        let distanceInFeet = distance * 3.28084
        
        if distanceInMeters >= 1 {
            label.text = String(format: "📏 %.2f m (%.1f ft)", distanceInMeters, distanceInFeet)
        } else {
            label.text = String(format: "📏 %.1f cm (%.1f in)", distanceInCm, distanceInCm / 2.54)
        }
        
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = measurementTextColor
        label.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.95)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        measurementLabel = label
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            label.heightAnchor.constraint(equalToConstant: 50),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }
    
    private func clearMeasurement() {
        measurementPoints.removeAll()
        measurementLabel?.removeFromSuperview()
        measurementLabel = nil
        measurementLine?.removeFromParent()
        measurementLine = nil
        
        // Remove all measurement markers
        arView.scene.anchors.first?.children.forEach { entity in
            if entity.name == "measurementMarker" || entity.name == "measurementLine" {
                entity.removeFromParent()
            }
        }
    }

    // MARK: - Gestures
    private func setupGestures() {
        arView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan)))
        arView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinch)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFurnitureSelectionTap(_:)))
        arView.addGestureRecognizer(tap)
        furnitureSelectionTapGesture = tap
    }

    @objc private func handleFurnitureSelectionTap(_ gesture: UITapGestureRecognizer) {
        guard !isMeasuringMode else { return }
        let location = gesture.location(in: arView)
        guard let tappedEntity = arView.entity(at: location) else { return }

        for furniture in placedFurniture where tappedEntity == furniture || isDescendant(tappedEntity, of: furniture) {
            showControls(for: furniture)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            return
        }
    }

    // MARK: - Loading
    private func loadRoom() {
        showLoadingOverlay()
        Task {
            do {
                let entity = try await Entity(contentsOf: roomURL)
                await MainActor.run {
                    setupScene(with: entity)
                    hideLoadingOverlay()
                }
            } catch {
                await MainActor.run {
                    hideLoadingOverlay()
                    print("Failed to load room: \(error)")
                }
            }
        }
    }

    private func setupScene(with entity: Entity) {
        arView.scene.anchors.removeAll()

        let model: ModelEntity = {
            if let m = entity as? ModelEntity { return m }
            let wrapper = ModelEntity()
            wrapper.addChild(entity)
            return wrapper
        }()

        roomModel = model
        let clone = model.clone(recursive: true)
        displayedModel = clone

        fitToScreen(clone)

        // Set camera distance based on the model's actual displayed size so it
        // fills the view properly on both iPhone and iPad.
        let displayedBounds = clone.visualBounds(relativeTo: nil)
        let maxDisplayedDim = max(displayedBounds.extents.x, displayedBounds.extents.y, displayedBounds.extents.z)
        cameraDistance = max(0.8, maxDisplayedDim * 2.2)

        // Apply saved colors from RoomColorManager
        applySavedColors(to: clone)
        applyHiddenEntityVisibility(to: clone)

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(clone)
        arView.scene.addAnchor(anchor)

        setupCamera()
    }
    
    private func applySavedColors(to root: ModelEntity) {
        let savedColors = RoomColorManager.shared.getAllColors(for: roomURL)
        let forceWhiteSurfacePrefixes = RoomColorManager.shared.getForceWhiteSurfacePrefixes(for: roomURL)
        
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

        func pbr(textureKey: String, roughness: Float) -> RealityKit.Material? {
            guard let name = RoomColorManager.shared.getTextureName(for: textureKey, roomURL: roomURL) else {
                return nil
            }
            guard let texture = RoomColorManager.shared.textureResource(named: name) else {
                return nil
            }
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(texture: .init(texture))
            mat.roughness = .init(floatLiteral: roughness)
            mat.metallic = .init(floatLiteral: 0.0)
            return mat
        }

        func resolvedMaterial(
            textureKey: String,
            colorKey: String,
            defaultColor: UIColor,
            roughness: Float
        ) -> Material {
            if let textured = pbr(textureKey: textureKey, roughness: roughness) {
                return textured
            }

            let color = savedColors[colorKey] ?? defaultColor
            return SimpleMaterial(color: color, roughness: .float(roughness), isMetallic: false)
        }

        root.visit { entity in
            guard let model = entity as? ModelEntity else { return }
            let semantic = semanticPrefix(for: model)
            
            if let semantic, forceWhiteSurfacePrefixes.contains(semantic) {
                model.model?.materials = [SimpleMaterial(color: .white, roughness: .float(0.8), isMetallic: false)]
                return
            }

            if semantic == "wall" {
                model.model?.materials = [resolvedMaterial(
                    textureKey: RoomColorManager.wallTextureKey,
                    colorKey: RoomColorManager.wallKey,
                    defaultColor: .white,
                    roughness: 0.75
                )]
            } else if semantic == "floor" {
                model.model?.materials = [resolvedMaterial(
                    textureKey: RoomColorManager.floorTextureKey,
                    colorKey: RoomColorManager.floorKey,
                    defaultColor: .white,
                    roughness: 0.85
                )]
            } else if semantic == "door" {
                model.model?.materials = [resolvedMaterial(
                    textureKey: RoomColorManager.doorTextureKey,
                    colorKey: RoomColorManager.doorKey,
                    defaultColor: .white,
                    roughness: 0.4
                )]
            } else if semantic == "window" {
                model.model?.materials = [resolvedMaterial(
                    textureKey: RoomColorManager.windowTextureKey,
                    colorKey: RoomColorManager.windowKey,
                    defaultColor: .white,
                    roughness: 0.4
                )]
            } else if semantic == "table" {
                model.model?.materials = [resolvedMaterial(
                    textureKey: RoomColorManager.tableTextureKey,
                    colorKey: RoomColorManager.tableKey,
                    defaultColor: .white,
                    roughness: 0.4
                )]
            } else if semantic == "chair" {
                model.model?.materials = [resolvedMaterial(
                    textureKey: RoomColorManager.chairTextureKey,
                    colorKey: RoomColorManager.chairKey,
                    defaultColor: .white,
                    roughness: 0.4
                )]
            } else if semantic == "storage" {
                model.model?.materials = [resolvedMaterial(
                    textureKey: RoomColorManager.storageTextureKey,
                    colorKey: RoomColorManager.storageKey,
                    defaultColor: .white,
                    roughness: 0.4
                )]
            }
        }
    }

    private func fitToScreen(_ model: ModelEntity) {
        // Use RealWorldScaleManager to properly track the scale
        let scaleFactor = scaleManager.setupRoomScale(for: model)
        model.scale = .init(repeating: scaleFactor)
    }

    private func applyHiddenEntityVisibility(to root: ModelEntity) {
        let hiddenPrefixes = RoomColorManager.shared.getHiddenEntityPrefixes(for: roomURL)
        guard !hiddenPrefixes.isEmpty else { return }

        root.visit { entity in
            guard let model = entity as? ModelEntity else { return }
            let name = model.name.lowercased()
            let prefixes = ["wall", "floor", "door", "window", "table", "chair", "storage"]
            guard let matched = prefixes.first(where: { name.starts(with: $0) }) else { return }
            model.isEnabled = !hiddenPrefixes.contains(matched)
        }
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

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let t = g.translation(in: arView)
        cameraYaw += Float(t.x) * 0.005
        cameraPitch = max(-1.4, min(1.4, cameraPitch + Float(t.y) * 0.005))
        g.setTranslation(.zero, in: arView)
        updateCamera()
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        cameraDistance = max(0.3, min(8, cameraDistance / Float(g.scale)))
        g.scale = 1
        updateCamera()
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
            
            // Use RealWorldScaleManager to calculate proper scale
            // This ensures furniture appears at realistic size relative to the room
            let furnitureScale = scaleManager.calculateFurnitureScale(for: model)
            model.scale = furnitureScale
            
            model.generateCollisionShapes(recursive: true)

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(model)
            arView.scene.addAnchor(anchor)

            placedFurniture.append(model)
            
            // If proximity mode is active, add this furniture to tracking
            if isProximityModeActive {
                trackedFurnitureForProximity.append(model)
            }
            
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
}

extension RoomVisualizeVC: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { previewURL == nil ? 0 : 1 }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        previewURL! as QLPreviewItem
    }
}
