import UIKit
import RealityKit
import ARKit

class RoomARViewController1: UIViewController {

    let arView = ARView(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(arView)
        arView.frame = view.bounds

        setupAR()
    }

    private func setupAR() {
        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .automatic
        arView.session.run(config)

        // Load room model
        guard let room = try? Entity.load(named: "ios_room") else {
            print("❌ Could not load ios_room.usdz")
            return
        }

        // Resize model
        room.scale = [0.02, 0.02, 0.02]

        // Collision shapes
        room.generateCollisionShapes(recursive: true)

        // Install gestures
        if let collisionEntity = room as? (Entity & HasCollision) {
            arView.installGestures([.scale, .rotation, .translation], for: collisionEntity)
        } else {
            room.visit { entity in
                if let model = entity as? (Entity & HasCollision) {
                    arView.installGestures([.scale, .rotation, .translation], for: model)
                }
            }
        }

        printEntities(room)

        // Apply materials
        room.visit { entity in
            
            let name = entity.name.lowercased()

            if name.starts(with: "wall"),
               let model = entity as? ModelEntity {
                model.model?.materials = [SimpleMaterial(color: .systemBlue, roughness: 0.4, isMetallic: false)]
            }

            if name.starts(with: "floor"),
               let model = entity as? ModelEntity {
                model.model?.materials = [SimpleMaterial(color: .gray, roughness: 0.6, isMetallic: false)]
            }

            if name.starts(with: "chair"),
               let model = entity as? ModelEntity {
                model.model?.materials = [SimpleMaterial(color: .black, roughness: 0.4, isMetallic: false)]
            }

            if name.starts(with: "table"),
               let model = entity as? ModelEntity {
                model.model?.materials = [SimpleMaterial(color: .systemPink, roughness: 0.4, isMetallic: false)]
            }
        }

        // Add room to anchor
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(room)
        arView.scene.anchors.append(anchor)
    }

    // Debug print
    func printEntities(_ entity: Entity) {
        print("ENTITY:", entity.name)
        entity.children.forEach { printEntities($0) }
    }
}

