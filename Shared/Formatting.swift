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

/// Distance choices for a stroke. 25/50/100/200 for every stroke; Freestyle also
/// offers the distance events 400/800/1500. Mirrors web + Android `distancesFor`.
private let baseDistances = [25, 50, 100, 200]
private let freestyleExtra = [400, 800, 1500]
func distancesFor(_ stroke: String) -> [Int] {
    stroke == "Freestyle" ? baseDistances + freestyleExtra : baseDistances
}

/// Full superset (used where a stroke isn't in scope).
let distanceOptions = distancesFor("Freestyle")
