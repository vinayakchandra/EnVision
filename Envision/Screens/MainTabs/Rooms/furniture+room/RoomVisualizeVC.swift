import UIKit
import RealityKit

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
        let rulerButton = UIBarButtonItem(
            image: UIImage(systemName: "ruler"),
            style: .plain,
            target: self,
            action: #selector(rulerTapped)
        )
        rulerButton.tintColor = .systemBlue
        
        let addButton = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(addFurnitureTapped)
        )
        addButton.tintColor = .systemGreen
        
        navigationItem.rightBarButtonItems = [addButton, rulerButton]
    }
    
    @objc private func rulerTapped() {
        isMeasuringMode.toggle()
        
        // Update button appearance
        if let rulerButton = navigationItem.rightBarButtonItems?.last {
            rulerButton.tintColor = isMeasuringMode ? .systemOrange : .systemBlue
            rulerButton.image = UIImage(systemName: isMeasuringMode ? "ruler.fill" : "ruler")
        }
        
        if isMeasuringMode {
            showMeasurementInstructions()
            setupMeasurementTapGesture()
        } else {
            clearMeasurement()
            removeMeasurementTapGesture()
        }
    }
    
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
        
        // Raycast to find 3D point
        guard let result = arView.entity(at: location) else { return }
        
        let worldPosition = result.position(relativeTo: nil)
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
        let distance = simd_distance(point1, point2)
        
        // Convert to real-world units (assuming model scale)
        let realDistance = distance / 0.005 // Adjust based on your model scale
        
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

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(clone)
        arView.scene.addAnchor(anchor)

        setupCamera()
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
}
