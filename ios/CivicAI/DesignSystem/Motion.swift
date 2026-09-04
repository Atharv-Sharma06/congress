import SwiftUI

// MARK: - Reduce Motion helper

/// Reads Reduce Motion once and hands back either the animation or nil.
/// Using this instead of scattering ternaries keeps "respect the setting" from
/// being something a new view can forget.
struct MotionGate {
    let reduceMotion: Bool

    func animation(_ animation: Animation) -> Animation? {
        reduceMotion ? nil : animation
    }
}

extension EnvironmentValues {
    var motionGate: MotionGate { MotionGate(reduceMotion: accessibilityReduceMotion) }
}

// MARK: - Staggered entrance

/// Fades in and lifts a view into place, offset by its position in a list.
/// With Reduce Motion on, the view is simply present from the first frame —
/// a branch, not a slower animation.
struct StaggeredAppear: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private var delay: Double {
        Double(min(index, Theme.Motion.staggerCap)) * Theme.Motion.staggerStep
    }

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 10)
            .onAppear {
                guard !reduceMotion else {
                    hasAppeared = true
                    return
                }
                withAnimation(Theme.Motion.quick.delay(delay)) { hasAppeared = true }
            }
    }
}

extension View {
    /// Position in the group being revealed. Past `Theme.Motion.staggerCap` the
    /// delay stops growing, so a long list never feels like it is loading slowly.
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}

// MARK: - Shimmer

/// A soft highlight sweeping across a skeleton. Replaces the old opacity pulse:
/// a sweep reads as "content is coming", a pulse reads as "something is wrong".
struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geometry in
                        let width = geometry.size.width
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.45), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: width * 0.6)
                        .offset(x: phase * width * 1.6)
                        .blendMode(.plusLighter)
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipped()
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.15).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmering() -> some View { modifier(Shimmer()) }
}

// MARK: - Left-to-right reveal

/// Masks a view behind a growing rectangle so a chart line draws itself in once,
/// on first appearance. Reads as data arriving rather than as decoration.
struct DrawInReveal: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .mask(alignment: .leading) {
                GeometryReader { geometry in
                    Rectangle()
                        .frame(width: geometry.size.width * progress)
                }
            }
            .onAppear {
                guard !reduceMotion else {
                    progress = 1
                    return
                }
                withAnimation(Theme.Motion.chartDraw) { progress = 1 }
            }
    }
}

extension View {
    func drawsIn() -> some View { modifier(DrawInReveal()) }
}

// MARK: - Animated numbers

/// A metric value that rolls only the digits that changed when data refreshes.
/// Tabular figures keep the surrounding layout from shifting while it transitions.
struct AnimatedValue: View {
    let value: Double
    let format: MetricFormat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(Format.value(value, as: format))
            .monospacedDigit()
            .contentTransition(.numericText(value: value))
            .animation(reduceMotion ? nil : Theme.Motion.standard, value: value)
    }
}

// MARK: - Ground

/// The app's ground: a quiet slate gradient with a single soft orange bloom.
/// This is the only decorative element in the app, and it is what glass floats over —
/// a card blurred against a flat fill would just look grey.
struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.Palette.backgroundTop, Theme.Palette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [Theme.Palette.accent.opacity(0.10), .clear],
                center: UnitPoint(x: 0.85, y: 0.05),
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// Standard screen ground. Use instead of `.background(Color…)` on a screen root.
    func appBackground() -> some View {
        background(AppBackground())
    }
}
