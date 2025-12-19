import UIKit
import RealityKit
import ARKit

class RoomFurniture: UIViewController {

    private var arView: ARView!
    private var chairRoot: ModelEntity?
    private var isChairPlaced = false

    // Joystick properties
    private var joystickBase: UIView!
    private var joystickKnob: UIView!
    private let joystickSize: CGFloat = 120
    private let knobSize: CGFloat = 60

    // Current tracked position for joystick/sliders
    private var currentPosition = SIMD3<Float>(0, 0, 0)
    private var currentRotation: Float = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Visualize"
        navigationController?.navigationBar.prefersLargeTitles = false

        setupAR()
        setupTapGesture()
        placeHall()
        setupJoystick()
        setupHeightSlider()
        setupRotationSlider()
        setupScalingButtons()
    }

    // ------------------------------------------------------
    // MARK: - AR SETUP
    // ------------------------------------------------------

    private func setupAR() {
        arView = ARView(frame: view.bounds)
        view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
    }

    // ------------------------------------------------------
    // MARK: - TAP PLACEMENT
    // ------------------------------------------------------

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard !isChairPlaced else { return }

        let tapLocation = gesture.location(in: arView)
        let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)

        guard let hit = results.first else { return }

        let pos = SIMD3<Float>(
            hit.worldTransform.columns.3.x,
            hit.worldTransform.columns.3.y,
            hit.worldTransform.columns.3.z
        )

        placeChair(at: pos)
    }

    private func placeChair(at position: SIMD3<Float>) {
        guard let chairEntity = try? Entity.load(named: "chair") else { return }

        let root = ModelEntity()
        root.addChild(chairEntity)
        root.scale = SIMD3<Float>(repeating: 0.25)
        root.generateCollisionShapes(recursive: true)

        let anchor = AnchorEntity(plane: .horizontal)
        anchor.position = position
        anchor.addChild(root)

        arView.scene.addAnchor(anchor)

        chairRoot = root
        currentPosition = root.position
        currentRotation = 0
        isChairPlaced = true
    }

    // ------------------------------------------------------
    // MARK: - HALL SPAWN
    // ------------------------------------------------------

    private func placeHall() {
        guard let hallEntity = try? Entity.load(named: "hall") else { return }

        hallEntity.scale = SIMD3<Float>(repeating: 0.5)
        hallEntity.generateCollisionShapes(recursive: true)

        let hallAnchor = AnchorEntity(plane: .horizontal)
        hallAnchor.addChild(hallEntity)
        arView.scene.addAnchor(hallAnchor)
    }

    // ------------------------------------------------------
    // MARK: - JOYSTICK (Movement X/Z)
    // ------------------------------------------------------

    private func setupJoystick() {

        joystickBase = UIView(frame: CGRect(x: 0, y: 0, width: joystickSize, height: joystickSize))
        joystickBase.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        joystickBase.layer.cornerRadius = joystickSize / 2
        joystickBase.center = CGPoint(x: view.bounds.midX, y: view.bounds.height - 260)
        view.addSubview(joystickBase)

        joystickKnob = UIView(frame: CGRect(x: 0, y: 0, width: knobSize, height: knobSize))
        joystickKnob.backgroundColor = UIColor.white
        joystickKnob.layer.cornerRadius = knobSize / 2
        joystickKnob.center = joystickBase.center
        view.addSubview(joystickKnob)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleJoystick(_:)))
        joystickKnob.addGestureRecognizer(pan)
    }

    @objc private func handleJoystick(_ gesture: UIPanGestureRecognizer) {
        guard let chair = chairRoot else { return }

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

        let forceX = Float(finalX / radius) * 0.02
        let forceZ = Float(finalY / radius) * 0.02

        currentPosition.x += forceX
        currentPosition.z += forceZ

        chair.position = currentPosition

        if gesture.state == .ended {
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 1.2) {
                self.joystickKnob.center = self.joystickBase.center
            }
            gesture.setTranslation(.zero, in: view)
        }
    }

    // ------------------------------------------------------
    // MARK: - SPRING SLIDER FOR HEIGHT (Y Axis)
    // ------------------------------------------------------

    private func setupHeightSlider() {

        let slider = createSlider()

        slider.addTarget(self, action: #selector(heightChanged(_:)), for: .valueChanged)

        view.addSubview(slider)

        NSLayoutConstraint.activate([
            slider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            slider.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -140),
            slider.widthAnchor.constraint(equalToConstant: 260)
        ])
    }

    @objc private func heightChanged(_ sender: UISlider) {
        guard let chair = chairRoot else { return }

        currentPosition.y += sender.value * 0.02
        chair.position = currentPosition

        resetSliderIfReleased(sender)
    }

    // ------------------------------------------------------
    // MARK: - SPRING SLIDER FOR ROTATION
    // ------------------------------------------------------

    private func setupRotationSlider() {

        let slider = createSlider()

        slider.addTarget(self, action: #selector(rotationChanged(_:)), for: .valueChanged)

        view.addSubview(slider)

        NSLayoutConstraint.activate([
            slider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            slider.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90),
            slider.widthAnchor.constraint(equalToConstant: 260)
        ])
    }

    @objc private func rotationChanged(_ sender: UISlider) {
        guard let chair = chairRoot else { return }

        currentRotation += sender.value * 0.1

        UIView.animate(withDuration: 0.15) {
            chair.orientation = simd_quatf(angle: self.currentRotation, axis: [0,1,0])
        }

        resetSliderIfReleased(sender)
    }

    // Helper for sliders
    private func resetSliderIfReleased(_ slider: UISlider) {
        if !slider.isTracking {
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           usingSpringWithDamping: 0.6,
                           initialSpringVelocity: 1.1) {
                slider.value = 0
            }
        }
    }

    private func createSlider() -> UISlider {
        let s = UISlider()
        s.minimumValue = -1
        s.maximumValue = 1
        s.value = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        s.tintColor = .white
        return s
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

        view.addSubview(stack)

        let scaleUp = makeButton("➕", #selector(scaleUpTap))
        let scaleDown = makeButton("➖", #selector(scaleDownTap))

        stack.addArrangedSubview(scaleUp)
        stack.addArrangedSubview(scaleDown)

        NSLayoutConstraint.activate([
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -25),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.widthAnchor.constraint(equalToConstant: 180),
            stack.heightAnchor.constraint(equalToConstant: 55)
        ])
    }

    private func makeButton(_ title: String, _ selector: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 30)
        b.tintColor = .white
        b.layer.cornerRadius = 10
        b.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        b.addTarget(self, action: selector, for: .touchUpInside)
        return b
    }

    @objc private func scaleUpTap() {
        scale(by: 1.05)
    }

    @objc private func scaleDownTap() {
        scale(by: 0.95)
    }

    private func scale(by factor: Float) {
        guard let chair = chairRoot else { return }
        UIView.animate(withDuration: 0.2) {
            chair.scale *= SIMD3<Float>(repeating: factor)
        }
    }
}

