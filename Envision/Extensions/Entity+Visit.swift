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
