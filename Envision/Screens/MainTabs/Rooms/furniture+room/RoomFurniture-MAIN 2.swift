import UIKit
import RealityKit
import ARKit
import UniformTypeIdentifiers

class RoomFurniture1: UIViewController, UIDocumentPickerDelegate {

    private var arView: ARView!
    private var placedEntity: ModelEntity?
    private var pendingEntity: ModelEntity?
    private var objectPlaced = false

    // Position + Rotation state
    private var currentPosition = SIMD3<Float>(0, 0, 0)
    private var currentRotation: Float = 0

    // Joystick views
    private var joystickBase: UIView!
    private var joystickKnob: UIView!
    private let joystickSize: CGFloat = 120
    private let knobSize: CGFloat = 60

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAR()
        setupTapGesture()
        setupImportButton()

        setupJoystick()
        setupHeightSlider()
        setupRotationSlider()
        setupScalingButtons()
    }

    // ------------------------------------------------------
    // MARK: - AR VIEW SETUP
    // ------------------------------------------------------

    private func setupAR() {
        arView = ARView(frame: view.bounds)
        view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)

//        arView.debugOptions = [.showWorldOrigin, .showFeaturePoints]
    }

    // ------------------------------------------------------
    // MARK: - IMPORT BUTTON
    // ------------------------------------------------------

    private func setupImportButton() {
        let button = UIButton(type: .system)
        button.setTitle("+", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 40)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            button.widthAnchor.constraint(equalToConstant: 50),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])

        button.addTarget(self, action: #selector(importModel), for: .touchUpInside)
    }

    @objc private func importModel() {
        let supportedTypes: [UTType] = [
            .usdz,
            .realityFile,
            UTType(filenameExtension: "obj")!,
            UTType(filenameExtension: "stl")!
        ]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.allowsMultipleSelection = false
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        do {
            let model = try ModelEntity.loadModel(contentsOf: url)
            model.scale = SIMD3<Float>(repeating: 0.25)
            pendingEntity = model
            objectPlaced = false
            print("📦 Model loaded: \(url.lastPathComponent)")
        } catch {
            print("❌ Failed to load model:", error)
        }
    }

    // ------------------------------------------------------
    // MARK: - TAP TO PLACE MODEL
    // ------------------------------------------------------

    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(onSceneTap(_:)))
        arView.addGestureRecognizer(tap)
    }

    @objc private func onSceneTap(_ gesture: UITapGestureRecognizer) {
        guard let modelToPlace = pendingEntity, !objectPlaced else { return }

        let location = gesture.location(in: arView)
        let results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)

        guard let result = results.first else {
            print("⚠️ No plane found")
            return
        }

        let position = SIMD3<Float>(result.worldTransform.columns.3.x,
                                    result.worldTransform.columns.3.y,
                                    result.worldTransform.columns.3.z)

        let anchor = AnchorEntity(plane: .horizontal)
        anchor.position = position

        let root = ModelEntity()
        root.addChild(modelToPlace)
        root.generateCollisionShapes(recursive: true)
        arView.scene.addAnchor(anchor)
        anchor.addChild(root)

        placedEntity = root
        currentPosition = root.position

        objectPlaced = true
        print("🪑 Object placed at: \(position)")
    }

    // ------------------------------------------------------
    // MARK: - JOYSTICK MOVEMENT
    // ------------------------------------------------------

    private func setupJoystick() {
        joystickBase = UIView(frame: CGRect(x: 0, y: 0, width: joystickSize, height: joystickSize))
        joystickBase.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        joystickBase.layer.cornerRadius = joystickSize / 2
        joystickBase.center = CGPoint(x: view.bounds.midX, y: view.bounds.height - 260)
        view.addSubview(joystickBase)

        joystickKnob = UIView(frame: CGRect(x: 0, y: 0, width: knobSize, height: knobSize))
        joystickKnob.backgroundColor = .white
        joystickKnob.layer.cornerRadius = knobSize / 2
        joystickKnob.center = joystickBase.center
        view.addSubview(joystickKnob)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleJoystick(_:)))
        joystickKnob.addGestureRecognizer(pan)
    }

    @objc private func handleJoystick(_ gesture: UIPanGestureRecognizer) {
        guard let object = placedEntity else { return }

        let move = gesture.translation(in: view)
        let radius = joystickSize / 2

        let dx = move.x
        let dy = move.y

        let distance = sqrt(dx*dx + dy*dy)
        var finalX = dx
        var finalY = dy

        if distance > radius {
            finalX = (dx / distance) * radius
            finalY = (dy / distance) * radius
        }

        joystickKnob.center = CGPoint(
            x: joystickBase.center.x + finalX,
            y: joystickBase.center.y + finalY
        )

        currentPosition.x += Float(finalX / radius) * 0.02
        currentPosition.z += Float(finalY / radius) * 0.02

        object.position = currentPosition

        if gesture.state == .ended {
            UIView.animate(withDuration: 0.3) {
                self.joystickKnob.center = self.joystickBase.center
            }
        }
    }

    // ------------------------------------------------------
    // MARK: - HEIGHT SLIDER
    // ------------------------------------------------------

    private func setupHeightSlider() {
        let slider = createSlider()
        slider.addTarget(self, action: #selector(changeHeight(_:)), for: .valueChanged)
        view.addSubview(slider)

        NSLayoutConstraint.activate([
            slider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            slider.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -140),
            slider.widthAnchor.constraint(equalToConstant: 260)
        ])
    }

    @objc private func changeHeight(_ sender: UISlider) {
        guard let object = placedEntity else { return }
        currentPosition.y += sender.value * 0.02
        object.position = currentPosition
        resetSlider(sender)
    }

    // ------------------------------------------------------
    // MARK: - ROTATION SLIDER
    // ------------------------------------------------------

    private func setupRotationSlider() {
        let slider = createSlider()
        slider.addTarget(self, action: #selector(rotate(_:)), for: .valueChanged)
        view.addSubview(slider)

        NSLayoutConstraint.activate([
            slider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            slider.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90),
            slider.widthAnchor.constraint(equalToConstant: 260)
        ])
    }

    @objc private func rotate(_ sender: UISlider) {
        guard let object = placedEntity else { return }

        currentRotation += sender.value * 0.1
        object.orientation = simd_quatf(angle: currentRotation, axis: [0,1,0])

        resetSlider(sender)
    }

    private func resetSlider(_ slider: UISlider) {
        if !slider.isTracking {
            UIView.animate(withDuration: 0.3) {
                slider.value = 0
            }
        }
    }

    private func createSlider() -> UISlider {
        let slider = UISlider()
        slider.minimumValue = -1
        slider.maximumValue = 1
        slider.tintColor = .white
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }

    // ------------------------------------------------------
    // MARK: - SCALE BUTTONS
    // ------------------------------------------------------

    private func setupScalingButtons() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false

        let plus = makeButton("➕", #selector(scaleUp))
        let minus = makeButton("➖", #selector(scaleDown))

        stack.addArrangedSubview(plus)
        stack.addArrangedSubview(minus)

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -25),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.widthAnchor.constraint(equalToConstant: 180),
            stack.heightAnchor.constraint(equalToConstant: 55)
        ])
    }

    private func makeButton(_ title: String, _ action: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 30)
        b.tintColor = .white
        b.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        b.layer.cornerRadius = 10
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    @objc private func scaleUp() {
        placedEntity?.scale *= SIMD3<Float>(repeating: 1.05)
    }

    @objc private func scaleDown() {
        placedEntity?.scale *= SIMD3<Float>(repeating: 0.95)
    }
}
