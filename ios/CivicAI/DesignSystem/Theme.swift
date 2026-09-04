import SwiftUI
import UIKit

/// Single source of truth for color, spacing, radius and motion.
/// Mirrors `design-system/MASTER.md`. Views must never hardcode a hex value.
enum Theme {

    // MARK: - Color
    //
    // Slate carries every structural and text role. Orange is the only chromatic
    // accent and is reserved for exactly two jobs: the primary action, and the data.
    // Nothing else may be orange — that is what makes the data read as the subject.

    enum Palette {
        static let primary          = Color(light: 0xC2410C, dark: 0xFB923C)
        static let onPrimary        = Color(light: 0xFFFFFF, dark: 0x1A1206)
        static let accent           = Color(light: 0xEA580C, dark: 0xFDBA74)
        static let secondary        = Color(light: 0x334155, dark: 0xCBD5E1)

        static let foreground       = Color(light: 0x0F172A, dark: 0xF1F5F9)
        static let foregroundMuted  = Color(light: 0x475569, dark: 0x94A3B8)

        // Ground gradient. Glass only ever floats over this.
        static let backgroundTop    = Color(light: 0xF8FAFC, dark: 0x0B1120)
        static let backgroundBottom = Color(light: 0xE2E8F0, dark: 0x020617)

        /// Tint layered over the blur so text has something to sit on.
        static let glassTint = Color(
            light: 0xFFFFFF, lightAlpha: 0.62,
            dark: 0x1E293B, darkAlpha: 0.52
        )
        /// The lit rim along a glass card's top edge.
        static let glassStroke      = Color(lightWhite: 0.70, darkWhite: 0.10)
        /// Used in place of the material when Reduce Transparency is on.
        static let surfaceOpaque    = Color(light: 0xFFFFFF, dark: 0x16213A)
        /// Modals sit one level above cards.
        static let surfaceElevated  = Color(light: 0xFFFFFF, dark: 0x1B2740)

        static let border           = Color(light: 0xCBD5E1, dark: 0x334155)
        static let gridline         = Color(light: 0xE2E8F0, dark: 0x1E293B)

        static let positive         = Color(light: 0x15803D, dark: 0x4ADE80)
        static let negative         = Color(light: 0xB91C1C, dark: 0xF87171)
        static let neutralTrend     = Color(light: 0x475569, dark: 0x94A3B8)
        static let destructive      = Color(light: 0xB91C1C, dark: 0xF87171)
    }

    // MARK: - Spacing (4/8pt rhythm)

    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        /// Glass wants a softer corner than a flat card.
        static let card: CGFloat = 20
        static let control: CGFloat = 12
        static let pill: CGFloat = 999
    }

    // MARK: - Motion
    //
    // Motion exists to explain a change in state. If nothing changed, nothing moves.
    // Every value here is gated on Reduce Motion at the call site.

    enum Motion {
        static let microDuration: Double = 0.12
        static let quickDuration: Double = 0.18
        static let standardDuration: Double = 0.26
        /// Exit runs at ~60% of enter, so dismissing feels immediate.
        static let exitDuration: Double = 0.14
        static let chartDrawDuration: Double = 0.62

        /// Delay between consecutive items in a staggered reveal.
        static let staggerStep: Double = 0.045
        /// Past this many items the stagger reads as slow loading, so it stops.
        static let staggerCap: Int = 8

        static let micro    = SwiftUI.Animation.easeOut(duration: microDuration)
        static let quick    = SwiftUI.Animation.easeOut(duration: quickDuration)
        static let standard = SwiftUI.Animation.easeInOut(duration: standardDuration)
        static let exit     = SwiftUI.Animation.easeIn(duration: exitDuration)
        static let press    = SwiftUI.Animation.spring(response: 0.28, dampingFraction: 0.7)
        static let chartDraw = SwiftUI.Animation.easeOut(duration: chartDrawDuration)
    }

    enum Elevation {
        /// One soft shadow so a card reads as floating, not printed.
        static let cardRadius: CGFloat = 24
        static let cardY: CGFloat = 8
        static let cardOpacity: Double = 0.08
    }

    /// Minimum tap target required by Apple HIG.
    static let minTapTarget: CGFloat = 44
}

// MARK: - Color helpers

extension Color {
    /// Builds a color that resolves per interface style, so dark mode is never an afterthought.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    /// Same, with a per-mode alpha. Resolved at draw time, so it follows a live
    /// appearance change rather than freezing at first access.
    init(light: UInt32, lightAlpha: Double, dark: UInt32, darkAlpha: Double) {
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            return UIColor(rgb: isDark ? dark : light)
                .withAlphaComponent(isDark ? darkAlpha : lightAlpha)
        })
    }

    /// White at different alphas per mode — used for the lit rim on glass, which
    /// needs to be bright in light mode and barely there in dark.
    init(lightWhite: Double, darkWhite: Double) {
        self.init(uiColor: UIColor { traits in
            UIColor(white: 1, alpha: traits.userInterfaceStyle == .dark ? darkWhite : lightWhite)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Trend presentation

extension TrendSentiment {
    var color: Color {
        switch self {
        case .positive: return Theme.Palette.positive
        case .negative: return Theme.Palette.negative
        case .neutral:  return Theme.Palette.neutralTrend
        }
    }
}

extension TrendDirection {
    /// Direction is always paired with this symbol so meaning never rests on color alone.
    var sfSymbol: String {
        switch self {
        case .up:     return "arrow.up.right"
        case .down:   return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var spokenWord: String {
        switch self {
        case .up:     return "up"
        case .down:   return "down"
        case .stable: return "unchanged"
        }
    }
}
