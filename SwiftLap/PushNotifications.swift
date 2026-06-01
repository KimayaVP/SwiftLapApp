//
//  PushNotifications.swift
//  SwiftLap (iOS)
//
//  Remote push (APNs). Complements LocalNotifications (on-device reminders):
//  this registers the device with Apple, hands the resulting device token to
//  the backend (/notifications/register-device), and shows banners while the
//  app is foregrounded. The backend pushes whenever it creates an in-app
//  notification, so the inbox and push stay in lockstep.
//

import UIKit
import UserNotifications

@MainActor
final class PushManager: NSObject, ObservableObject {
    static let shared = PushManager()

    // Latest APNs device token (hex), once Apple has issued one this launch.
    private var deviceToken: String?
    // Set once the user is signed in, so a token arriving later still gets sent.
    private var wantsRegistration = false

    /// Call after sign-in: ask permission (if needed) and register with APNs.
    func enable() {
        wantsRegistration = true
        Task {
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
            UIApplication.shared.registerForRemoteNotifications()
            // If a token from a previous launch is already in hand, send it now.
            if deviceToken != nil { await sendTokenToBackend() }
        }
    }

    /// Called by the app delegate when Apple returns a device token.
    func didRegister(deviceToken token: Data) {
        deviceToken = token.map { String(format: "%02x", $0) }.joined()
        if wantsRegistration {
            Task { await sendTokenToBackend() }
        }
    }

    /// Call on logout so this phone stops receiving the user's pushes.
    func disable() {
        wantsRegistration = false
        guard let token = deviceToken else { return }
        Task { try? await APIClient.shared.unregisterDevice(token: token) }
    }

    private func sendTokenToBackend() async {
        guard let token = deviceToken else { return }
        try? await APIClient.shared.registerDevice(token: token)
    }
}

// MARK: - App delegate (bridged into the SwiftUI app via UIApplicationDelegateAdaptor)

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushManager.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // No token this launch (e.g. no network / simulator). Push just won't fire.
    }

    // Show the banner + play sound even when the app is in the foreground.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}
