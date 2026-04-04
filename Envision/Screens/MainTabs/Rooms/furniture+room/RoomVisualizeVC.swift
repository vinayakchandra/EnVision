import UIKit
import RealityKit

final class RoomVisualizeVC: UIViewController {

    // MARK: - Inputs
    private let roomURL: URL

    // MARK: - State
    private var roomModel: ModelEntity?
    private var displayedModel: ModelEntity?
    private var placedFurniture: [ModelEntity] = []
    private var selectedFurniture: ModelEntity?
    private var isMeasuringMode = false
    private var measurementPoints: [SIMD3<Float>] = []
    private var measurementLabel: UILabel?
    private var measurementLine: ModelEntity?
    
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
    private var furnitureSelectionTapGesture: UITapGestureRecognizer?
    
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
        // Grey-blueish background for better button visibility
        view.environment.background = .color(UIColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 1.0))
        return view
    }()

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
        title = "Visualize"
        navigationController?.navigationBar.prefersLargeTitles = true

        setupLayout()
        setupNavigation()
        setupGestures()
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

    // MARK: - Navigation
    private func setupNavigation() {
        // Ruler button (leftmost) - for measurements
        let rulerButton = UIBarButtonItem(
            image: UIImage(systemName: "ruler"),
            style: .plain,
            target: self,
            action: #selector(rulerTapped)
        )
        rulerButton.tintColor = .systemBlue
        
        // Share button (middle) - for export
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareTapped)
        )
        shareButton.tintColor = .systemBlue
        
        // Add furniture button (rightmost)
        let addButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addFurnitureTapped)
        )
        addButton.tintColor = .systemGreen
        
        // Order: rightmost first in array
        navigationItem.rightBarButtonItems = [addButton, shareButton, rulerButton]
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
            popover.barButtonItem = navigationItem.rightBarButtonItems?[1]
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
                    popover.barButtonItem = self.navigationItem.rightBarButtonItems?[1]
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
                            popover.barButtonItem = self.navigationItem.rightBarButtonItems?[1]
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
            
            // NEW: Proximity measurement option
            alert.addAction(UIAlertAction(title: "Furniture Proximity (Auto)", style: .default) { [weak self] _ in
                self?.enterMeasurementMode(type: .proximity)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad support
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
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
        if let rulerButton = navigationItem.rightBarButtonItems?.last {
            rulerButton.tintColor = active ? .systemOrange : .systemBlue
            rulerButton.image = UIImage(systemName: active ? "ruler.fill" : "ruler")
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
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 180)
        ])
    }
    
    // MARK: - Furniture Measurements
    private func showFurnitureMeasurementInstructions() {
        let toast = UILabel()
        toast.text = "Tap a furniture item to see dimensions"
        toast.font = .systemFont(ofSize: 15, weight: .medium)
        toast.textColor = .white
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
        toast.textColor = .white
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
        label.textColor = .white
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
        setupFurnitureSelectionTapGesture()
    }

    private func setupFurnitureSelectionTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleFurnitureSelectionTap(_:)))
        tap.cancelsTouchesInView = false
        arView.addGestureRecognizer(tap)
        furnitureSelectionTapGesture = tap
    }

    @objc private func handleFurnitureSelectionTap(_ gesture: UITapGestureRecognizer) {
        guard !isMeasuringMode else { return }
        let location = gesture.location(in: arView)
        guard let furniture = resolveFurniture(at: location) else { return }
        selectFurniture(furniture, animated: true)
    }

    private func resolveFurniture(at location: CGPoint) -> ModelEntity? {
        // Preferred: direct hit-test to tapped entity.
        if let tappedEntity = arView.entity(at: location) {
            for furniture in placedFurniture where tappedEntity == furniture || isDescendant(tappedEntity, of: furniture) {
                return furniture
            }
        }

        // Fallback: choose nearest furniture in screen space.
        let nearest = placedFurniture.min { lhs, rhs in
            let lhs2D = arView.project(lhs.position(relativeTo: nil)) ?? .zero
            let rhs2D = arView.project(rhs.position(relativeTo: nil)) ?? .zero
            let lhsDist = hypot(lhs2D.x - location.x, lhs2D.y - location.y)
            let rhsDist = hypot(rhs2D.x - location.x, rhs2D.y - location.y)
            return lhsDist < rhsDist
        }

        return nearest
    }

    private func selectFurniture(_ model: ModelEntity, animated: Bool) {
        selectedFurniture = model
        showControls(for: model)
        guard animated else { return }
        animateSelectionFeedback(for: model)
    }

    private func animateSelectionFeedback(for model: ModelEntity) {
        let originalScale = model.scale
        model.scale = originalScale * SIMD3<Float>(repeating: 1.03)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            model.scale = originalScale
        }
    }

    // MARK: - Loading
    private func loadRoom() {
        Task {
            do {
                let entity = try await Entity(contentsOf: roomURL)
                await MainActor.run {
                    setupScene(with: entity)
                }
            } catch {
                print("Failed to load room: \(error)")
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
        
        // Apply saved colors from RoomColorManager
        applySavedColors(to: clone)

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(clone)
        arView.scene.addAnchor(anchor)

        setupCamera()
    }
    
    private func applySavedColors(to root: ModelEntity) {
        let savedColors      = RoomColorManager.shared.getAllColors(for: roomURL)
        let floorTextureName = RoomColorManager.shared.getTextureName(for: RoomColorManager.floorTextureKey, roomURL: roomURL)
        let wallTextureName  = RoomColorManager.shared.getTextureName(for: RoomColorManager.wallTextureKey,  roomURL: roomURL)

        func pbr(named assetName: String, roughness: Float) -> RealityKit.Material? {
            guard let texture = try? TextureResource.load(named: assetName) else { return nil }
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(texture: .init(texture))
            mat.roughness = .init(floatLiteral: roughness)
            mat.metallic  = .init(floatLiteral: 0.0)
            return mat
        }

        root.visit { entity in
            guard let model = entity as? ModelEntity else { return }
            let name = model.name.lowercased()

            if name.starts(with: "wall") {
                if let tex = wallTextureName, !tex.isEmpty, let mat = pbr(named: tex, roughness: 0.75) {
                    model.model?.materials = [mat]
                } else if let color = savedColors[RoomColorManager.wallKey] {
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.4, isMetallic: false)]
                }
            } else if name.starts(with: "floor") {
                if let tex = floorTextureName, !tex.isEmpty, let mat = pbr(named: tex, roughness: 0.85) {
                    model.model?.materials = [mat]
                } else if let color = savedColors[RoomColorManager.floorKey] {
                    model.model?.materials = [SimpleMaterial(color: color, roughness: 0.6, isMetallic: false)]
                }
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
            }
        }
    }

    private func fitToScreen(_ model: ModelEntity) {
        // Use RealWorldScaleManager to properly track the scale
        let scaleFactor = scaleManager.setupRoomScale(for: model)
        model.scale = .init(repeating: scaleFactor)
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
            await MainActor.run {
                let anchor = AnchorEntity(world: .zero)
                anchor.addChild(model)
                self.arView.scene.addAnchor(anchor)

                self.placedFurniture.append(model)
                
                // If proximity mode is active, add this furniture to tracking
                if self.isProximityModeActive {
                    self.trackedFurnitureForProximity.append(model)
                }
                
                self.selectFurniture(model, animated: false)
            }
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
