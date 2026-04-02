//
//  VisualizeRoomViewController+Measurements.swift
//  Envision
//
//  Adds two measurement tools to the AR furniture viewer:
//
//  1. Scale Measurement — bounding box with W / H / D labels drawn around
//     the loaded model (uses BoundingBoxEntity from Components/).
//
//  2. Point-to-Point — tap any two surfaces in the AR scene (model or
//     real-world plane) to place markers and display the straight-line
//     distance between them (uses DistanceLabelEntity from Components/).
//

import UIKit
import RealityKit
import ARKit

// MARK: - Measurement Toolbar Setup

extension VisualizeRoomViewController {

    // MARK: - Toolbar

    func setupMeasurementToolbar() {
        let toolbar = buildToolbar()
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            toolbar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    func buildToolbar() -> UIView {
        let container = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 22
        container.clipsToBounds = true

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .center
        stack.distribution = .equalSpacing

        let bbox = makeToolbarButton(icon: "ruler", label: "Scale", tag: 0, action: #selector(bboxButtonTapped))
        bboxButton = bbox

        let p2p = makeToolbarButton(
            icon: "point.topleft.down.to.point.bottomright.curvepath",
            label: "P-to-P",
            tag: 1,
            action: #selector(p2pButtonTapped)
        )
        p2pButton = p2p

        let unit = makeToolbarButton(
            icon: "arrow.left.and.right",
            label: measurementUnit == .metric ? "m" : "ft",
            tag: 2,
            action: #selector(unitButtonTapped)
        )
        unitButton = unit

        let clear = makeToolbarButton(icon: "trash", label: "Clear", tag: 3, action: #selector(clearButtonTapped))

        [bbox, p2p, unit, clear].forEach { stack.addArrangedSubview($0) }

        container.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.contentView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor, constant: -12),
        ])

        return container
    }

    func makeToolbarButton(icon: String, label: String, tag: Int, action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(
            systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        )
        config.title = label
        config.imagePlacement = .top
        config.imagePadding = 4
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)

        let btn = UIButton(configuration: config)
        btn.tag = tag
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.titleLabel?.font = .systemFont(ofSize: 10, weight: .medium)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - Toolbar Actions

    @objc func bboxButtonTapped() {
        toggleBoundingBox()
    }

    @objc func p2pButtonTapped() {
        togglePointToPoint()
    }

    @objc func unitButtonTapped() {
        measurementUnit = (measurementUnit == .metric) ? .imperial : .metric
        MeasurementManager.shared.currentUnit = measurementUnit

        var config = unitButton?.configuration
        config?.title = measurementUnit == .metric ? "m" : "ft"
        unitButton?.configuration = config

        if showBoundingBox {
            removeBoundingBox()
            showBoundingBoxForLoadedEntity()
        }
    }

    @objc func clearButtonTapped() {
        clearAllMeasurements()
    }

    // MARK: - Active Mode Indicator

    func updateButtonState(_ button: UIButton?, active: Bool) {
        var config = button?.configuration
        config?.baseForegroundColor = active ? AppColors.accent : .label
        config?.background.backgroundColor = active
            ? AppColors.accent.withAlphaComponent(0.15)
            : .clear
        button?.configuration = config
    }
}

// MARK: - Scale / Bounding Box

extension VisualizeRoomViewController {

    func toggleBoundingBox() {
        showBoundingBox.toggle()
        updateButtonState(bboxButton, active: showBoundingBox)

        if showBoundingBox {
            showBoundingBoxForLoadedEntity()
        } else {
            removeBoundingBox()
        }
    }

    func showBoundingBoxForLoadedEntity() {
        guard let entity = loadedEntity else {
            showNeedModelAlert()
            showBoundingBox = false
            updateButtonState(bboxButton, active: false)
            return
        }

        let boxEntity = BoundingBoxEntity(
            for: entity,
            color: AppColors.accent,
            unit: measurementUnit,
            showLabels: true
        )

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(boxEntity)
        arView.scene.addAnchor(anchor)
        activeBoundingBoxAnchor = anchor

        presentDimensionsHUD(for: entity)
    }

    func removeBoundingBox() {
        if let anchor = activeBoundingBoxAnchor {
            arView.scene.removeAnchor(anchor)
            activeBoundingBoxAnchor = nil
        }
        dismissDimensionsHUD()
    }

    // MARK: - Dimensions HUD

    static let hudTag = 9_001

    func presentDimensionsHUD(for entity: Entity) {
        dismissDimensionsHUD()

        let bounds = entity.visualBounds(relativeTo: nil)
        let scale = RealWorldScaleManager.shared

        let w = scale.formatRealWorldDistance(scale.toRealWorldMeters(bounds.extents.x))
        let h = scale.formatRealWorldDistance(scale.toRealWorldMeters(bounds.extents.y))
        let d = scale.formatRealWorldDistance(scale.toRealWorldMeters(bounds.extents.z))

        let hud = UIView()
        hud.tag = VisualizeRoomViewController.hudTag
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        hud.layer.cornerRadius = 12

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "W \(w)  ·  H \(h)  ·  D \(d)"
        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center

        hud.addSubview(label)
        view.addSubview(hud)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: hud.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -14),
            hud.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            hud.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    func dismissDimensionsHUD() {
        view.viewWithTag(VisualizeRoomViewController.hudTag)?.removeFromSuperview()
    }
}

