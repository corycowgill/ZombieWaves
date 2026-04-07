import SwiftUI

// MARK: - Color Palette

struct AshfallColors {
    static let background       = Color(red: 0.08, green: 0.07, blue: 0.06)
    static let surface          = Color(red: 0.13, green: 0.12, blue: 0.10)
    static let surfaceLight     = Color(red: 0.18, green: 0.16, blue: 0.14)
    static let accent           = Color(red: 0.86, green: 0.55, blue: 0.15)
    static let accentDim        = Color(red: 0.60, green: 0.38, blue: 0.10)
    static let danger           = Color(red: 0.78, green: 0.18, blue: 0.18)
    static let health           = Color(red: 0.30, green: 0.70, blue: 0.25)
    static let shield           = Color(red: 0.35, green: 0.55, blue: 0.80)
    static let textPrimary      = Color(red: 0.92, green: 0.89, blue: 0.82)
    static let textSecondary    = Color(red: 0.62, green: 0.58, blue: 0.52)
    static let textDim          = Color(red: 0.42, green: 0.39, blue: 0.35)
    static let ember            = Color(red: 0.95, green: 0.35, blue: 0.10)
    static let fog              = Color(red: 0.20, green: 0.22, blue: 0.25)
    static let gold             = Color(red: 0.90, green: 0.75, blue: 0.30)
    static let scrap            = Color(red: 0.55, green: 0.55, blue: 0.50)
    static let water            = Color(red: 0.30, green: 0.60, blue: 0.85)
    static let fuel             = Color(red: 0.70, green: 0.50, blue: 0.20)
    static let food             = Color(red: 0.50, green: 0.72, blue: 0.30)
    static let electronics      = Color(red: 0.45, green: 0.70, blue: 0.75)
    static let medicine         = Color(red: 0.80, green: 0.30, blue: 0.40)
    static let rankStarFilled   = Color(red: 0.95, green: 0.80, blue: 0.20)
    static let rankStarEmpty    = Color(red: 0.30, green: 0.28, blue: 0.25)
}

// MARK: - Font Styles

struct AshfallFonts {
    static func title(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .black, design: .serif)
    }

    static func heading(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func caption(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    static func mono(_ size: CGFloat = 14) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    static func stat(_ size: CGFloat = 18) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AshfallFonts.heading(18))
            .foregroundColor(AshfallColors.textPrimary)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isDestructive ? AshfallColors.danger : AshfallColors.accent)
                    .shadow(color: (isDestructive ? AshfallColors.danger : AshfallColors.accent).opacity(0.4),
                            radius: configuration.isPressed ? 2 : 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AshfallColors.textDim.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AshfallFonts.body(16))
            .foregroundColor(AshfallColors.accent)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(AshfallColors.accent.opacity(0.6), lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AshfallColors.surface.opacity(0.8))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(AshfallColors.textSecondary)
            .padding(10)
            .background(Circle().fill(AshfallColors.surfaceLight.opacity(0.6)))
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Common View Modifiers

struct AshfallCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AshfallColors.surface)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AshfallColors.surfaceLight, lineWidth: 0.5)
            )
    }
}

struct AshfallPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .modifier(AshfallCardModifier(cornerRadius: 12))
    }
}

extension View {
    func ashfallCard(cornerRadius: CGFloat = 10) -> some View {
        modifier(AshfallCardModifier(cornerRadius: cornerRadius))
    }

    func ashfallPanel() -> some View {
        modifier(AshfallPanelModifier())
    }

    func glowBorder(color: Color, radius: CGFloat = 6, lineWidth: CGFloat = 1.5) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: lineWidth)
                .shadow(color: color.opacity(0.5), radius: radius)
        )
    }
}

// MARK: - Theme Constants

struct AshfallTheme {
    static let screenPadding: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let sectionSpacing: CGFloat = 20
    static let iconSize: CGFloat = 24
    static let portraitSize: CGFloat = 80
    static let heroCardWidth: CGFloat = 160
    static let heroCardHeight: CGFloat = 200
    static let maxSquadSize: Int = 5
    static let animationStandard: Animation = .easeInOut(duration: 0.3)
    static let animationFast: Animation = .easeOut(duration: 0.15)
    static let animationSlow: Animation = .easeInOut(duration: 0.6)

    static let backgroundGradient = LinearGradient(
        colors: [AshfallColors.background, Color(red: 0.10, green: 0.08, blue: 0.06)],
        startPoint: .top,
        endPoint: .bottom
    )
}
