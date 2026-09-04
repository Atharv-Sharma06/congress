# Page override — Ask CivicAI

Deviations from `../MASTER.md`. Everything not listed here follows the Master.

## Why this screen deviates

It is the only screen where content is generated rather than retrieved. The design
job is to keep the AI's output visibly subordinate to the data: the numbers and the
sources are the product, the prose is the wrapper.

## Overrides

| Rule | Master | Here | Reason |
|---|---|---|---|
| Primary CTA | One per screen | The send button. "View sources" is `SecondaryButtonStyle` — glass, not orange | Sourcing must be prominent, but only one thing on screen gets the accent. |
| Card density | 16pt padding, 12pt gap | Key findings use the same, but stack full width | Findings are read sequentially, not scanned in a grid. |
| Chart height | 200pt | 180pt | The chart supports the prose here; on Metric Detail it *is* the content. |
| Icons | Chosen at design time | Chosen at runtime by the model | Constrained to an SF Symbol enum in the response schema — an emoji cannot get through. |
| Stagger | Applies to card groups | Applies to suggestion chips and key findings | Both are read top to bottom; the reveal matches the reading order. |

## Required behavior

- **Never an empty input.** The idle state shows four tappable example questions.
  A blank text field with a placeholder is a dead end for a first-time user.
- **Skeleton, not spinner.** The loading state mirrors the answer's shape so the
  layout does not jump when content arrives, and shimmers rather than pulses.
- **Findings reveal in reading order**, 45ms apart. The chart draws itself in once.
  Both are off under Reduce Motion.
- **The input border animates on focus** (`Motion.micro`) — a state change, so it
  earns a transition.
- **"No data" is a first-class state,** not an error. It uses `StatusView` with a
  neutral tray symbol and offers "Ask something else" — the app was working
  correctly; the data simply doesn't cover the question.
- **Numbers use `.monospacedDigit()`** even inside model-written strings, so a
  finding's value column doesn't shimmer as it renders.
- **Findings read as one VoiceOver phrase:** title, value, change. The icon is
  `accessibilityHidden` — it is decoration next to text that already says it.
- **Dismissal is always available.** Close in the leading toolbar slot, plus the
  standard sheet drag-to-dismiss.

## Copy rules

- Never say "I think", "probably", or "this proves".
- The failure line is fixed: *"I couldn't find reliable public data for that question."*
- Never surface a provider name or error code to the user.
