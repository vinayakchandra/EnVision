import UIKit
import RealityKit
import ARKit

// colored geometry + changed table and chair
final class RoomARWithFurnitureViewController: UIViewController {

    private var arView: ARView!
    private var loadingView: UIView!
    private var loadingLabel: UILabel!


    override func viewDidLoad() {
        super.viewDidLoad()
        setupARView()
        showLoadingView()
        loadRoomScene()
    }

    private func setupARView() {
        view.backgroundColor = .black

        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)

        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .automatic
        arView.session.run(config)
    }

    private func loadRoomScene() {

        guard let room = try? Entity.load(named: "ios_room") else {
            print("❌ Could not load ios_room.usdz")
            return
        }

        // Scale whole room model
        room.scale = [0.01, 0.01, 0.01]

        // Enable collisions + gestures
        room.generateCollisionShapes(recursive: true)

        room.visit { entity in
            if let model = entity as? ModelEntity {
                arView.installGestures([.scale, .rotation, .translation], for: model)
            }
        }

        // Print hierarchy
        printEntities(room)

        // Replace chairs + tables
        replaceEntities(prefix: "chair", in: room, with: "chair", scale: [1,1,1])
        replaceEntities(prefix: "table", in: room, with: "table", scale: [0.015, 0.005, 0.015])

        // Apply colors + floating labels
        room.visit { entity in
            let name = entity.name.lowercased()

            if let model = entity as? ModelEntity {
                if name.starts(with: "wall") {
                    model.model?.materials = [SimpleMaterial(color: .systemBlue, roughness: 0.4, isMetallic: false)]
                    attachLabel(to: model, text: name, yOffset: 1.5)
                }

                if name.starts(with: "floor") {
                    model.model?.materials = [SimpleMaterial(color: .gray, roughness: 0.6, isMetallic: false)]
                    attachLabel(to: model, text: name, yOffset: 0.05)
                }

                if name.starts(with: "chair") {
                    model.model?.materials = [SimpleMaterial(color: .black, roughness: 0.4, isMetallic: false)]
                    attachLabel(to: model, text: name, yOffset: 0.15)
                }

                if name.starts(with: "table") {
                    model.model?.materials = [SimpleMaterial(color: .systemPink, roughness: 0.4, isMetallic: true)]
                    attachLabel(to: model, text: name, yOffset: 0.5)
                }
            }
        }

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(room)
        arView.scene.anchors.append(anchor)

        DispatchQueue.main.async {
            self.hideLoadingView()
        }

    }
 
    private func printEntities(_ entity: Entity) {
        print("ENTITY:", entity.name)
        entity.children.forEach { printEntities($0) }
    }
    
    private func showLoadingView() {
        loadingView = UIView(frame: view.bounds)
        loadingView.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        loadingLabel = UILabel()
        loadingLabel.text = "Loading Room..."
        loadingLabel.textColor = .white
        loadingLabel.font = .systemFont(ofSize: 18, weight: .medium)
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false

        loadingView.addSubview(spinner)
        loadingView.addSubview(loadingLabel)
        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loadingView.centerYAnchor, constant: -20),

            loadingLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12),
            loadingLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor)
        ])
    }

    private func hideLoadingView() {
        UIView.animate(withDuration: 0.25, animations: {
            self.loadingView.alpha = 0
        }) { _ in
            self.loadingView.removeFromSuperview()
            self.loadingView = nil
        }
    }

}

// Floating label
func attachLabel(to entity: Entity, text: String, yOffset: Float = 0.1) {
    let mesh = MeshResource.generateText(
        text,
        extrusionDepth: 0.01,
        font: .systemFont(ofSize: 0.15),
        containerFrame: .zero,
        alignment: .center,
        lineBreakMode: .byWordWrapping
    )

    let material = SimpleMaterial(color: .white, isMetallic: false)
    let textEntity = ModelEntity(mesh: mesh, materials: [material])

    textEntity.position = [0, yOffset, 0]
    textEntity.components.set(BillboardComponent())

    entity.addChild(textEntity)
}

// Replacement logic
func replaceEntities(prefix: String, in root: Entity, with modelName: String, scale: SIMD3<Float>) {
    root.visit { entity in
        let name = entity.name.lowercased()
        if name.range(of: "^" + prefix + "[0-9]+$", options: .regularExpression) != nil,
           let parent = entity.parent {

            let originalTransform = entity.transformMatrix(relativeTo: parent)

            guard let newModel = try? Entity.load(named: modelName) else {
                print("❌ Failed to load:", modelName)
                return
            }

            newModel.transform = Transform(matrix: originalTransform)
            newModel.scale *= scale
            newModel.generateCollisionShapes(recursive: true)

            entity.removeFromParent()
            parent.addChild(newModel)
        }
    }
}
