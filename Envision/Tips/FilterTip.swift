//
//  FilterTip.swift
//  Envision
//
//  TipKit tip for filter chips functionality.
//  This tip helps users discover the filter functionality in list views.
//

import Foundation

#if canImport(TipKit)
import TipKit

/// Tip shown near filter chips to help users discover filtering functionality.
@available(iOS 17.0, *)
struct FilterTip: Tip {
    
    // MARK: - Tip Content
    
    var title: Text {
        Text("Filter Your Collection")
    }
    
    var message: Text? {
        Text("Use filters to quickly find rooms or furniture by category.")
    }
    
    var image: Image? {
        Image(systemName: "line.3.horizontal.decrease.circle")
    }
    
    // MARK: - Tip Options
    
    var options: [TipOption] {
        []
    }
}
#endif
