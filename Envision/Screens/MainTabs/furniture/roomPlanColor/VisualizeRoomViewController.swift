import UIKit
import RealityKit
import ARKit
import UniformTypeIdentifiers

class VisualizeRoomViewController: UIViewController, UIDocumentPickerDelegate {

    let arView = ARView(frame: .zero)

    // MARK: - State Storage
    var selectedModel: ModelEntity?
    var showLabels = false   // start OFF
    var colorToggleIsOn = false  // start OFF

    var originalMaterials: [ModelEntity: [Material]] = [:]
    var labelStorage: [Entity: Entity] = [:] // Parent -> Label

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Room Geometry Playground"
        navigationController?.navigationBar.prefersLargeTitles = false

        view.addSubview(arView)
        arView.frame = view.bounds

        setupToggleUI()
        setupAR()
        setupTapGesture()
        presentModelPicker()
    }

    // ----------------------------------------------------------
    // MARK: - UI Switches
    // ----------------------------------------------------------
    func setupToggleUI() {

        // --- Label Switch ---
        let labelToggle = UISwitch()
        labelToggle.isOn = false
        labelToggle.translatesAutoresizingMaskIntoConstraints = false
        labelToggle.addTarget(self, action: #selector(toggleLabels(_:)), for: .valueChanged)

        let labelText = UILabel()
        labelText.text = "Show Labels"
        labelText.textColor = .white
        labelText.translatesAutoresizingMaskIntoConstraints = false

        // --- Color Switch ---
        let colorToggle = UISwitch()
        colorToggle.isOn = false
        colorToggle.translatesAutoresizingMaskIntoConstraints = false
        colorToggle.addTarget(self, action: #selector(toggleColors(_:)), for: .valueChanged)

        let colorText = UILabel()
        colorText.text = "Enable Colors"
        colorText.textColor = .white
        colorText.translatesAutoresizingMaskIntoConstraints = false

        // Add UI elements
        view.addSubview(labelToggle)
        view.addSubview(labelText)
        view.addSubview(colorToggle)
        view.addSubview(colorText)

        NSLayoutConstraint.activate([
            labelToggle.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            labelToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            labelText.centerYAnchor.constraint(equalTo: labelToggle.centerYAnchor),
            labelText.leadingAnchor.constraint(equalTo: labelToggle.trailingAnchor, constant: 10),

            colorToggle.topAnchor.constraint(equalTo: labelToggle.bottomAnchor, constant: 10),
            colorToggle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            colorText.centerYAnchor.constraint(equalTo: colorToggle.centerYAnchor),
            colorText.leadingAnchor.constraint(equalTo: colorToggle.trailingAnchor, constant: 10),
        ])
    }

    @objc func toggleLabels(_ sender: UISwitch) {
        showLabels = sender.isOn

        for (_, labelEntity) in labelStorage {
            labelEntity.isEnabled = showLabels
        }
    }

    @objc func toggleColors(_ sender: UISwitch) {
        colorToggleIsOn = sender.isOn

        // Reapply styling based on switch state
        arView.scene.anchors.first?.children.forEach { entity in
            applyMaterialRules(to: entity)
        }
    }

    // ----------------------------------------------------------
    // MARK: - Tap Gesture for Manual Coloring
    // ----------------------------------------------------------
    func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)

        if let result = arView.entity(at: location),
           let model = result as? ModelEntity {
            selectedModel = model
            presentColorPicker()
        }
    }

    func presentColorPicker() {
        let picker = UIColorPickerViewController()
        picker.delegate = self
        picker.supportsAlpha = true
        present(picker, animated: true)
    }

    // ----------------------------------------------------------
    // MARK: - AR Setup
    // ----------------------------------------------------------
    private func setupAR() {
        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .automatic
        arView.session.run(config)
    }

    // ----------------------------------------------------------
    // MARK: - File Picker
    // ----------------------------------------------------------
    func presentModelPicker() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.usdz, .realityFile], asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let pickedURL = urls.first else { return }
        loadModel(from: pickedURL)
    }

    // ----------------------------------------------------------
    // MARK: - Load + Add Model
    // ----------------------------------------------------------
    func loadModel(from url: URL) {
        do {
            let entity = try Entity.load(contentsOf: url)
            placeModel(entity)
        } catch {
            print("❌ Failed to load model:", error)
        }
    }

    func placeModel(_ room: Entity) {

        room.scale = [0.005, 0.005, 0.005]
        room.generateCollisionShapes(recursive: true)

        if let movable = room as? (Entity & HasCollision) {
            arView.installGestures([.scale, .rotation, .translation], for: movable)
        }

        applyMaterialRules(to: room)

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(room)
        arView.scene.addAnchor(anchor)
    }

    // ----------------------------------------------------------
    // MARK: - Material Logic (Color Toggle)
    // ----------------------------------------------------------
    func applyMaterialRules(to root: Entity) {

        root.visit { entity in
            guard let model = entity as? ModelEntity else { return }

            model.generateCollisionShapes(recursive: false)
            arView.installGestures([.translation, .rotation, .scale], for: model)

            let name = entity.name.lowercased()

            if originalMaterials[model] == nil {
                originalMaterials[model] = model.model?.materials ?? []
            }

            guard colorToggleIsOn else {
                if let original = originalMaterials[model] {
                    model.model?.materials = original
                }
                return
            }

            switch true {
            case name.starts(with: "wall"):
                model.model?.materials = [SimpleMaterial(color: .systemBlue, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 1.5)

            case name.starts(with: "floor"):
                model.model?.materials = [SimpleMaterial(color: .gray, roughness: 0.6, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.05)

            case name.starts(with: "chair"):
                model.model?.materials = [SimpleMaterial(color: .black, roughness: 0.4, isMetallic: false)]
                attachLabel(to: model, text: name, yOffset: 0.15)

            case name.starts(with: "table"):
                model.model?.materials = [SimpleMaterial(color: .systemPink, roughness: 0.4, isMetallic: true)]
                attachLabel(to: model, text: name, yOffset: 0.5)

            default: break
            }
        }
    }

    // ----------------------------------------------------------
    // MARK: - Labels
    // ----------------------------------------------------------
    func attachLabel(to entity: Entity, text: String, yOffset: Float) {

        labelStorage[entity]?.removeFromParent()

        let mesh = MeshResource.generateText(text, extrusionDepth: 0.01, font: .systemFont(ofSize: 0.15))
        let labelEntity = ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .white, isMetallic: false)])

        labelEntity.position = [0, yOffset, 0]
        labelEntity.components.set(BillboardComponent())
        labelEntity.isEnabled = showLabels

        entity.addChild(labelEntity)
        labelStorage[entity] = labelEntity
    }
}

// --------------------------------------------------------------
// MARK: - Color Picker Override
// --------------------------------------------------------------
extension VisualizeRoomViewController: UIColorPickerViewControllerDelegate {

    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        guard let selectedModel = selectedModel else { return }

        selectedModel.model?.materials = [
            SimpleMaterial(color: viewController.selectedColor, roughness: 0.4, isMetallic: false)
        ]
    }
}