// spring slider
class RoomFurnitureM2: UIViewController {

    private var arView: ARView!
    private var chairRoot: ModelEntity?
    private var isChairPlaced = false

    // Tracks chair movement incrementally for joystick mode
    private var currentPosition = SIMD3<Float>(0,0,0)
    private var joystickBase: UIView!
    private var joystickKnob: UIView!
    private let joystickSize: CGFloat = 120
    private let knobSize: CGFloat = 60
    private var joystickActive = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAR()
        setupTapGesture()
        placeHall()
        setupSliders()
//        setupJoystick()

    }

    // ------------------------------------------------------
    // MARK: - AR SETUP
    // ------------------------------------------------------

    private func setupAR() {
        arView = ARView(frame: view.bounds)
        view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)

        // Debug if needed:
//         arView.debugOptions = [.showWorldOrigin, .showFeaturePoints]
    }

    // ------------------------------------------------------
    // MARK: - TAP TO PLACE CHAIR
    // ------------------------------------------------------
    private func setupJoystick() {

        joystickBase = UIView(frame: CGRect(x: 0, y: 0, width: joystickSize, height: joystickSize))
        joystickBase.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        joystickBase.layer.cornerRadius = joystickSize / 2
        joystickBase.center = CGPoint(x: view.bounds.midX, y: view.bounds.height - 200)
        joystickBase.isUserInteractionEnabled = true
        view.addSubview(joystickBase)

        joystickKnob = UIView(frame: CGRect(x: 0, y: 0, width: knobSize, height: knobSize))
        joystickKnob.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        joystickKnob.layer.cornerRadius = knobSize / 2
        joystickKnob.center = joystickBase.center
        joystickKnob.isUserInteractionEnabled = true
        view.addSubview(joystickKnob)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleJoystickMove(_:)))
        joystickKnob.addGestureRecognizer(panGesture)
    }
    @objc private func handleJoystickMove(_ gesture: UIPanGestureRecognizer) {
        guard let chair = chairRoot else { return }

        let translation = gesture.translation(in: view)

        // Convert movement to joystick local coordinate space
        let dx = translation.x
        let dy = translation.y

        // Limit knob movement to circle radius
        let distance = sqrt(dx * dx + dy * dy)
        let maxRadius = joystickSize / 2

        var finalX = dx
        var finalY = dy

        if distance > maxRadius {
            finalX = (dx / distance) * maxRadius
            finalY = (dy / distance) * maxRadius
        }

        // Move knob visually
        joystickKnob.center = CGPoint(
            x: joystickBase.center.x + finalX,
            y: joystickBase.center.y + finalY
        )

        // Apply movement force (scaled)
        let forceX = Float(finalX / maxRadius) * 0.02
        let forceZ = Float(finalY / maxRadius) * 0.02

        currentPosition.x += forceX
        currentPosition.z += forceZ

        // Smooth update
        UIView.animate(withDuration: 0.15) {
            chair.position = self.currentPosition
        }

        // Re-center joystick after release
        if gesture.state == .ended {
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.5,
                initialSpringVelocity: 1.2,
                options: .curveEaseOut
            ) {
                self.joystickKnob.center = self.joystickBase.center
            }

            gesture.setTranslation(.zero, in: view)
        }
    }

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {

        guard !isChairPlaced else { return }

        let tapLocation = gesture.location(in: arView)

        let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)

        guard let firstHit = results.first else {
            print("❌ No plane found yet.")
            return
        }

        let position = SIMD3<Float>(
            firstHit.worldTransform.columns.3.x,
            firstHit.worldTransform.columns.3.y,
            firstHit.worldTransform.columns.3.z
        )

        placeChair(at: position)
    }

    private func placeChair(at position: SIMD3<Float>) {

        guard let chairEntity = try? Entity.load(named: "chair") else {
            print("❌ chair.usdz missing.")
            return
        }

        let root = ModelEntity()
        root.addChild(chairEntity)
        root.scale = SIMD3<Float>(repeating: 0.25)

        root.generateCollisionShapes(recursive: true)

        let anchor = AnchorEntity(plane: .horizontal)
        anchor.position = position
        anchor.addChild(root)
        arView.scene.addAnchor(anchor)

        chairRoot = root
        currentPosition = root.position  // sync starting point
        isChairPlaced = true

        print("✅ Chair placed at", position)
    }

    // ------------------------------------------------------
    // MARK: - AUTO PLACE HALL
    // ------------------------------------------------------

    private func placeHall() {

        guard let hallEntity = try? Entity.load(named: "hall") else {
            print("❌ hall.usdz missing.")
            return
        }

        hallEntity.scale = SIMD3<Float>(repeating: 0.5)
        hallEntity.generateCollisionShapes(recursive: true)

        let hallAnchor = AnchorEntity(plane: .horizontal)
        hallAnchor.addChild(hallEntity)
        arView.scene.addAnchor(hallAnchor)
    }

    // ------------------------------------------------------
    // MARK: - SLIDER CONTROL UI (JOYSTICK + NORMAL)
    // ------------------------------------------------------

    private func setupSliders() {

        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 18
        container.translatesAutoresizingMaskIntoConstraints = false
        container.alignment = .center
        container.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        container.layer.cornerRadius = 14
        container.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        container.isLayoutMarginsRelativeArrangement = true
        view.addSubview(container)

        // ---- Joystick Sliders ----
        let moveX = createSlider(min: -1, max: 1, action: #selector(moveXChanged(_:)))
        moveX.value = 0
        container.addArrangedSubview(labelled("Move X", moveX))

        let moveZ = createSlider(min: -1, max: 1, action: #selector(moveZChanged(_:)))
        moveZ.value = 0
        container.addArrangedSubview(labelled("Move Z", moveZ))

        let moveY = createSlider(min: -1, max: 1, action: #selector(moveYChanged(_:)))
        moveY.value = 0
        container.addArrangedSubview(labelled("Height", moveY))

        // ---- Normal Sliders ----
        let rotationSlider = createSlider(min: -Float.pi, max: Float.pi, action: #selector(rotationChanged(_:)))
        rotationSlider.value = 0
        container.addArrangedSubview(labelled("Rotate", rotationSlider))

        let scaleSlider = createSlider(min: 0.1, max: 2.0, action: #selector(scaleChanged(_:)))
        scaleSlider.value = 0.25
        container.addArrangedSubview(labelled("Scale", scaleSlider))

        NSLayoutConstraint.activate([
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func createSlider(min: Float, max: Float, action: Selector) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = min
        slider.maximumValue = max
        slider.addTarget(self, action: action, for: .valueChanged)
        slider.widthAnchor.constraint(equalToConstant: 260).isActive = true
        slider.tintColor = .white
        return slider
    }

    private func labelled(_ title: String, _ slider: UISlider) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)

        let row = UIStackView(arrangedSubviews: [label, slider])
        row.axis = .vertical
        row.spacing = 5
        row.alignment = .center
        return row
    }

    // ------------------------------------------------------
    // MARK: - SLIDER ACTIONS (JOYSTICK + SPRING)
    // ------------------------------------------------------

    @objc private func moveXChanged(_ sender: UISlider) {
        joystickMove(sender) { force in self.currentPosition.x += force }
    }

    @objc private func moveZChanged(_ sender: UISlider) {
        joystickMove(sender) { force in self.currentPosition.z += force }
    }

    @objc private func moveYChanged(_ sender: UISlider) {
        joystickMove(sender) { force in self.currentPosition.y += force }
    }

    private func joystickMove(_ slider: UISlider, update: (_ force: Float) -> Void) {
        guard let chair = chairRoot else { return }
        let force = slider.value * 0.02  // sensitivity

        update(force)

        animateSpring {
            chair.position = self.currentPosition
        }

        // Reset to zero after release
        if !slider.isTracking {
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           usingSpringWithDamping: 0.6,
                           initialSpringVelocity: 1.2,
                           options: .curveEaseOut) {
                slider.value = 0
            }
        }
    }

    // ------------------------------------------------------
    // MARK: - STATIC (NON-JOYSTICK) SLIDERS
    // ------------------------------------------------------

    @objc private func rotationChanged(_ sender: UISlider) {
        guard let chair = chairRoot else { return }
        let value = sender.value

        animateSpring {
            chair.orientation = simd_quatf(angle: value, axis: [0,1,0])
        }
    }

    @objc private func scaleChanged(_ sender: UISlider) {
        guard let chair = chairRoot else { return }
        animateSpring {
            chair.scale = SIMD3<Float>(repeating: sender.value)
        }
    }

    // ------------------------------------------------------
    // MARK: - SPRING ANIMATION HELPER
    // ------------------------------------------------------

    private func animateSpring(_ block: @escaping () -> Void) {
        UIView.animate(withDuration: 0.25,
                       delay: 0,
                       usingSpringWithDamping: 0.55,
                       initialSpringVelocity: 0.9,
                       options: .curveEaseOut,
                       animations: block)
    }
}

//buttons
class RoomFurnitureM1: UIViewController {

    private var arView: ARView!
    private var chairRoot: ModelEntity?
    private var isChairPlaced = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupAR()
        setupTapGesture()
        setupSliders()
        placeHall()
//        setupControlButtons()
    }

    // ------------------------------------------------------
    // MARK: - AR SETUP
    // ------------------------------------------------------

    private func setupAR() {
        arView = ARView(frame: view.bounds)
        view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
    }
    private func setupSliders() {

        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 20
        container.translatesAutoresizingMaskIntoConstraints = false
        container.alignment = .center
        
        container.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        container.layer.cornerRadius = 15
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
        
        view.addSubview(container)

        // ----- Move X -----
        let moveX = createSlider(min: -0.2, max: 0.2, action: #selector(moveXChanged(_:)))
        container.addArrangedSubview(labelled("Move X", moveX))

        // ----- Move Z -----
        let moveZ = createSlider(min: -0.2, max: 0.2, action: #selector(moveZChanged(_:)))
        container.addArrangedSubview(labelled("Move Z", moveZ))

        // ----- Move Y (Height) -----
        let moveY = createSlider(min: -0.2, max: 0.2, action: #selector(moveYChanged(_:)))
        container.addArrangedSubview(labelled("Height", moveY))

        // ----- Rotation -----
        let rotateSlider = createSlider(min: -Float.pi, max: Float.pi, action: #selector(rotationChanged(_:)))
        container.addArrangedSubview(labelled("Rotate", rotateSlider))

        // ----- Scale -----
        let scaleSlider = createSlider(min: 0.1, max: 2.0, action: #selector(scaleChanged(_:)))
        scaleSlider.value = 0.25   // match object scale
        container.addArrangedSubview(labelled("Scale", scaleSlider))

        NSLayoutConstraint.activate([
            container.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    private func createSlider(min: Float, max: Float, action: Selector) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = min
        slider.maximumValue = max
        slider.tintColor = .white
        slider.addTarget(self, action: action, for: .valueChanged)
        slider.widthAnchor.constraint(equalToConstant: 250).isActive = true
        return slider
    }

    private func labelled(_ title: String, _ slider: UISlider) -> UIStackView {
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)

        let stack = UIStackView(arrangedSubviews: [label, slider])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        return stack
    }


    // ------------------------------------------------------
    // MARK: - TAP TO PLACE CHAIR
    // ------------------------------------------------------

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {

        guard !isChairPlaced else { return }

        let tapLocation = gesture.location(in: arView)

        let results = arView.raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .horizontal)

        guard let firstHit = results.first else {
            print("❌ No plane detected.")
            return
        }

        let position = SIMD3<Float>(
            firstHit.worldTransform.columns.3.x,
            firstHit.worldTransform.columns.3.y,
            firstHit.worldTransform.columns.3.z
        )

        placeChair(at: position)
    }

    private func placeChair(at position: SIMD3<Float>) {

        guard let chairEntity = try? Entity.load(named: "chair") else {
            print("❌ chair.usdz not found")
            return
        }

        let root = ModelEntity()
        root.addChild(chairEntity)
        root.scale = SIMD3<Float>(repeating: 0.25)

        root.generateCollisionShapes(recursive: true)

        let anchor = AnchorEntity(plane: .horizontal)
        anchor.position = [position.x, position.y + 0.02, position.z]
        anchor.addChild(root)

        arView.scene.addAnchor(anchor)

        self.chairRoot = root
        self.isChairPlaced = true

        print("✅ Chair placed at:", anchor.position)
    }


    // ------------------------------------------------------
    // MARK: - PLACE HALL AUTOMATICALLY
    // ------------------------------------------------------

    private func placeHall() {

        guard let hallEntity = try? Entity.load(named: "hall") else {
            print("❌ hall.usdz not found")
            return
        }

        hallEntity.scale = SIMD3<Float>(repeating: 0.5)
        hallEntity.generateCollisionShapes(recursive: true)

        let hallAnchor = AnchorEntity(plane: .horizontal)
        hallAnchor.addChild(hallEntity)

        arView.scene.addAnchor(hallAnchor)
    }


    // ------------------------------------------------------
    // MARK: - UI BUTTON CONTROLS (UPDATED WITH Y AXIS)
    // ------------------------------------------------------

    private func setupControlButtons() {

        let panel = UIStackView()
        panel.axis = .vertical
        panel.alignment = .center
        panel.spacing = 10
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        panel.layer.cornerRadius = 15
        panel.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        panel.isLayoutMarginsRelativeArrangement = true
        view.addSubview(panel)

        // Row: Movement (⬅️ ⬆️ ⬇️ ➡️)
        let moveRow = makeRow(["⬅️", "⬆️", "⬇️", "➡️"],
                              actions: [#selector(moveLeft), #selector(moveForward), #selector(moveBackward), #selector(moveRight)])
        panel.addArrangedSubview(moveRow)

        // Row: Height (⤴️ ⤵️)
        let heightRow = makeRow(["⤴️", "⤵️"],
                                actions: [#selector(moveUp), #selector(moveDown)])
        panel.addArrangedSubview(heightRow)

        // Row: Scale (➕ ➖)
        let scaleRow = makeRow(["➕", "➖"],
                               actions: [#selector(scaleUp), #selector(scaleDown)])
        panel.addArrangedSubview(scaleRow)

        // Row: Rotate (🔁)
        let rotateRow = makeRow(["🔁"],
                                actions: [#selector(rotate)])
        panel.addArrangedSubview(rotateRow)

        NSLayoutConstraint.activate([
            panel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panel.widthAnchor.constraint(equalToConstant: 220)
        ])
    }
    private func makeRow(_ titles: [String], actions: [Selector]) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually

        for (i, title) in titles.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 26)
            btn.tintColor = .white
            btn.backgroundColor = UIColor.darkGray.withAlphaComponent(0.4)
            btn.layer.cornerRadius = 10
            btn.widthAnchor.constraint(equalToConstant: 44).isActive = true
            btn.heightAnchor.constraint(equalToConstant: 44).isActive = true
            btn.addTarget(self, action: actions[i], for: .touchUpInside)
            row.addArrangedSubview(btn)
        }
        return row
    }


    // ------------------------------------------------------
    // MARK: - CONTROL ACTIONS (UPDATED)
    // ------------------------------------------------------

    private let moveStep: Float = 0.05
    private let scaleStep: Float = 0.05
    private let rotationStep: Float = .pi / 12

    @objc private func moveLeft() { chairRoot?.position.x -= moveStep }
    @objc private func moveRight() { chairRoot?.position.x += moveStep }
    @objc private func moveForward() { chairRoot?.position.z -= moveStep }
    @objc private func moveBackward() { chairRoot?.position.z += moveStep }

    // NEW Y-AXIS CONTROLS
    @objc private func moveUp() { chairRoot?.position.y += moveStep }
    @objc private func moveDown() { chairRoot?.position.y -= moveStep }

    @objc private func scaleUp() {
        guard let chair = chairRoot else { return }
        chair.scale += SIMD3<Float>(repeating: scaleStep)
    }

    @objc private func scaleDown() {
        guard let chair = chairRoot else { return }
        chair.scale -= SIMD3<Float>(repeating: scaleStep)
    }

    @objc private func rotate() {
        guard let chair = chairRoot else { return }
        chair.orientation *= simd_quatf(angle: rotationStep, axis: [0, 1, 0])
    }
    //-------------
    @objc private func moveXChanged(_ sender: UISlider) {
        chairRoot?.position.x = sender.value
    }

    @objc private func moveZChanged(_ sender: UISlider) {
        chairRoot?.position.z = sender.value
    }

    @objc private func moveYChanged(_ sender: UISlider) {
        chairRoot?.position.y = sender.value
    }

    @objc private func rotationChanged(_ sender: UISlider) {
        chairRoot?.orientation = simd_quatf(angle: sender.value, axis: [0,1,0])
    }

    @objc private func scaleChanged(_ sender: UISlider) {
        let v = sender.value
        chairRoot?.scale = SIMD3<Float>(repeating: v)
    }

}
