# CivicAI — Design System (Master / Source of Truth)

Platform: **iOS 17+ / SwiftUI**. Page-level deviations live in
`design-system/pages/<page>.md` and override this file.

## 0. The feel, in one line

**Clean, modern, corporate, accessible, trustworthy.** A professional data
instrument — slate structure, one orange accent, glass surfaces floating over a
quiet ground, and motion that only ever explains a change.

Trustworthy is the load-bearing word, and it is why the surfaces are glass:
the data underneath is never fully hidden, and the source is never more than one
tap away. Transparency is the visual argument as well as the product argument.

**Style:** Data-Dense Dashboard + restrained glassmorphism.
**Never:** decorative gradients over data, emoji as icons, blur used for its own
sake, motion that does not correspond to a state change.

---

## 1. Color tokens

Slate carries all structure and text. Orange is the *only* chromatic accent, and it
is reserved for two jobs: the primary action, and the data itself. Nothing else is
allowed to be orange — that is what makes the data read as the subject.

Defined once in `ios/CivicAI/DesignSystem/Theme.swift`. Never hardcode a hex in a view.

### Core

| Token | Light | Dark | Use |
|---|---|---|---|
| `primary` | `#C2410C` orange-700 | `#FB923C` orange-400 | Primary CTA, links, selected state |
| `onPrimary` | `#FFFFFF` | `#1A1206` | Label on a primary fill |
| `accent` | `#EA580C` orange-600 | `#FDBA74` orange-300 | Chart series, data emphasis |
| `secondary` | `#334155` slate-700 | `#CBD5E1` slate-300 | Structural marks, second series |
| `foreground` | `#0F172A` slate-900 | `#F1F5F9` slate-100 | Primary text |
| `foregroundMuted` | `#475569` slate-600 | `#94A3B8` slate-400 | Secondary text, axis labels |

### Ground and surfaces

| Token | Light | Dark | Use |
|---|---|---|---|
| `backgroundTop` | `#F8FAFC` | `#0B1120` | Top of the page gradient |
| `backgroundBottom` | `#E2E8F0` | `#020617` | Bottom of the page gradient |
| `glassTint` | `#FFFFFF` @ 62% | `#1E293B` @ 52% | Tint layered over the material |
| `surfaceOpaque` | `#FFFFFF` | `#16213A` | Fallback when Reduce Transparency is on |
| `glassStroke` | `#FFFFFF` @ 70% | `#FFFFFF` @ 10% | Top highlight edge that sells the glass |
| `border` | `#CBD5E1` | `#334155` | Hairline, dividers |
| `gridline` | `#E2E8F0` | `#1E293B` | Chart grid — deliberately low contrast |

### Semantic

| Token | Light | Dark | Use |
|---|---|---|---|
| `positive` | `#15803D` | `#4ADE80` | Trend moving the good way |
| `negative` | `#B91C1C` | `#F87171` | Trend moving the bad way |
| `neutralTrend` | `#475569` | `#94A3B8` | Movement that is neither |
| `destructive` | `#B91C1C` | `#F87171` | Destructive actions |

### Contrast floor (verified both modes)

- Body text on glass: **≥ 4.5:1**. Muted text: **≥ 4.5:1** (not 3:1 — glass already
  costs perceived contrast, so we do not spend the accessibility budget twice).
- `onPrimary` on `primary`: 5.1:1 light, 12:1 dark.
- Data marks vs ground: **≥ 3:1**. Gridlines are exempt; they must recede.
- Trend meaning is **never color-only** — always an arrow glyph plus label text.

---

## 2. Glass, precisely

Glass is three layers, always in this order, never improvised per-view:

1. `.ultraThinMaterial` — the blur
2. `glassTint` — a tint so text has something to sit on
3. `glassStroke` hairline on the top edge + `border` around — the lit rim

Plus one soft shadow (`y 8, blur 24, 8%`) so the card reads as floating, not printed.

**Rules**
- Glass only over the app's own gradient ground. Never glass on glass — one level
  of transparency, then opaque.
- **Reduce Transparency must be honored.** When it is on, the material and tint are
  replaced with `surfaceOpaque` and the stroke drops to `border`. Every card checks
  `@Environment(\.accessibilityReduceTransparency)`; this is not optional.
