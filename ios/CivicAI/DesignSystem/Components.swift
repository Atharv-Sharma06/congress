import SwiftUI
import UIKit

// MARK: - Glass surface

/// The one card treatment in the app.
///
/// Glass is three layers, always in this order: `.ultraThinMaterial` (the blur),
/// a tint so text has something to sit on, and a lit rim on the top edge. Plus one
/// soft shadow so it reads as floating rather than printed.
///
/// When Reduce Transparency is on, the material and tint are replaced with an
/// opaque surface. That branch is the whole reason glass is safe to use here.
struct CardSurface<Content: View>: View {
    var padding: CGFloat = Theme.Space.lg
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if reduceTransparency {
                    shape.fill(Theme.Palette.surfaceOpaque)
                } else {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Theme.Palette.glassTint)
                }
            }
            .overlay {
                // The rim: bright along the top edge, fading to the plain border.
                // This gradient is what actually reads as "glass" — without it the
                // card looks like a flat translucent rectangle.
                shape.strokeBorder(
                    reduceTransparency
                        ? AnyShapeStyle(Theme.Palette.border)
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [Theme.Palette.glassStroke, Theme.Palette.border.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        ),
                    lineWidth: 1
                )
            }
            .shadow(
                color: .black.opacity(Theme.Elevation.cardOpacity),
                radius: Theme.Elevation.cardRadius,
                x: 0,
                y: Theme.Elevation.cardY
            )
    }
}

// MARK: - Press feedback

/// Scale + opacity only — never animates layout bounds, so nothing around it shifts.
struct PressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : Theme.Motion.press, value: configuration.isPressed)
    }
}

/// Prominent, high-contrast CTA. One per screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.Palette.onPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
            .padding(.horizontal, Theme.Space.lg)
            .background(
                Theme.Palette.primary,
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
            .shadow(color: Theme.Palette.primary.opacity(isEnabled ? 0.28 : 0), radius: 12, y: 4)
            .opacity(isEnabled ? (configuration.isPressed ? 0.9 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : Theme.Motion.press, value: configuration.isPressed)
    }
}

/// Quieter companion to `PrimaryButtonStyle` — glass, not orange. For actions that
/// matter but must not compete with the screen's single primary CTA.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        return configuration.label
            .font(.headline)
            .foregroundStyle(Theme.Palette.foreground)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
            .padding(.horizontal, Theme.Space.lg)
            .background {
                if reduceTransparency {
                    shape.fill(Theme.Palette.surfaceOpaque)
                } else {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Theme.Palette.glassTint)
                }
            }
            .overlay(shape.strokeBorder(Theme.Palette.border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : Theme.Motion.press, value: configuration.isPressed)
    }
}

/// Glass background for `List` rows, so system lists match the card treatment
/// instead of sitting as opaque slabs on the gradient ground.
struct GlassRowBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Rectangle()
            .fill(reduceTransparency ? AnyShapeStyle(Theme.Palette.surfaceOpaque)
                                     : AnyShapeStyle(Material.ultraThin))
            .overlay(reduceTransparency ? Color.clear : Theme.Palette.glassTint)
    }
}

extension View {
    func glassListRow() -> some View { listRowBackground(GlassRowBackground()) }
}

/// Smaller sibling of `CardSurface` at control radius — suggestion chips, inline
/// affordances. Same Reduce Transparency branch.
struct GlassChip: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
        return content
            .background {
                if reduceTransparency {
                    shape.fill(Theme.Palette.surfaceOpaque)
                } else {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Theme.Palette.glassTint)
                }
            }
            .overlay(shape.strokeBorder(Theme.Palette.border, lineWidth: 1))
    }
}

extension View {
    func glassChip() -> some View { modifier(GlassChip()) }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Palette.foreground)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Trend pill

/// Direction is carried by an arrow glyph and by the label text, so the meaning
/// survives with color vision differences or in grayscale.
struct TrendPill: View {
    let trend: Trend
    let change: MetricChange
    let format: MetricFormat

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Image(systemName: trend.direction.sfSymbol)
                .font(.caption.weight(.bold))
            Text(Format.changeSummary(change, format: format))
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(trend.sentiment.color)
        .padding(.horizontal, Theme.Space.sm)
        .padding(.vertical, Theme.Space.xs)
        .background(trend.sentiment.color.opacity(0.12), in: Capsule())
        .overlay(Capsule().strokeBorder(trend.sentiment.color.opacity(0.22), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Format.changeSummary(change, format: format))
    }
}

// MARK: - Loading, empty and error states

/// Skeleton bar. Shape-matched to the content it stands in for, so nothing jumps
/// when the real value arrives.
struct SkeletonBlock: View {
    var height: CGFloat = 14
    var width: CGFloat? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Theme.Palette.gridline)
            .frame(width: width, height: height)
            .shimmering()
            .accessibilityHidden(true)
    }
}

struct MetricCardSkeleton: View {
    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SkeletonBlock(height: 12, width: 90)
                SkeletonBlock(height: 28, width: 120)
                SkeletonBlock(height: 12, width: 140)
                SkeletonBlock(height: 44)
            }
        }
    }
}

/// One consistent treatment for "nothing here" and "it broke".
struct StatusView: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Theme.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(Theme.Palette.foregroundMuted)
                .padding(Theme.Space.lg)
                .background(Theme.Palette.gridline.opacity(0.6), in: Circle())
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Palette.foreground)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.foregroundMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, Theme.Space.xs)
                    .frame(maxWidth: 260)
            }
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }
}

extension StatusView {
    /// Error states always name the problem and offer a way forward.
    static func error(_ error: CivicError, retry: (() -> Void)? = nil) -> StatusView {
        StatusView(
            symbol: error.isRetryable ? "wifi.exclamationmark" : "questionmark.circle",
            title: error.isRetryable ? "Something went wrong" : "Not available",
            message: error.errorDescription ?? "Please try again.",
            actionTitle: (error.isRetryable && retry != nil) ? "Try again" : nil,
            action: error.isRetryable ? retry : nil
        )
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
