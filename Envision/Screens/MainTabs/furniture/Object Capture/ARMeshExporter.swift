//
//  ARMeshExporter.swift
//  Envision
//
//  Created by user@78 on 22/11/25.
//


//
//  ARMeshExporter.swift
//  Envision
//

import ARKit
import ModelIO

final class ARMeshExporter {

    func export(meshAnchors: [ARMeshAnchor]) -> URL? {
        let asset = MDLAsset()

        for anchor in meshAnchors {
            let mesh = anchor.geometry
            let mdlMesh = MDLMesh()
            asset.add(mdlMesh)
        }

        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scan_\(UUID().uuidString).usdz")

        do {
            try asset.export(to: url)
            return url
        } catch {
            print("Export failed:", error)
            return nil
        }
    }
}
