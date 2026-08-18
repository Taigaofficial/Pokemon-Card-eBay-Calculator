import SwiftUI

/// Central design tokens for the whole app. Views never hard-code colors —
/// they read them from `Theme.current`. To try a new look, point `current`
/// at a different palette (or edit one) and every screen updates.
struct Theme {
    var accent: Color
    var recording: Color
    var background: Color
    var cardFill: Color
    var categoryColors: [String: Color]
    var categoryFallback: Color

    func color(forCategory category: String) -> Color {
        categoryColors[category] ?? categoryFallback
    }

    /// The active theme.
    static let current = midnight

    /// Default dark theme: near-black with a mint accent.
    static let midnight = Theme(
        accent: .mint,
        recording: .red,
        background: .black,
        cardFill: Color(.secondarySystemGroupedBackground).opacity(0.35),
        categoryColors: [
            "Idea": .yellow,
            "Task": .mint,
            "Journal": .purple,
            "Work": .blue,
            "Personal": .pink,
        ],
        categoryFallback: .gray
    )

    /// Example alternate palette — set `current = ember` to preview it.
    static let ember = Theme(
        accent: .orange,
        recording: .red,
        background: Color(red: 0.08, green: 0.05, blue: 0.04),
        cardFill: Color.orange.opacity(0.08),
        categoryColors: [
            "Idea": .yellow,
            "Task": .orange,
            "Journal": .purple,
            "Work": .teal,
            "Personal": .pink,
        ],
        categoryFallback: .gray
    )
}
