//
//  RoomViewerViewController.swift
//  Envision
//

import UIKit
import SceneKit
import ARKit

enum ViewerMode {
    case object
    case ar
}

final class RoomViewerViewController: UIViewController {

    // MARK: - Inputs

    private let roomURL: URL
    private var viewerMode: ViewerMode

    // MARK: - Scene Views

    private let scnView = SCNView()
    private let arView  = ARSCNView()

    private var roomScene: SCNScene?
    private var placedFurniture: [SCNNode] = []

    // MARK: - UI Controls

    private let closeButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    private let modeToggle   = UISegmentedControl(items: ["AR", "Object"])
    private let addFurnitureButton = UIButton(type: .system)

    // MARK: - Init

    init(roomURL: URL, mode: ViewerMode = .object) {
        self.roomURL = roomURL
        self.viewerMode = mode
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        setupSceneViews()
        setupChrome()
        loadRoomScene()
        applyInitialMode()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        arView.session.pause()
    }

    // MARK: - Scene Setup

    private func setupSceneViews() {
        scnView.translatesAutoresizingMaskIntoConstraints = false
        arView.translatesAutoresizingMaskIntoConstraints  = false

        scnView.backgroundColor = .systemBackground
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = false  // DISABLED to allow our gestures to work

        arView.backgroundColor = .clear
        arView.autoenablesDefaultLighting = false
        arView.automaticallyUpdatesLighting = true

        // Add gesture recognizers for interactivity in Object mode
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 1
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationGesture.delegate = self
        
        // Two-finger pan for camera rotation
        let cameraPan = UIPanGestureRecognizer(target: self, action: #selector(handleCameraPan(_:)))
        cameraPan.minimumNumberOfTouches = 2
        cameraPan.maximumNumberOfTouches = 2
        cameraPan.delegate = self
        
        scnView.addGestureRecognizer(panGesture)
        scnView.addGestureRecognizer(pinchGesture)
        scnView.addGestureRecognizer(rotationGesture)
        scnView.addGestureRecognizer(cameraPan)
        
        // Add gesture recognizers for AR mode as well
        let arPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleARPan(_:)))
        arPanGesture.delegate = self
        