// MARK: - Point-to-Point Measurement

extension VisualizeRoomViewController {

    func togglePointToPoint() {
        isPointToPointActive.toggle()
        updateButtonState(p2pButton, active: isPointToPointActive)

        if isPointToPointActive {
            showP2PHint()
        } else {
            cancelPendingPointA()
            dismissP2PHint()
        }
    }

    // MARK: - Tap Handler

    func handlePointToPointTap(at screenPoint: CGPoint) {
        guard let worldPos = resolveWorldPosition(from: screenPoint) else { return }

        if pendingPointA == nil {
            placePointAMarker(at: worldPos)
            pendingPointA = worldPos
            updateP2PHint("Tap a second point to complete measurement")
        } else {
            let pointA = pendingPointA!
            drawMeasurement(from: pointA, to: worldPos)
            cancelPendingPointA()
            updateP2PHint("Tap to start a new measurement")
        }
    }

    // MARK: - World Position Resolution

    func resolveWorldPosition(from screenPoint: CGPoint) -> SIMD3<Float>? {
        // 1. Hit on a RealityKit entity (the furniture model)
        if let hit = arView.scene.firstRaycast(from: screenPoint, in: arView) {
            return hit.position
        }

        // 2. ARKit plane raycast
        let arkitResults = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .any)
        if let hit = arkitResults.first {
            let col = hit.worldTransform.columns.3
            return SIMD3<Float>(col.x, col.y, col.z)
        }

        // 3. Project onto horizontal plane at model's Y level
        guard let entity = loadedEntity else { return nil }
        return projectRayOntoHorizontalPlane(screenPoint: screenPoint, atY: entity.position(relativeTo: nil).y)
    }

    func projectRayOntoHorizontalPlane(screenPoint: CGPoint, atY y: Float) -> SIMD3<Float>? {
        guard let ray = arView.ray(through: screenPoint) else { return nil }
        let dy = ray.direction.y
        guard abs(dy) > 0.0001 else { return nil }
        let t = (y - ray.origin.y) / dy
        guard t > 0 else { return nil }
        return ray.origin + ray.direction * t
    }

    // MARK: - Point A Marker

    func placePointAMarker(at position: SIMD3<Float>) {
        cancelPendingPointA()

        let sphere = ModelEntity(
            mesh: .generateSphere(radius: 0.006),
            materials: [SimpleMaterial(color: .systemGreen, roughness: 0.4, isMetallic: false)]
        )
        let anchor = AnchorEntity(world: position)
        anchor.addChild(sphere)
        arView.scene.addAnchor(anchor)
        pointAMarkerAnchor = anchor
    }

    func cancelPendingPointA() {
        pendingPointA = nil
        if let a = pointAMarkerAnchor {
            arView.scene.removeAnchor(a)
            pointAMarkerAnchor = nil
        }
    }

    // MARK: - Draw Measurement

    func drawMeasurement(from start: SIMD3<Float>, to end: SIMD3<Float>) {
        let distLine = DistanceLabelEntity(from: start, to: end, unit: measurementUnit)
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(distLine)
        arView.scene.addAnchor(anchor)
        measurementAnchors.append(anchor)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - P2P Hint

    static let p2pHintTag = 9_002

    func showP2PHint(_ message: String = "Tap any surface to place first point") {
        dismissP2PHint()

        let hud = UIView()
        hud.tag = VisualizeRoomViewController.p2pHintTag
        hud.translatesAutoresizingMaskIntoConstraints = false
        hud.backgroundColor = AppColors.accent.withAlphaComponent(0.85)
        hud.layer.cornerRadius = 10

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = message
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center

        hud.addSubview(label)
        view.addSubview(hud)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: hud.topAnchor, constant: 7),
            label.bottomAnchor.constraint(equalTo: hud.bottomAnchor, constant: -7),
            label.leadingAnchor.constraint(equalTo: hud.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: hud.trailingAnchor, constant: -14),
            hud.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            hud.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    func updateP2PHint(_ message: String) {
        guard let hud = view.viewWithTag(VisualizeRoomViewController.p2pHintTag) else {
            showP2PHint(message)
            return
        }
        (hud.subviews.first as? UILabel)?.text = message
    }

    func dismissP2PHint() {
        view.viewWithTag(VisualizeRoomViewController.p2pHintTag)?.removeFromSuperview()
    }

    // MARK: - Clear All

    func clearAllMeasurements() {
        removeBoundingBox()
        showBoundingBox = false
        updateButtonState(bboxButton, active: false)

        cancelPendingPointA()

        for anchor in measurementAnchors {
            arView.scene.removeAnchor(anchor)
        }
        measurementAnchors.removeAll()

        isPointToPointActive = false
        updateButtonState(p2pButton, active: false)
        dismissP2PHint()
    }

    // MARK: - Alert

    func showNeedModelAlert() {
        let alert = UIAlertController(
            title: "No Model Loaded",
            message: "Load a furniture model first to measure it.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - RealityKit Scene Raycast Convenience

extension RealityKit.Scene {
    /// Returns the first collision hit from a screen point in the given ARView.
    func firstRaycast(from screenPoint: CGPoint, in arView: ARView) -> CollisionCastHit? {
        guard let ray = arView.ray(through: screenPoint) else { return nil }
        return raycast(origin: ray.origin, direction: ray.direction).first
    }
}
