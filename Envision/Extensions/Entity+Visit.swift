//
//  Entity+Visit.swift
//  Envision
//
//  Created by user@78 on 22/11/25.
//

import Foundation
import RealityKit

extension Entity {
    func visit(_ block: (Entity) -> Void) {
        block(self)
        for child in children {
            child.visit(block)
        }
    }
}

// MARK: - USDZ Export Extension
extension ModelEntity {
    /// Export the entity as a USDZ file
    /// - Parameter url: The destination URL for the USDZ file
    func exportAsUSDZ(to url: URL) throws {
        // Use the built-in write method for USDZ export
        // Available in iOS 15+
        if #available(iOS 15.0, *) {
            // Create a semaphore to wait for async operation
            let semaphore = DispatchSemaphore(value: 0)
            var exportError: Error?
            
            Task {
                do {
                    try await self.write(to: url)
                } catch {
                    exportError = error
                }
                semaphore.signal()
            }
            
            semaphore.wait()
            
            if let error = exportError {
                throw error
            }
        } else {
            throw NSError(
                domain: "EnVision",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "USDZ export requires iOS 15 or later"]
            )
        }
    }
    
    /// Async version of USDZ export
    @available(iOS 15.0, *)
    func exportAsUSDZAsync(to url: URL) async throws {
        try await self.write(to: url)
    }
}
