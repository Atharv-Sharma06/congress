# CivicAI — iOS app

SwiftUI, iOS 17+, Swift Charts, CoreLocation. No third-party dependencies.

## Build

### With XcodeGen (recommended)

```bash
brew install xcodegen
cd ios
xcodegen generate
open CivicAI.xcodeproj
```

Then: target **CivicAI** → **Signing & Capabilities** → select your team. Run.

### Without XcodeGen

1. Xcode → File → New → Project → iOS → App.
   Product Name `CivicAI`, Interface **SwiftUI**, Language **Swift**.
   Save it *outside* this folder to avoid clobbering these sources.
2. Delete the generated `ContentView.swift` and `CivicAIApp.swift`.
3. Drag the `CivicAI/` folder from here into the project — check **Create groups**
   and **Copy items if needed**.
4. Build Settings → set `INFOPLIST_FILE` to `CivicAI/Resources/Info.plist`.
5. Project → Info → Configurations → set Debug and Release to
   `Config/Debug.xcconfig` and `Config/Release.xcconfig`.
6. Set the deployment target to **iOS 17.0**.

## Configuration

The app holds no provider keys. It knows two values, injected at build time:

| xcconfig key | Meaning |
|---|---|
| `CIVICAI_API_BASE_URL` | Your backend. HTTPS required except `localhost`. |
| `CIVICAI_APP_KEY` | Optional shared secret; must match `APP_SHARED_SECRET`. |

`Config/Debug.xcconfig` already points at `http://localhost:8080`, matching
`npm start` in `../backend`. Edit `Config/Release.xcconfig` before archiving.

If `CIVICAI_API_BASE_URL` is missing or not HTTPS, `APIClient` traps at launch with a
message naming the file to fix. That is deliberate — a release build silently talking
to nothing is worse than a build that refuses to run.

> Note on xcconfig: `//` starts a comment, so URLs are written as
> `https:/$()/host` — the empty `$()` breaks up the slashes and expands to nothing.

## Structure

```
CivicAI/
  App/            CivicAIApp, RootView, MainTabView
  DesignSystem/   Theme (tokens), Components (glass card, buttons, states),
                  Motion (stagger, shimmer, draw-in, animated values, ground)
  Models/         Codable models + CivicError
  Services/       APIClient (actor), LocationService, AppState
  ViewModels/     MetricsStore, AskViewModel, CompareViewModel, LocationPickerViewModel
  Views/
    Tabs/         Home, Explore, Compare, Settings
    Components/   MetricCard, TrendChart, SourceSheet
    LocationPickerView, MetricDetailView, AskCivicAIView
  Utils/          Formatters
  Resources/      Info.plist, Assets.xcassets
```

`MetricsStore` is shared through `@EnvironmentObject`, so Home and Explore render
from one fetch. Switching tabs never refetches.

## Design system

Everything visual comes from `DesignSystem/`, which mirrors
`../design-system/MASTER.md`. Views must not hardcode hex values or magic spacing.

| File | Owns |
|---|---|
| `Theme.swift` | Color, spacing, radius, motion and elevation tokens |
| `Components.swift` | `CardSurface` (glass), button styles, `StatusView`, skeletons, haptics |
| `Motion.swift` | `staggeredAppear`, `shimmering`, `drawsIn`, `AnimatedValue`, `AppBackground` |

**Look:** slate structure, one orange accent, glass cards floating over a gradient
ground. Orange is reserved for exactly two jobs — the primary action, and the data
itself. Nothing else may be orange; that is what makes the data read as the subject.

### Glass, and why it's safe here

`CardSurface` is three layers: `.ultraThinMaterial`, a per-mode tint so text has
something to sit on, and a lit rim gradient on the top edge. The rim is what
actually reads as glass — without it you get a flat translucent rectangle.

Glass only ever sits over `AppBackground`; there is no glass on glass. And every
glass surface (`CardSurface`, `GlassChip`, `GlassRowBackground`,
`SecondaryButtonStyle`) branches on `accessibilityReduceTransparency` and falls
back to `Palette.surfaceOpaque`. That branch is the reason transparency is
acceptable in an app whose whole claim is legibility.

### The five motions

| Motion | Where | Modifier |
|---|---|---|
| Staggered entrance | Home cards, Compare rows, Ask findings | `.staggeredAppear(index:)` |
| Chart draw-in | `TrendChart`, `Sparkline` | `.drawsIn()` |
| Numeric roll | Every metric value | `AnimatedValue` |
| Press | Cards and buttons | `PressableCardStyle` |
| Shimmer | All skeletons | `.shimmering()` |

All five branch on `accessibilityReduceMotion` — content appears immediately and
fully legible, rather than animating more slowly. Stagger is deliberately **not**
used inside `List`, where cell reuse turns it into flicker on scroll.

### Other load-bearing rules

- **Dark mode** — every color is a light/dark pair via `Color(light:dark:)`, resolved
  at draw time. There is no inverted-palette fallback.
- **Dynamic Type** — no `lineLimit` on metric values; `fixedSize(vertical:)` on
  wrapping text. Icon sizes scale with `@ScaledMetric`.
- **Never color-only** — trend meaning is carried by an SF Symbol arrow *and* the
  label text, so it survives grayscale and color vision differences.
- **No emoji** — key findings render `Image(systemName:)` from a symbol name the
  backend's JSON schema constrains to an enum.
- **Tap targets** — `Theme.minTapTarget` (44pt) via `frame(minHeight:)` plus
  `contentShape`, never by growing glyphs.
- **Charts are not a dead end** — `TrendChart` implements
  `AXChartDescriptorRepresentable`, so VoiceOver can walk every data point.

## Manual QA

Test on iPhone SE (3rd gen) and iPhone 15 Pro Max, in both appearances:

- [ ] Light and dark, both devices — no clipped text, no low-contrast pairs
- [ ] Settings → Accessibility → Larger Text at max — cards wrap, nothing truncates
- [ ] Reduce Motion on — no shimmer, no stagger, no draw-in, no press scaling;
      every value legible on the first frame
- [ ] Reduce Transparency on — glass becomes opaque everywhere (cards, chips, list
      rows, secondary buttons); no text sitting on a blurred background
- [ ] VoiceOver — every card reads name, value, year and trend as one phrase
- [ ] VoiceOver on a metric detail chart — rotor reaches individual data points
- [ ] Landscape — no horizontal scroll, Ask bar stays clear of the last card
- [ ] Airplane mode — "Network error" with a working Try again
- [ ] Backend stopped — same, and Ask degrades without leaking provider errors
- [ ] Deny location permission — picker explains and offers the manual list
