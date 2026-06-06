//
//  BiometricLockView.swift
//  SwiftLap (iOS)
//
//  Shown on launch when biometric login is on and a saved session exists.
//  Unlocks with Face ID / Touch ID, or drops back to the normal sign-in.
//

import SwiftUI

struct BiometricLockView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var working = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(Theme.softGradient).frame(width: 110, height: 110)
                Image(systemName: Biometrics.symbolName())
                    .font(.system(size: 52, weight: .regular))
                    .foregroundStyle(Theme.teal)
            }
            Text("SwiftLap")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.navy)
            Text("Locked — unlock with \(auth.biometricTypeName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let err = auth.biometricError {
                Text(err).font(.caption).foregroundStyle(Theme.coral).multilineTextAlignment(.center)
            }
            Spacer()

            Button {
                Task { working = true; await auth.unlockWithBiometrics(); working = false }
            } label: {
                if working { ProgressView().tint(.white) }
                else { Label("Unlock with \(auth.biometricTypeName)", systemImage: Biometrics.symbolName()) }
            }
            .buttonStyle(.brandPrimary)
            .disabled(working)

            Button("Use email, Google or Apple instead") {
                auth.useAnotherSignIn()
            }
            .font(.subheadline)
            .foregroundStyle(Theme.teal)
            .padding(.bottom, 8)
        }
        .padding(24)
        .task {
            // Offer the prompt automatically on appear.
            working = true; await auth.unlockWithBiometrics(); working = false
        }
    }
}
