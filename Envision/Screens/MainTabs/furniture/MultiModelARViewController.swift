//
//  MultiModelARViewController.swift
//  Envision
//
//  Created by admin55 on 26/11/25.
//


import UIKit
import RealityKit
import ARKit

class MultiModelARViewController: UIViewController {

    let arView = ARView(frame: .zero)
    var currentAnchors: [AnchorEntity] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupAR()
        setupAddButton()
    }

    private func setupAR() {
        view.addSubview(arView)
        arView.frame = view.bounds
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)
//        arView.debugOptions = [.showFeaturePoints, .showWorldOrigin, .showAnchorGeometry]
    }

    private func setupAddButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        button.tintColor = .systemBlue
        button.backgroundColor = .systemBackground.withAlphaComponent(0.9)
        
        button.layer.cornerRadius = 27
        button.clipsToBounds = true

        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            button.widthAnchor.constraint(equalToConstant: 55),
            button.heightAnchor.constraint(equalToConstant: 55)
        ])
        
        button.addTarget(self, action: #selector(addModel), for: .touchUpInside)
    }


    @objc private func addModel() {
        // Example — you would present your library UI here
        loadModel(named: "chair")
    }

    func loadModel(named name: String) {
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("furniture/\(name).usdz")

        do {
            let modelEntity = try ModelEntity.loadModel(contentsOf: fileURL)
            let anchor = AnchorEntity(plane: .horizontal)
            anchor.addChild(modelEntity)
            arView.scene.addAnchor(anchor)
            currentAnchors.append(anchor)
        } catch {
            print("Failed: \(error)")
        }
    }
}
