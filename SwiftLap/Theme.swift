//
//  Theme.swift
//  SwiftLap (iOS)
//
//  "Deep Ocean" palette + reusable building blocks (brand gradient, tile,
//  button styles, brand wordmark). Keep visual choices here so screens stay
//  consistent and a future palette swap is a one-file change.
//

import SwiftUI

extension Color {
    /// #RRGGBB hex initializer.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    // Core palette
    static let navy    = Color(hex: 0x0A2540)   // deep navy — structure / headers
    static let teal    = Color(hex: 0x0AB6BC)   // primary accent
    static let aqua    = Color(hex: 0x1FD1B8)   // gradient end
    static let coral   = Color(hex: 0xFF6B5C)   // alerts / destructive / badges

    /// Single accent color for tints where a gradient can't be used.
    static let accent = teal

    /// Signature teal→aqua gradient used on primary buttons & tiles.
    static let gradient = LinearGradient(
        colors: [teal, aqua],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Soft tinted gradient for tile/card backgrounds.
    static let softGradient = LinearGradient(
        colors: [teal.opacity(0.16), aqua.opacity(0.10)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Brand wordmark (non-interactive logo for toolbars)

/// A small, clearly non-tappable brand lockup: a swimmer glyph + "SwiftLap".
/// Use in a topBarLeading toolbar slot so it reads as branding, not a button.
struct BrandMark: View {
    var role: String? = nil   // "swimmer" | "coach" → small caption under/after

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.pool.swim")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.teal)
            Text("SwiftLap")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.navy)
            if let role {
                Text(role == "coach" ? "Coach" : "Swimmer")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.teal.opacity(0.14)))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)   // not a button
    }
}

// MARK: - Button styles

/// Filled primary action — teal→aqua gradient, white label.
struct BrandPrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 14).padding(.horizontal, 18)
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Outlined secondary action — teal border, teal label.
struct BrandSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.teal)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 14).padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.teal.opacity(0.5), lineWidth: 1.5)
                    .background(Theme.teal.opacity(configuration.isPressed ? 0.10 : 0).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BrandPrimaryButtonStyle {
    static var brandPrimary: BrandPrimaryButtonStyle { BrandPrimaryButtonStyle() }
}
extension ButtonStyle where Self == BrandSecondaryButtonStyle {
    static var brandSecondary: BrandSecondaryButtonStyle { BrandSecondaryButtonStyle() }
}