- Modals and sheets use system materials, not the card recipe.
- The ground gradient carries one very soft orange radial bloom at ~6% opacity.
  It is the only decorative element in the app.

---

## 3. Motion

Motion exists to explain a change in state. If nothing changed, nothing moves.

### Tokens

| Token | Duration | Curve | Used for |
|---|---|---|---|
| `micro` | 120ms | `easeOut` | Opacity, tint, icon swaps |
| `quick` | 180ms | `easeOut` | Enter, reveal, expand |
| `standard` | 260ms | `easeInOut` | Section and state crossfades |
| `exit` | 140ms | `easeIn` | Dismiss (≈60% of enter — leaving feels fast) |
| `press` | spring(0.28, 0.7) | — | Tap feedback |
| `chartDraw` | 620ms | `easeOut` | One-time chart reveal |

### The five motions in this app

1. **Staggered entrance.** Cards fade in and rise 10pt, 45ms apart, capped at 8
   items so a long list never feels like it is loading slowly.
2. **Chart draw-in.** The line reveals left to right via a mask, once, on first
   appearance. It reads as data arriving, not as decoration.
3. **Numeric transition.** Values use `.contentTransition(.numericText())`, so a
   refresh rolls the digits that changed instead of hard-swapping the whole number.
4. **Press.** Scale to 0.97 plus opacity. Never animates layout bounds — nothing
   around the card may shift.
5. **Shimmer.** Skeletons sweep a soft highlight across, replacing the old opacity
   pulse. Shape-matched to the content that will replace them, so nothing jumps.

### Non-negotiables

- Everything above is gated on `@Environment(\.accessibilityReduceMotion)`. With it
  on: no stagger, no draw-in, no shimmer, no press scaling — content appears
  immediately and fully legible. This is a branch, not a slowdown.
- Animate `transform` and `opacity` only. Never width, height, or position layout.
- Animations are interruptible; a tap during one cancels it.
- Nothing blocks input while animating.
- One-time reveals fire once per appearance, never on every scroll pass.

---

## 4. Typography

System font (SF), Dynamic Type throughout. No bundled webfonts.

| Role | Style | Weight |
|---|---|---|
| Screen title | `.largeTitle` | `.bold` |
| Section header | `.title3` | `.semibold` |
| Card metric value | `.title` + `.monospacedDigit()` | `.bold` |
| Card label | `.footnote` uppercase, tracking 0.6 | `.semibold` |
| Body | `.body` | `.regular` |
| Caption / source | `.caption` | `.regular` |

- All numbers use `.monospacedDigit()` — tabular figures keep columns from jittering
  during the numeric transition.
- Never `.lineLimit(1)` on a metric value. At Dynamic Type XXXL it wraps, not truncates.

---

## 5. Spacing & layout

4/8pt rhythm. `Theme.Space`: `xs 4, sm 8, md 12, lg 16, xl 24, xxl 32`.

- Screen inset 16 · card padding 16 · card gap 12 · section gap 24
- Card radius 20 (glass wants a softer corner than a flat card)
- Control radius 12 · pill radius full
- Bottom scroll padding 96 so the docked Ask bar never covers the last card
- Respect safe areas; the ground gradient runs edge to edge under them

---

## 6. Icons

SF Symbols only. One family, consistent weight. **No emoji anywhere** — including
AI key findings, where the backend returns an SF Symbol name constrained by a JSON
schema enum.

| Meaning | Symbol |
|---|---|
| Economy | `chart.line.uptrend.xyaxis` |
| Housing | `house` |
| Population | `person.3` |
| Education | `graduationcap` |
| Source / provenance | `link.circle` |
| Ask CivicAI | `sparkle.magnifyingglass` |
| Trend up / down / flat | `arrow.up.right` / `arrow.down.right` / `arrow.right` |

---

## 7. Interaction

- Every tappable element ≥ 44×44pt via `frame(minHeight:)` + `contentShape` —
  never by growing the glyph.
- ≥ 8pt between touch targets.
- Haptics: `.impact(.light)` on card tap, `.notification(.success)` on answer arrival.
- One primary CTA per screen.

---

## 8. States

Every data surface implements all four: `loading` (shape-matched shimmer for
anything over ~300ms) → `loaded` → `empty` (says *why*, offers a next action) →
`error` (cause + retry). Charts never render a bare empty axis frame.
