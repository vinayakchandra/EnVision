import UIKit
import RealityKit

final class FurnitureControlPanel: UIView {

    // MARK: - Target Model
    private(set) var targetEntity: ModelEntity?

    // MARK: - UI Elements
    private let joystickSize: CGFloat = 104
    private let knobSize: CGFloat = 46

    private var joystickBase = UIView()
    private var joystickKnob = UIView()

    private var heightLabel = UILabel()
    private var rotationLabel = UILabel()
    private var heightSlider = UISlider()
    private var rotationSlider = UISlider()

    // MARK: - Tracking values
    private var currentPosition = SIMD3<Float>(0, 0, 0)
    private var currentRotation: Float = 0

    // MARK: - Theme
    private var controlBaseColor: UIColor {
        UIColor.white
    }

    private var knobColor: UIColor {
        UIColor.white
    }

    private var iconColor: UIColor {
        UIColor.black.withAlphaComponent(0.55)
    }

    private var labelColor: UIColor {
        UIColor.black.withAlphaComponent(0.40)
    }

    private var sliderMinColor: UIColor {
        UIColor.black.withAlphaComponent(0.46)
    }

    private var sliderMaxColor: UIColor {
        UIColor.black.withAlphaComponent(0.18)
    }

    private var sliderThumbColor: UIColor {
        UIColor.white
    }

    private var controlBorderColor: UIColor {
        UIColor.black.withAlphaComponent(0.16)
    }

    private var panelBackgroundColor: UIColor {
        UIColor.clear
    }

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
        backgroundColor = panelBackgroundColor
        translatesAutoresizingMaskIntoConstraints = false

        setupJoystick()
        setupHeightSlider()
        setupRotationSlider()
        setupScaleButtons()
        applyTheme()
    }

    private func applyTheme() {
        backgroundColor = panelBackgroundColor

        joystickBase.backgroundColor = controlBaseColor
        joystickKnob.backgroundColor = knobColor
        joystickBase.layer.borderColor = controlBorderColor.cgColor
        joystickKnob.layer.borderColor = controlBorderColor.cgColor

        joystickBase.layer.shadowColor = UIColor.black.cgColor
        joystickBase.layer.shadowOpacity = 0.20
        joystickBase.layer.shadowRadius = 10
        joystickBase.layer.shadowOffset = CGSize(width: 0, height: 3)

        joystickKnob.layer.shadowColor = UIColor.black.cgColor
        joystickKnob.layer.shadowOpacity = 0.18
        joystickKnob.layer.shadowRadius = 6
        joystickKnob.layer.shadowOffset = CGSize(width: 0, height: 3)

        heightLabel.textColor = labelColor
        rotationLabel.textColor = labelColor

        heightSlider.minimumTrackTintColor = sliderMinColor
        heightSlider.maximumTrackTintColor = sliderMaxColor
        heightSlider.thumbTintColor = sliderThumbColor

        rotationSlider.minimumTrackTintColor = sliderMinColor
        rotationSlider.maximumTrackTintColor = sliderMaxColor
        rotationSlider.thumbTintColor = sliderThumbColor

        for case let button as UIButton in subviews {
            guard button.currentImage != nil else { continue }
            button.tintColor = iconColor
            button.backgroundColor = controlBaseColor
            button.layer.borderColor = controlBorderColor.cgColor
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.16
            button.layer.shadowRadius = 8
            button.layer.shadowOffset = CGSize(width: 0, height: 3)
        }
    }

    // ---------------------------------------------------------
    // MARK: Joystick for movement
    // ---------------------------------------------------------

    private func setupJoystick() {

        joystickBase.backgroundColor = controlBaseColor
        joystickBase.layer.cornerRadius = joystickSize / 2
        joystickBase.layer.borderWidth = 1
        joystickBase.translatesAutoresizingMaskIntoConstraints = false
        addSubview(joystickBase)

        joystickKnob.backgroundColor = knobColor
        joystickKnob.layer.cornerRadius = knobSize / 2
        joystickKnob.layer.borderWidth = 1
        joystickKnob.translatesAutoresizingMaskIntoConstraints = false
        addSubview(joystickKnob)

        NSLayoutConstraint.activate([
            joystickBase.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
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
        heightLabel = makeSliderLabel(text: "Height")
        addSubview(heightLabel)

        heightSlider = makeSlider()
        heightSlider.addTarget(self, action: #selector(heightChanged(_:)), for: .valueChanged)
        addSubview(heightSlider)

        NSLayoutConstraint.activate([
            heightLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            heightLabel.centerYAnchor.constraint(equalTo: heightSlider.centerYAnchor),
            heightLabel.widthAnchor.constraint(equalToConstant: 46),

            heightSlider.leadingAnchor.constraint(equalTo: heightLabel.trailingAnchor, constant: 8),
            heightSlider.trailingAnchor.constraint(equalTo: joystickBase.leadingAnchor, constant: -30),
            heightSlider.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12)
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
        rotationLabel = makeSliderLabel(text: "Rotation")
        addSubview(rotationLabel)

        rotationSlider = makeSlider()
        rotationSlider.addTarget(self, action: #selector(rotationChanged(_:)), for: .valueChanged)
        addSubview(rotationSlider)

        NSLayoutConstraint.activate([
            rotationLabel.leadingAnchor.constraint(equalTo: heightLabel.leadingAnchor),
            rotationLabel.centerYAnchor.constraint(equalTo: rotationSlider.centerYAnchor),
            rotationLabel.widthAnchor.constraint(equalToConstant: 46),

            rotationSlider.leadingAnchor.constraint(equalTo: rotationLabel.trailingAnchor, constant: 8),
            rotationSlider.trailingAnchor.constraint(equalTo: heightSlider.trailingAnchor),
            rotationSlider.topAnchor.constraint(equalTo: heightSlider.bottomAnchor, constant: 14)
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


    private func makeSliderLabel(text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = labelColor
        return label
    }

    private func makeSlider() -> UISlider {
        let slider = UISlider()
        slider.minimumValue = -1
        slider.maximumValue = 1
        slider.value = 0
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = sliderMinColor
        slider.maximumTrackTintColor = sliderMaxColor
        slider.thumbTintColor = sliderThumbColor
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
        stack.spacing = 18
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: heightSlider.leadingAnchor),
            stack.topAnchor.constraint(equalTo: rotationSlider.bottomAnchor, constant: 10),
            stack.widthAnchor.constraint(equalToConstant: 168),
            stack.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func makeButton(_ symbolName: String, action: Selector) -> UIButton {
        let b = UIButton(type: .system)

        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let image = UIImage(systemName: symbolName, withConfiguration: config)

        b.setImage(image, for: .normal)
        b.tintColor = iconColor
        b.backgroundColor = controlBaseColor
        b.layer.borderWidth = 1
        b.layer.borderColor = controlBorderColor.cgColor
        b.layer.cornerRadius = 9
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
