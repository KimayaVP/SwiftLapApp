//
//  Formatting.swift
//  Shared (iOS + watch)
//

import Foundation

/// Seconds → "m:ss" (e.g. 83.0 → "1:23"). Matches the web app's formatTime.
func formatLapTime(_ seconds: Double) -> String {
    let total = Int(seconds.rounded())
    return "\(total / 60):" + String(format: "%02d", total % 60)
}

let strokeOptions = ["Freestyle", "Backstroke", "Breaststroke", "Butterfly", "IM"]
let distanceOptions = [50, 100, 200, 400]
