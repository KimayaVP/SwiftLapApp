//
//  BiometricStore.swift
//  SwiftLap (iOS)
//
//  Face ID / Touch ID "login" support. Biometrics aren't an identity provider —
//  they unlock a session that a *real* login (email / Google / Apple) already
//  established on this device. We stash the Supabase access + refresh tokens in
//  the Keychain, protected so the item can only be read after a successful face/
//  touch match, then exchange them for a fresh session on unlock.
//

import Foundation
import LocalAuthentication

enum Biometrics {
    /// Whether this device can do Face ID / Touch ID right now (hardware present
    /// + a face/finger enrolled).
    static func isAvailable() -> Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// "Face ID" / "Touch ID" / "Biometrics" for use in UI copy.
    static func typeName() -> String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }

    static func symbolName() -> String {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType == .touchID ? "touchid" : "faceid"
    }
}

/// Keychain-backed store for the session tokens, gated behind biometrics.
enum BiometricStore {
    private static let service = "com.swiftlap.ios.biometric"
    private static let account = "session"

    struct Tokens: Codable { let accessToken: String; let refreshToken: String }

    /// Is there a biometric-protected session saved on this device?
    static func hasSavedSession() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            // Don't prompt for biometrics just to check existence.
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    /// Saves (or replaces) the tokens behind a biometric access-control rule.
    /// `.biometryCurrentSet` means the item is auto-invalidated if the user adds/
    /// changes a face/finger — a safe default that re-prompts a real login.
    @discardableResult
    static func save(accessToken: String, refreshToken: String) -> Bool {
        guard let data = try? JSONEncoder().encode(Tokens(accessToken: accessToken, refreshToken: refreshToken)) else { return false }
        guard let access = SecAccessControlCreateWithFlags(
            nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, .biometryCurrentSet, nil
        ) else { return false }

        // Remove any existing item first.
        clear()

        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: access,
        ]
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    /// Reads the tokens — triggers the Face ID / Touch ID prompt. Returns nil on
    /// cancel / failure / missing item.
    static func read(reason: String) -> Tokens? {
        let ctx = LAContext()
        ctx.localizedReason = reason
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseOperationPrompt as String: reason,
            kSecUseAuthenticationContext as String: ctx,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let tokens = try? JSONDecoder().decode(Tokens.self, from: data) else { return nil }
        return tokens
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