        let arPinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handleARPinch(_:)))
        arPinchGesture.delegate = self
        
        let arRotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleARRotation(_:)))
        arRotationGesture.delegate = self
        
        arView.addGestureRecognizer(arPanGesture)
        arView.addGestureRecognizer(arPinchGesture)
        arView.addGestureRecognizer(arRotationGesture)

        view.addSubview(scnView)
        view.addSubview(arView)

        NSLayoutConstraint.activate([
            scnView.topAnchor.constraint(equalTo: view.topAnchor),
            scnView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scnView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scnView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - UI Chrome

    private func setupChrome() {

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .label
        closeButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        closeButton.layer.cornerRadius = 22
        closeButton.contentEdgeInsets = .init(top: 10, left: 10, bottom: 10, right: 10)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        exportButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        exportButton.tintColor = .label
        exportButton.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        exportButton.layer.cornerRadius = 22
        exportButton.contentEdgeInsets = .init(top: 10, left: 10, bottom: 10, right: 10)
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)

        // Segmented toggle
        modeToggle.backgroundColor = UIColor.label.withAlphaComponent(0.1)
        modeToggle.selectedSegmentTintColor = .white
        modeToggle.setTitleTextAttributes([.foregroundColor: UIColor.label], for: .selected)
        modeToggle.setTitleTextAttributes([.foregroundColor: UIColor.label.withAlphaComponent(0.7)], for: .normal)
        modeToggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)

        // + button
        addFurnitureButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addFurnitureButton.tintColor = .white
        addFurnitureButton.backgroundColor = UIColor.label.withAlphaComponent(0.9)
        addFurnitureButton.layer.cornerRadius = 28
        addFurnitureButton.addTarget(self, action: #selector(addFurnitureTapped), for: .touchUpInside)

        [closeButton, exportButton, modeToggle, addFurnitureButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([

            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            exportButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            exportButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            modeToggle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeToggle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            modeToggle.widthAnchor.constraint(equalToConstant: 210),

            addFurnitureButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            addFurnitureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            addFurnitureButton.widthAnchor.constraint(equalToConstant: 56),
            addFurnitureButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    // MARK: - Room Scene Loading

    private func loadRoomScene() {
        print("🔍 DEBUG: Loading room from: \(roomURL.lastPathComponent)")
        do {
            let scene = try SCNScene(url: roomURL, options: nil)
            roomScene = scene
            scnView.scene = scene

            // Enable interactivity for the room model itself
            enableInteractivityForRoomModel(scene.rootNode)

            // Lighting
            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.intensity = 900
            scene.rootNode.addChildNode(ambient)

            let directional = SCNNode()
            directional.light = SCNLight()
            directional.light?.type = .directional
            directional.light?.intensity = 1200
            directional.eulerAngles = SCNVector3(Float(-Double.pi/3), Float(Double.pi/4), 0)
            scene.rootNode.addChildNode(directional)

            // Camera
            if scnView.pointOfView == nil {
                let cameraNode = SCNNode()
                cameraNode.camera = SCNCamera()
                cameraNode.position = SCNVector3(0, 2.0, 4.0)
                scene.rootNode.addChildNode(cameraNode)
                scnView.pointOfView = cameraNode
            }

        } catch {
            print("❌ Failed to load room scene:", error)
        }
    }
    
    // Enable interactivity for room model parts
    private func enableInteractivityForRoomModel(_ node: SCNNode) {
        print("🔍 DEBUG: Enabling interactivity for room model")
        var geometryCount = 0
        
        // Also check if root node has geometry
        if node.geometry != nil {
            print("  ⚠️ Root node itself has geometry!")
            node.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
            if node.name == nil || node.name!.isEmpty {
                node.name = "room_part"
            }
            print("  ✅ Root node tagged as: '\(node.name ?? "unnamed")'")
            geometryCount += 1
        }
        
        node.enumerateChildNodes { childNode, _ in
            if childNode.geometry != nil {
                geometryCount += 1
                childNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
                
                // Keep original name from RoomPlan (Chair0, Wall1, Floor0, etc.)
                // No need to rename - we'll detect by pattern matching
                print("  ✅ Node: '\(childNode.name ?? "unnamed")' - Geometry: YES - Physics: YES")
            } else {
                print("  ⚠️ Skipped (no geometry): '\(childNode.name ?? "unnamed")'")
            }
        }
        
        print("🔍 DEBUG: Total geometry nodes found: \(geometryCount)")
    }
    
    // Helper function to check if a node is interactable
    private func isNodeInteractable(_ nodeName: String) -> Bool {
        // Check for custom tagged furniture
        if nodeName == "interactable_furniture" || nodeName == "room_part" {
            return true
        }
        
        // Check for RoomPlan parametric names
        let roomPlanTypes = ["Wall", "Floor", "Chair", "Table", "Storage", "Sink",
                            "Refrigerator", "Door", "Window", "Opening", "Ceiling"]
        for type in roomPlanTypes {
            if nodeName.contains(type) {
                return true
            }
        }
        
        // Check for generic room terms
        if nodeName.lowercased().contains("room") ||
           nodeName.lowercased().contains("wall") ||
           nodeName.lowercased().contains("floor") {
            return true
        }
        
        return false
    }

    // MARK: - Mode Handling

    private func applyInitialMode() {
        if viewerMode == .ar {
            modeToggle.selectedSegmentIndex = 0
            switchToARMode()
        } else {
            modeToggle.selectedSegmentIndex = 1
            switchToObjectMode()
        }
    }

    private func switchToObjectMode() {
        arView.isHidden = true
        scnView.isHidden = false
        arView.session.pause()
    }

    private func switchToARMode() {
        scnView.isHidden = true
        arView.isHidden = false

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        arView.scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }

        if let scene = roomScene {
            let clone = scene.rootNode.clone()

            // Reposition far enough
            clone.position = SCNVector3(0, -0.1, -2.0)

            // Scale down slightly (room models can be tall)
            clone.scale = SCNVector3(0.8, 0.8, 0.8)
            
            // The room_container should already be cloned, just make sure it's interactable
            if let roomContainer = clone.childNode(withName: "room_container", recursively: false) {
                roomContainer.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
                print("✅ Room container found and made interactable in AR")
            }

            arView.scene.rootNode.addChildNode(clone)
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func exportTapped() {
        let alert = UIAlertController(title: "Export Room", message: "Save or share your decorated room", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Export Room File", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let picker = UIDocumentPickerViewController(forExporting: [self.roomURL])
            self.present(picker, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Share Room", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let activityVC = UIActivityViewController(activityItems: [self.roomURL], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.exportButton
                popover.sourceRect = self.exportButton.bounds
            }
            self.present(activityVC, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Save Screenshot", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let renderer = UIGraphicsImageRenderer(bounds: self.scnView.bounds)
            let screenshot = renderer.image { _ in
                self.scnView.drawHierarchy(in: self.scnView.bounds, afterScreenUpdates: true)
            }
            UIImageWriteToSavedPhotosAlbum(screenshot, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = exportButton
            popover.sourceRect = exportButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        let alert: UIAlertController
        if let error = error {
            alert = UIAlertController(title: "Save Error", message: error.localizedDescription, preferredStyle: .alert)
        } else {
            alert = UIAlertController(title: "Saved!", message: "Screenshot saved to Photos", preferredStyle: .alert)
        }
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func toggleChanged() {
        viewerMode = modeToggle.selectedSegmentIndex == 0 ? .ar : .object
        viewerMode == .ar ? switchToARMode() : switchToObjectMode()
    }

    @objc private func addFurnitureTapped() {
        let picker = FurniturePickerViewController()
        picker.onModelSelected = { [weak self] url in
            self?.insertFurniture(url: url)
        }

        let nav = UINavigationController(rootViewController: picker)
        nav.modalPresentationStyle = .pageSheet
        nav.sheetPresentationController?.detents = [.medium(), .large()]
        present(nav, animated: true)
    }

    // MARK: - Furniture Insertion

    private func insertFurniture(url: URL) {
        guard let furnitureScene = try? SCNScene(url: url, options: nil) else { return }

        let node = furnitureScene.rootNode.clone()
        node.scale = SCNVector3(0.5, 0.5, 0.5)

        switch viewerMode {
        case .object:
            node.position = SCNVector3(0, 0, 0)
            scnView.scene?.rootNode.addChildNode(node)
        case .ar:
            node.position = SCNVector3(0, 0, -0.6)
            arView.scene.rootNode.addChildNode(node)
        }

        placedFurniture.append(node)
        
        // Enable interactivity for the furniture
        enableInteractivity(for: node)
    }
    
    // MARK: - Interactivity Setup
    
    private func enableInteractivity(for node: SCNNode) {
        // Add physics body to make node interactive
        node.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
        node.name = "interactable_furniture"
        
        // Enable interactivity for all child nodes
        node.enumerateChildNodes { childNode, _ in
            if childNode.geometry != nil {
                childNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
                childNode.name = "interactable_furniture"
            }
        }
    }
    
    // MARK: - Gesture Handlers (Object Mode)
    
    private var selectedNode: SCNNode?
    private var lastPanPoint: CGPoint = .zero
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: scnView)
        
        if gesture.state == .began {
            let hitResults = scnView.hitTest(location, options: [:])
            print("🎯 Pan began - Hit results count: \(hitResults.count)")
            
            // Log all hit nodes
            for (index, result) in hitResults.enumerated() {
                print("  Hit \(index): '\(result.node.name ?? "unnamed")' - Has geometry: \(result.node.geometry != nil)")
            }
            
            // Find first interactable node
            if let result = hitResults.first(where: { isNodeInteractable($0.node.name ?? "") }) {
                selectedNode = findParentFurnitureNode(result.node)
                lastPanPoint = location
                print("  ✅ Selected node: '\(result.node.name ?? "unnamed")' for interaction!")
            } else {
                print("  ❌ No interactable node found")
            }
        } else if gesture.state == .changed, let selected = selectedNode {
            let translation = gesture.translation(in: scnView)
            
            // Move in XZ plane (horizontal)
            let moveScale: Float = 0.01
            selected.position.x += Float(translation.x) * moveScale
            selected.position.z -= Float(translation.y) * moveScale
            
            gesture.setTranslation(.zero, in: scnView)
        } else if gesture.state == .ended {
            selectedNode = nil
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed || gesture.state == .began else { return }
        
        let location = gesture.location(in: scnView)
        let hitResults = scnView.hitTest(location, options: [:])
        
        if let result = hitResults.first(where: { isNodeInteractable($0.node.name ?? "") }) {
            let node = findParentFurnitureNode(result.node)
            let scale = Float(gesture.scale)
            node.scale = SCNVector3(
                node.scale.x * scale,
                node.scale.y * scale,
                node.scale.z * scale
            )
            gesture.scale = 1.0
            print("  📏 Scaling node: \(node.scale)")
        }
    }
    
    // Camera pan gesture for two-finger movement
    @objc private func handleCameraPan(_ gesture: UIPanGestureRecognizer) {
        guard let camera = scnView.pointOfView else { return }
        
        if gesture.state == .changed {
            let translation = gesture.translation(in: scnView)
            
            // Rotate camera around the scene
            let rotationScale: Float = 0.005
            camera.eulerAngles.y -= Float(translation.x) * rotationScale
            camera.eulerAngles.x -= Float(translation.y) * rotationScale
            
            // Clamp vertical rotation to avoid flipping
            camera.eulerAngles.x = max(-Float.pi/2, min(Float.pi/2, camera.eulerAngles.x))
            
            gesture.setTranslation(.zero, in: scnView)
        }
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        let location = gesture.location(in: scnView)
        
        if gesture.state == .began {
            let hitResults = scnView.hitTest(location, options: [:])
            print("🔄 Rotation began - Hit results: \(hitResults.count)")
            
            if let result = hitResults.first(where: { isNodeInteractable($0.node.name ?? "") }) {
                selectedNode = findParentFurnitureNode(result.node)
                print("  ✅ Node selected for rotation: '\(result.node.name ?? "unnamed")'")
            } else {
                print("  ❌ No node found for rotation")
            }
        } else if gesture.state == .changed, let selected = selectedNode {
            selected.eulerAngles.y -= Float(gesture.rotation)
            gesture.rotation = 0
            print("  🔄 Rotating: \(selected.eulerAngles.y)")
        } else if gesture.state == .ended {
            print("  ✅ Rotation ended")
            selectedNode = nil
        }
    }
    
    private func findParentFurnitureNode(_ node: SCNNode) -> SCNNode {
        var current = node
        while let parent = current.parent, !placedFurniture.contains(parent) && parent != scnView.scene?.rootNode {
            current = parent
        }
        // If we found a placed furniture node, return it; otherwise return the original
        if placedFurniture.contains(current) {
            return current
        }
        // Check if any parent is in placedFurniture
        var checkNode = node
        while let parent = checkNode.parent {
            if placedFurniture.contains(parent) {
                return parent
            }
            checkNode = parent
        }
        return node
    }
    
    // MARK: - AR Gesture Handlers
    
    private var selectedARNode: SCNNode?
    
    @objc private func handleARPan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: arView)
        
        if gesture.state == .began {
            let hitResults = arView.hitTest(location, options: [:])
            if let result = hitResults.first(where: { isNodeInteractable($0.node.name ?? "") }) {
                selectedARNode = findARParentNode(result.node)
            }
        } else if gesture.state == .changed, let selected = selectedARNode {
            let translation = gesture.translation(in: arView)
            
            // Move in XZ plane (horizontal)
            let moveScale: Float = 0.001
            selected.position.x += Float(translation.x) * moveScale
            selected.position.z -= Float(translation.y) * moveScale
            
            gesture.setTranslation(.zero, in: arView)
        } else if gesture.state == .ended {
            selectedARNode = nil
        }
    }
    
    @objc private func handleARPinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .changed || gesture.state == .began else { return }
        
        let location = gesture.location(in: arView)
        let hitResults = arView.hitTest(location, options: [:])
        
        if let result = hitResults.first(where: { isNodeInteractable($0.node.name ?? "") }) {
            let node = findARParentNode(result.node)
            let scale = Float(gesture.scale)
            node.scale = SCNVector3(
                node.scale.x * scale,
                node.scale.y * scale,
                node.scale.z * scale
            )
            gesture.scale = 1.0
        }
    }
    
    @objc private func handleARRotation(_ gesture: UIRotationGestureRecognizer) {
        guard gesture.state == .began || gesture.state == .changed else { return }
        
        let location = gesture.location(in: arView)
        let hitResults = arView.hitTest(location, options: [:])
        
        if let result = hitResults.first(where: { isNodeInteractable($0.node.name ?? "") }) {
            let node = findARParentNode(result.node)
            node.eulerAngles.y -= Float(gesture.rotation)
            gesture.rotation = 0
        }
    }
    
    private func findARParentNode(_ node: SCNNode) -> SCNNode {
        // For furniture, find the parent in placedFurniture array
        var current = node
        while let parent = current.parent {
            if placedFurniture.contains(parent) {
                return parent
            }
            // For room model, if we reach a node that's a direct child of scene root, return it
            if parent.parent == arView.scene.rootNode {
                return parent
            }
            current = parent
        }
        return node
    }
}

// MARK: - UIGestureRecognizerDelegate
extension RoomViewerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow gestures to work simultaneously (pinch + rotate, etc.)
        return true
    }
}
