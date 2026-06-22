//
//  Extensions.swift
//  Pasty
//
//  Created by Devlomi on 14/07/2025.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let r, g, b: Double
        
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        switch hexSanitized.count {
        case 3: // RGB
            r = Double((rgb >> 8) & 0xF) / 15.0
            g = Double((rgb >> 4) & 0xF) / 15.0
            b = Double(rgb & 0xF) / 15.0
        case 6: // RRGGBB
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
        default:
            r = 0
            g = 0
            b = 0
        }

        self.init(red: r, green: g, blue: b)
    }
}

