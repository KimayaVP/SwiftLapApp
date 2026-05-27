//
//  LocalNotifications.swift
//  SwiftLap (iOS)
//
//  On-device notifications scheduled by the app itself (no server / Apple Push
//  needed — these work even on a free Personal Team). Currently used to remind
//  the swimmer to log their times the morning after an upcoming meet.
//

import Foundation
import UserNotifications

enum LocalNotifications {
    /// Ask the user for permission to show notifications. Safe to call repeatedly.
    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Schedule a reminder for ~9am the day AFTER a meet to log the actual times.
    /// Identifier is keyed by meetId so re-creating doesn't duplicate it.
    static func scheduleMeetLogReminder(meetName: String, meetDate: Date, meetId: String) {
        let cal = Calendar.current
        guard let dayAfter = cal.date(byAdding: .day, value: 1, to: meetDate) else { return }
        var comps = cal.dateComponents([.year, .month, .day], from: dayAfter)
        comps.hour = 9

        // Don't schedule something already in the past.
        if let fireDate = cal.date(from: comps), fireDate < Date() { return }

        let content = UNMutableNotificationContent()
        content.title = "Log your times 🏊"
        content.body = "How did \(meetName) go? Tap to log your race times."
        content.sound = .default
        content.userInfo = ["meetId": meetId]

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "meet-\(meetId)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    /// Cancel a meet reminder (e.g. once all its events have been logged).
    static func cancelMeetLogReminder(meetId: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["meet-\(meetId)"])
    }
}
