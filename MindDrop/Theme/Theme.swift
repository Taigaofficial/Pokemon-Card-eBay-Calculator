import SwiftUI

/// Central design tokens for the whole app. Views never hard-code colors —
/// they read them from `Theme.current`. To try a new look, point `current`
/// at a different palette (or edit one) and every screen updates.
struct Theme {
    var accent: Color
    var recording: Color
    var background: Color
    /// Ambient glow washes behind the content (near-transparent radial
    /// gradients); use `.clear` to disable.
    var glowPrimary: Color
    var glowSecondary: Color
    var cardFill: Color
    var cardBorder: Color
    /// Timestamps, folder names, section headers.
    var metaText: Color
    /// The "Action Items" label inside an expanded card.
    var actionHeader: Color
    /// The check circles next to action items.
    var checkmark: Color
    var categoryColors: [String: Color]
    var categoryFallback: Color

    func color(forCategory category: String) -> Color {
        categoryColors[category] ?? categoryFallback
    }

    /// The active theme.
    static let current = aurora

    /// Near-black with a violet glow top-left, amber glow bottom-right,
    /// warm amber accent, teal metadata, and glassy separated cards.
    static let aurora = Theme(
        accent: Color(red: 0.96, green: 0.73, blue: 0.26),
        recording: .red,
        background: Color(red: 0.02, green: 0.02, blue: 0.035),
        glowPrimary: Color(red: 0.47, green: 0.30, blue: 0.85),
        glowSecondary: Color(red: 0.92, green: 0.53, blue: 0.18),
        cardFill: Color.white.opacity(0.055),
        cardBorder: Color.white.opacity(0.09),
        metaText: Color(red: 0.45, green: 0.77, blue: 0.71),
        actionHeader: Color(red: 0.95, green: 0.52, blue: 0.20),
        checkmark: Color(red: 0.24, green: 0.78, blue: 0.36),
        categoryColors: [
            "Idea": Color(red: 0.90, green: 0.79, blue: 0.36),
            "Task": Color(red: 0.66, green: 0.56, blue: 0.95),
            "Journal": Color(red: 0.40, green: 0.82, blue: 0.76),
            "Work": Color(red: 0.30, green: 0.58, blue: 1.0),
            "Personal": Color(red: 1.0, green: 0.30, blue: 0.44),
        ],
        categoryFallback: .gray
    )

    /// The original flat near-black + mint look, kept as an alternate.
    static let midnight = Theme(
        accent: .mint,
        recording: .red,
        background: .black,
        glowPrimary: .clear,
        glowSecondary: .clear,
        cardFill: Color(.secondarySystemGroupedBackground).opacity(0.35),
        cardBorder: .clear,
        metaText: Color(.secondaryLabel),
        actionHeader: .mint,
        checkmark: .mint,
        categoryColors: [
            "Idea": .yellow,
            "Task": .mint,
            "Journal": .purple,
            "Work": .blue,
            "Personal": .pink,
        ],
        categoryFallback: .gray
    )
}
