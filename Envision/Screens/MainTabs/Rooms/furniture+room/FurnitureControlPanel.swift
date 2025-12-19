import UIKit
import RealityKit

final class FurnitureControlPanel: UIView {

    // MARK: - Target Model
    private(set) var targetEntity: ModelEntity?

    // MARK: - UI Elements
    private let joystickSize: CGFloat = 120
    private let knobSize: CGFloat = 60

    private var joystickBase = UIView()
    private var joystickKnob = UIView()

    private var heightSlider = UISlider()
    private var rotationSlider = UISlider()

    // MARK: - Tracking values
    private var currentPosition = SIMD3<Float>(0, 0, 0)
    private var currentRotation: Float = 0

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Attach Furniture
    func attach(to entity: ModelEntity) {
        targetEntity = entity
        currentPosition = entity.position
        currentRotation = 0
    }

    // ---------------------------------------------------------
    // MARK: UI Setup
    // ---------------------------------------------------------

    private func setupUI() {
        // backgroundColor = UIColor.black.withAlphaComponent(0.25)
        translatesAutoresizingMaskIntoConstraints = false

        setupJoystick()
        setupHeightSlider()
        setupRotationSlider()
        setupScaleButtons()
    }

    // ---------------------------------------------------------
    // MARK: Joystick for movement
    // ---------------------------------------------------------

    private func setupJoystick() {

        joystickBase.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        joystickBase.layer.cornerRadius = joystickSize / 2
        joystickBase.translatesAutoresizingMaskIntoConstraints = false
        addSubview(joystickBase)

        joystickKnob.backgroundColor = .white
        joystickKnob.layer.cornerRadius = knobSize / 2
        joystickKnob.translatesAutoresizingMaskIntoConstraints = false
        addSubview(joystickKnob)

        NSLayoutConstraint.activate([
                                        joystickBase.centerYAnchor.constraint(equalTo: centerYAnchor),
                                        joystickBase.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
                                        joystickBase.widthAnchor.constraint(equalToConstant: joystickSize),
                                        joystickBase.heightAnchor.constraint(equalToConstant: joystickSize),

                                        joystickKnob.centerXAnchor.constraint(equalTo: joystickBase.centerXAnchor),
                                        joystickKnob.centerYAnchor.constraint(equalTo: joystickBase.centerYAnchor),
                                        joystickKnob.widthAnchor.constraint(equalToConstant: knobSize),
                                        joystickKnob.heightAnchor.constraint(equalToConstant: knobSize)
                                    ])

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleJoystick(_:)))
        joystickKnob.addGestureRecognizer(panGesture)
    }

    @objc private func handleJoystick(_ gesture: UIPanGestureRecognizer) {
        guard let entity = targetEntity else {
            return
        }

        let translation = gesture.translation(in: self)
        let radius = joystickSize / 2

        var dx = translation.x
        var dy = translation.y

        let distance = sqrt(dx * dx + dy * dy)
        if distance > radius {
            dx = (dx / distance) * radius
            dy = (dy / distance) * radius
        }

        joystickKnob.center = CGPoint(
            x: joystickBase.center.x + dx,
            y: joystickBase.center.y + dy
        )

        currentPosition.x += Float(dx / radius) * 0.005
        currentPosition.z += Float(dy / radius) * 0.005
        entity.position = currentPosition

        if gesture.state == .ended {
            UIView.animate(withDuration: 0.3) {
                self.joystickKnob.center = self.joystickBase.center
            }
            gesture.setTranslation(.zero, in: self)
        }
    }


    // ---------------------------------------------------------
    // MARK: Sliders
    // ---------------------------------------------------------

    private func setupHeightSlider() {
        heightSlider = makeSlider()
        heightSlider.addTarget(self, action: #selector(heightChanged(_:)), for: .valueChanged)
        addSubview(heightSlider)

        NSLayoutConstraint.activate([
                                        heightSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
                                        heightSlider.trailingAnchor.constraint(equalTo: joystickBase.leadingAnchor, constant: -30),
                                        heightSlider.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10)
                                    ])
    }

    @objc private func heightChanged(_ sender: UISlider) {
        guard let entity = targetEntity else {
            return
        }

        currentPosition.y += sender.value * 0.01
        entity.position = currentPosition

        resetSliderIfReleased(sender)
    }


    private func setupRotationSlider() {
        rotationSlider = makeSlider()
        rotationSlider.addTarget(self, action: #selector(rotationChanged(_:)), for: .valueChanged)
        addSubview(rotationSlider)

        NSLayoutConstraint.activate([
                                        rotationSlider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
                                        rotationSlider.trailingAnchor.constraint(equalTo: heightSlider.trailingAnchor),
                                        rotationSlider.topAnchor.constraint(equalTo: heightSlider.bottomAnchor, constant: 18)
                                    ])
    }

    @objc private func rotationChanged(_ sender: UISlider) {
        guard let entity = targetEntity else {
            return
        }

        currentRotation += sender.value * 0.05
        entity.orientation = simd_quatf(angle: currentRotation, axis: [0, 1, 0])

        resetSliderIfReleased(sender)
    }


    private func makeSlider() -> UISlider {
        let slider = UISlider()
        slider.minimumValue = -1
        slider.maximumValue = 1
        slider.value = 0
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.tintColor = .white
        return slider
    }

    private func resetSliderIfReleased(_ slider: UISlider) {
        if !slider.isTracking {
            UIView.animate(withDuration: 0.25) {
                slider.value = 0
            }
        }
    }


    // ---------------------------------------------------------
    // MARK: Scale Buttons
    // ---------------------------------------------------------

    private func setupScaleButtons() {

        let plus = makeButton("plus.magnifyingglass", action: #selector(scaleUp))
        let minus = makeButton("minus.magnifyingglass", action: #selector(scaleDown))

        let stack = UIStackView(arrangedSubviews: [minus, plus])
        stack.axis = .horizontal
        stack.spacing = 30
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
                                        stack.leadingAnchor.constraint(equalTo: heightSlider.leadingAnchor),
                                        stack.topAnchor.constraint(equalTo: rotationSlider.bottomAnchor, constant: 10),
                                        stack.widthAnchor.constraint(equalToConstant: 200),
                                        stack.heightAnchor.constraint(equalToConstant: 50)
                                    ])
    }

    private func makeButton(_ symbolName: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)

        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        let image = UIImage(systemName: symbolName, withConfiguration: config)

        b.setImage(image, for: .normal)
        b.tintColor = .white
        b.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        b.layer.cornerRadius = 10
        b.addTarget(self, action: action, for: .touchUpInside)
        return b
    }

    @objc private func scaleUp() {
        applyScale(1.05)
    }

    @objc private func scaleDown() {
        applyScale(0.95)
    }

    private func applyScale(_ factor: Float) {
        guard let entity = targetEntity else {
            return
        }
        entity.scale *= SIMD3(repeating: factor)
    }
}
