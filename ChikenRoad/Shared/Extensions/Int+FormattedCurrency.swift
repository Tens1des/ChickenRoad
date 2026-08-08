//
//  Int+FormattedCurrency.swift
//  ChikenRoad
//

import Foundation

extension Int {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
