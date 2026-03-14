//
//  Item.swift
//  intelligence-picture-books
//
//  Created by 渡辺海星 on 2026/03/15.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
