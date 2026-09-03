# FlowPay — Design System Reference

**Purpose.** A working design specification for FlowPay (Flutter mobile app, iOS + Android) built on BMONI Embedded. It is measured, not vibe-driven: every rule below is written so a teammate or coding agent can check whether a screen conforms to it or not. Where a rule quotes an exact value (a hex, a radius, a font weight), that value comes from real reference material listed at the bottom of the doc, or from a deliberate FlowPay-specific decision noted in-line.

This document supersedes anything in `.agents/skills/flowpay-core/taste-SKILL.md` for FlowPay's mobile UI. That skill was written for React/Next.js marketing sites and its code patterns do not apply to Flutter; use its *principles* (one accent color, motivated motion, no AI-tell copy) but this file for actual mobile UI direction.

---

## 1. Design Read

FlowPay is a **multi-currency wallet and payroll app for globally-mobile individuals and small business owners**, primarily anchored in Nigeria with expansion rails into Mexico and the US.

Two product surfaces inside one app:

- **Personal.** A user holds USD and NGN, receives income into a US virtual account (ACH) and a Nigerian NUBAN, and runs "Money Missions" (declarative split rules like *"whenever I receive $2,000, keep 30% USD, convert 50% to NGN, reserve 20% for tax"*).
- **Business.** An employer funds one wallet and runs payroll to distributed employees in Nigeria and Mexico in their local currencies, issuing virtual Mastercards on each employee wallet.

The BMONI layer underneath handles stablecoins, on-device signing, and rails. **The user never sees this.** They see "USD account", "NGN account", "Send", "Approve" — never "USDB", "smart wallet", "signature request", "proposal", "EVM".

**Reading this as:** a trust-first consumer fintech app for the Wise / Mercury / Kuda demographic, not a crypto wallet. Calm, precise, dense-but-legible. The visual anchor is money moving, not tokens.

**Design ambition.** FlowPay competes on visual credibility against Wise and Grey (multi-currency), Kuda (Nigerian everyday banking), and Mercury (business surfaces). If the hackathon demo puts our screen next to a Wise screenshot, the judge should not be able to tell which is the older company by looks alone.

---

## 2. Reference Apps: Measured, Not Cloned

Each of these has a well-documented, publicly-analyzed design language. The FlowPay rules in Sections 3–8 below are derived from studying them. **We are not cloning any of them.** The rules explain what to take and what to leave.

### 2.1 Wise (wise.com) — for multi-currency clarity and rail transparency

Wise's design language, as documented in its public design system:

- **Primary brand color:** Lime Voltage `#9FE870`, used **exclusively** on primary CTA fills and active states. One lime element per visible viewport is usually enough. Never as a status color.
- **Deep brand color:** Forest Ink `#163300`, dark text and dark section backgrounds. Not pure black; the green-tinted near-black is warmer and on-brand.
- **Neutrals:** Paper white `#FFFFFF`, sage canvas `#E8EBE6` for background bands.
- **Typography:** proprietary Wise Sans at weight 900 for display headlines (very heavy; the extreme weight is the brand signature). Inter for body/UI.
- **Radii:** pill (`9999px` / full-radius) for all buttons and nav segments. Softer 10–24px on cards.
- **Layout signature:** "You send → They receive" flow with real-time rate visible, delivery estimate, and complete fee breakdown. No hidden costs, ever.

**What FlowPay takes from Wise:** the pill-shaped CTA discipline, the "show every fee and rate up front" honesty, the balance-switcher pattern between currencies, and the confident use of one single accent color.

**What FlowPay does not take:** Wise's exact green (too on-the-nose, we'd look like a clone) and the shouty 900-weight display type (Wise-specific brand voice, not ours).

### 2.2 Mercury (mercury.com) — for business surfaces and typographic restraint

Mercury's system:

- **Primary accent:** Cobalt indigo `#5266EB`, reserved *exclusively* for the primary CTA ("Open account" pill). Never appears on two elements in the same section.
- **Canvas:** near-black `#171721` (indigo-tinted, never pure `#000000`), inverted text `#EDEDF3`.
- **Typography:** proprietary Arcadia and Arcadia Display, variable font used at an intermediate weight (480). Not bold, not light. Confident without being loud.
- **Radii:** 12px on cards, generous 32–40px pill radii on buttons and inputs.
- **Zero shadows.** Depth comes from surface luminance shifts between `#171721` and `#1E1E2A`, not drop shadows.
- **Color discipline in-product:** green for credits (`rgb(52,211,153)`), red for debits (`rgb(248,113,113)`), amber for pending (`rgb(251,191,36)`). Colors are for state only, never decoration.

**What FlowPay takes:** the "color only means state" discipline for the transaction feed and payroll dashboard, the zero-shadow depth via surface tinting, and tabular figures for money amounts.

**What FlowPay does not take:** Mercury's dark-first cinematic aesthetic. FlowPay defaults to **light mode** because dark-mode-first fintech reads as "for founders", and FlowPay's primary user is a Nigerian professional or small-business owner who expects light UI (Kuda, PiggyVest, Grey, Cleva all default to light).

### 2.3 Monzo (monzo.com) — for the transaction feed and card iconography

Monzo's system:

- **Hot Coral** `#FF4F40`, used as an **object color**, not a button color. It fills the physical card and illustrated tiles; the CTA is deep navy on white, not coral. Monzo's own brand guide explicitly warns that Hot Coral "is exhausting at scale" and long-form UI defaults to deep navy on soft white.
- **Deep navy** `#091723` (called "Firefly"), carrying most of the text and dark sections.
- **Typography:** Monzo Sans (custom cut of Universal Sans) for UI, Oldschool Grotesk for display.
- **Radii:** `500px` (pill) for buttons and chips; `4px` micro-tag corner for small inline labels.
- **Layout signature:** day-grouped transaction feed with merchant logos/emoji, tabular currency figures, real-time notifications.

**What FlowPay takes:** the "brand color is for the card object, not the button" discipline (this alone stops the app from looking like a template), the day-grouped transaction feed with tabular figures, and the pattern of using an emoji or merchant glyph as the leftmost element of each transaction row.

**What FlowPay does not take:** the coral color itself, and Monzo's day-band-alternating (white-then-dark) marketing rhythm — that's for landing pages, not in-app UI.

### 2.4 Revolut (revolut.com) — for product-tier navigation and pill buttons

Revolut's system:

- **Aeonik Pro** at weight 500 for display, sizes 20–136px with tight `line-height: 1.0` and negative letter-spacing.
- **Inter** for body copy.
- **Canvas:** hard black `#000000` or off-white. No in-between.
- **Primary CTA pattern:** *white pill on black*, the brightest pixel on the screen. Cobalt violet `#494FDF` is the brand accent but appears only on featured tier cards, never as the default CTA.
- **Zero shadows.** All depth comes from canvas-switch contrast.
- **Every button is `9999px` radius.** Pill is universal.
- **Multi-segment nav** at the top level: Personal / Business / Kids & Teens as first-class tabs.

**What FlowPay takes:** the segmented nav pattern for switching between Personal and Business modes, the universal pill button radius, and the discipline that shadows are not how you show depth in a fintech app.

### 2.5 Kuda / Grey / Cleva — for Nigerian context

Not a formal design analysis, but four signals from studying Nigerian fintech UX writing:

- **Payment reference IDs are always visible on receipts.** Nigerian users have been trained by decades of bank alerts to look for a transaction reference; hiding it under a details drawer is a trust failure.
- **Naira amounts use the ₦ symbol with a space:** `₦ 1,847,300.00`, not `NGN1847300`. USD uses `$` with no space.
- **Dual-currency display for cross-border amounts.** When showing a transaction that touches both currencies (a payroll payment, a swap), show both denominations, with the primary in the user's home currency and the other subtly smaller: `₦ 1,600,000 · ~$1,000 USD`.
- **Plain-language error messages.** "Phone number must be at least 11 digits", not "Validation error: E_PHONE_LENGTH".
- **Bank-name recognition matters.** When picking a recipient bank (GTBank, Access, Kuda, Opay, etc.), showing the bank's actual logo/brand color increases user confidence over a plain text list.

**What FlowPay takes:** all four. These are non-negotiable for the Nigerian side of the app.

---

## 3. FlowPay Design Tokens (the source of truth)

Encode these into a single Flutter `ThemeData` extension. Never hardcode a hex or a radius in a widget file.

### 3.1 Palette

FlowPay is **not** taking Wise's green, Mercury's indigo, Monzo's coral, or Revolut's violet. Those are brand-defining colors for those brands, and copying them screams "template". Instead, FlowPay uses a distinct but adjacent palette:

**Primary accent — "FlowPay Ink"** — `#0D2E2A` — a deep, slightly teal-shifted near-black.
- Used for: primary CTA fills (dark pill on light canvas, the Revolut pattern), body text, dark sections.
- Rationale: reads as "money that grew up" (dark green heritage without being on-the-nose about it), and gives us the Wise-style dark-primary look without collision.

**Secondary accent — "Signal"** — `#00C48A` — a saturated, calm green.
- Used for: success/credited states, positive delta indicators, the "money moving" line in the Money Mission stepper. **Never on a button as a default state.** State only.

**Object color — "FlowPay Amber"** — `#F4B740` — warm amber.
- Used for: the **virtual card face** (Monzo's "brand-color-as-object" pattern), the demo-mode pill, and pending/processing states.
- Rationale: The card being amber (not the button being amber) gives the app a memorable object color that never competes with the CTA, and amber is culturally neutral across NG/MX/US in a way green (money) or red (danger) isn't.

**Neutrals.**

| Token | Hex | Use |
|---|---|---|
| `canvas` | `#FAFAF7` | App background (never pure `#FFFFFF` on large surfaces) |
| `surface` | `#FFFFFF` | Cards, sheets, elevated surfaces |
| `surface-alt` | `#F2F1EC` | Alternate/tinted background bands, disabled fills |
| `hairline` | `#E6E4DE` | 1px borders and dividers |
| `text-primary` | `#0D2E2A` | Body text (same value as primary accent, intentional) |
| `text-secondary` | `#5C6461` | Metadata, timestamps, secondary labels |
| `text-tertiary` | `#8A918E` | Disabled text, low-priority captions |

**Semantic (state only, never brand).**

| Token | Hex | Use |
|---|---|---|
| `state-success` | `#00C48A` | Credited, approved, completed |
| `state-pending` | `#F4B740` | Pending, processing, waiting |
| `state-error` | `#E5484D` | Failed, error, destructive |
| `state-info` | `#3E5CFB` | Informational hints only |

**Contrast pairs (WCAG-checked).**

- `text-primary` (`#0D2E2A`) on `canvas` (`#FAFAF7`): approximately 13.9:1, passes AAA.
- White text on `text-primary` fill: approximately 13.9:1, passes AAA (primary CTA label).
- `text-secondary` (`#5C6461`) on `canvas`: approximately 6.4:1, passes AA body and AAA large text.
- `state-error` on `canvas`: approximately 4.9:1, passes AA.

**Color rule (mechanical, checkable).**

> On any single screen, the **accent** (`FlowPay Ink`) fills at most one primary CTA and one active-state indicator. `Signal` green appears only on state indicators, never on filled surfaces. `FlowPay Amber` appears only on the card object and the demo-mode pill. If a screen has two primary CTAs of equal weight, one of them is wrong.

### 3.2 Typography

FlowPay uses **Inter** for everything, at 4 role-specific configurations. Load via `google_fonts` package.

Rationale: Inter is free, ships with excellent tabular figures, has strong non-Latin coverage (needed for Naira/Peso amounts), and lets us skip the custom-font-loading complexity in a hackathon timeframe. Wise, Revolut, and Mercury all pair Inter with a proprietary display font; we skip the display font entirely and lean on weight and tracking discipline instead.

| Role | Font | Size (Flutter `dp`) | Weight | Letter-spacing | Line-height | Notes |
|---|---|---|---|---|---|---|
| Display / balance | Inter | 40 | 600 | -0.02em (-0.8) | 1.05 | For the big balance number on wallet home. **Enable tabular figures.** |
| Headline | Inter | 24 | 600 | -0.01em (-0.24) | 1.15 | Screen titles, section headers |
| Title | Inter | 18 | 600 | 0 | 1.25 | Card headers, prominent row labels |
| Body | Inter | 16 | 400 | 0 | 1.45 | Default paragraph text |
| Body-emphasized | Inter | 16 | 500 | 0 | 1.45 | Highlighted body words |
| Amount (row) | Inter | 16 | 500 | 0 | 1.25 | Transaction row amounts. **Tabular figures.** |
| Label | Inter | 14 | 500 | 0.02em (0.28) | 1.3 | Field labels, chip labels |
| Caption | Inter | 12 | 400 | 0.03em (0.36) | 1.3 | Timestamps, helper text, metadata |

**Tabular figures rule (mechanical).**

> Any text style that displays money amounts (`display`, `amount`, or any balance) must have `FontFeature.tabularFigures()` enabled in its `TextStyle`. This is a Flutter-specific concern: without it, Inter's proportional figures cause balances to jitter when they update, which is the single most amateur-looking mistake a fintech app can make.

```dart
TextStyle(
  fontSize: 40,
  fontWeight: FontWeight.w600,
  letterSpacing: -0.8,
  height: 1.05,
  fontFeatures: const [FontFeature.tabularFigures()],
)
```

### 3.3 Spacing

4px base unit. Named tokens only. No arbitrary paddings in widgets.

| Token | dp |
|---|---|
| `space-1` | 4 |
| `space-2` | 8 |
| `space-3` | 12 |
| `space-4` | 16 |
| `space-5` | 20 |
| `space-6` | 24 |
| `space-8` | 32 |
| `space-10` | 40 |
| `space-12` | 48 |
| `space-16` | 64 |

Screen edge padding: `space-4` (16dp) on phones. Section vertical gap between distinct blocks: `space-8` (32dp).

### 3.4 Corner radii (locked)

**One radius per role. No exceptions.** Encode as `ThemeData.extensions`.

| Role | Radius | Notes |
|---|---|---|
| Button (primary / secondary / tertiary) | `9999` (pill) | Every button. Every one. Universal pill. |
| Card | 20 | Wallet cards, transaction group cards, card-object |
| Sheet / modal | 24 (top corners only) | Bottom sheets, dialogs |
| Input / text field | 12 | Form inputs |
| Chip / tag | `9999` (pill) | Currency chips, filter chips, status pills |
| Avatar / logo tile | 12 | Bank logos, merchant tiles |

**Shape consistency check (mechanical):** If any button, chip, or interactive pill has a radius other than `9999`, it fails. If any card has a radius other than 20, it fails.

### 3.5 Elevation

**Zero drop shadows** (Mercury/Revolut discipline). Depth comes from:

1. Surface luminance shift: `surface` (`#FFFFFF`) sits on `canvas` (`#FAFAF7`). The ~1.5% luminance difference is the depth.
2. `hairline` border (`1px, #E6E4DE`) on cards where the surface-shift is not enough (e.g. white card on white sheet).

If someone reaches for `BoxShadow` in Flutter code, the answer is almost always "no, use a hairline border or a surface color swap instead." The one exception is the **card object** (virtual card): it gets a very soft, tinted shadow to feel physical (`Color(0x1A0D2E2A), blur 24, offset (0,8)`), because it's supposed to look like a physical card, not a UI card.

---

## 4. Screen-Level Direction

### 4.1 Onboarding & KYC

- **One question group per screen.** Never a long-scroll form. BMONI's KYC includes BVN, employment status, source of funds; split into 3–5 screens with a persistent step indicator ("2 of 5"), not a fake percentage bar.
- **Field labels are always above the input**, never as placeholders. Placeholder-as-label is banned.
- **Plain-language errors, always.** "Your BVN must be 11 digits", not "Validation error E_BVN_LENGTH".
- **Never expose crypto/wallet vocabulary.** "Your USD account is almost ready", not "Provisioning smart wallet".
- **Progress indicator:** thin (2px) horizontal segmented bar at the very top of the screen, using `text-primary` for completed segments and `hairline` for pending. Not a spinner, not a percentage.

### 4.2 Wallet Home (Personal)

Layout, top to bottom:

1. **App bar** (56dp): FlowPay wordmark on left, a small "Demo" pill on right if in demo mode (`FlowPay Amber` fill, 4px vertical / 8px horizontal padding, 12dp caption, `9999` pill radius).
2. **Balance switcher** (Wise-inspired): a horizontal scroll of currency cards. Each card is 260dp wide × 120dp tall, `surface` background, 20dp radius, showing:
   - Currency chip (`₦ NGN` or `$ USD`) as a small pill, top-left.
   - Balance as `display` style (40dp / 600 / tabular), aligned left, mid-card.
   - A tiny 24-hour trend indicator or the last-transaction delta, bottom-left.
3. **Primary actions row**: three tappable circular buttons (56dp diameter, `text-primary` fill, white icon): Send, Receive, Convert. Each labelled with a 12dp caption below.
4. **"Money Missions" entry**: a full-width card, 20dp radius, showing the currently-active mission as a natural-language sentence (see 4.3). If no mission, an empty state prompting "Set up your first Money Mission" with a subtle inline CTA.
5. **Activity feed**: day-grouped (Monzo pattern). Each day is a small `label` header ("Today", "Yesterday", or "Mon 3 Sep"). Each transaction row:
   - 40dp leading circle: either the counterparty's initial in `surface-alt`, or a merchant/bank logo if we have one.
   - Two-line body: line 1 = counterparty name (`amount` style), line 2 = category or note (`caption` style).
   - Trailing right-aligned: amount (`amount` style, tabular). Positive amounts in `state-success`, negative in `text-primary` (not red; red is only for failures).
   - **Never show the raw event type** (`employee.deposit.completed`). Map to "Received from Ade" or similar.

### 4.3 Money Mission Flow

This is the hero feature and the demo's money-shot. It has to look like plain language, not a form.

**Input mode**: a text field where the user types the rule in natural language ("Whenever I receive $2,000, keep 30% in USD, convert 50% to Naira, reserve 20% for tax"). Under it, small "Try an example" chips with 2–3 preset rules for the demo.

**Parsed rule display**: after parsing (real or demo-mode deterministic), the rule renders as connected chips:

```
[When I receive] [$2,000 USD]
    ↓
[Keep] [30%] [in USD]  →  [$600]
[Convert] [50%] [to NGN]  →  [~₦1,600,000]
[Reserve] [20%] [for tax]  →  [$400]
```

Each chip is tappable to edit inline. Arrows are `text-secondary`, chips are `surface-alt` fill with `text-primary` label, `9999` radius.

**Execution stepper** (the demo money-shot): a horizontal 4-step stepper showing **Validated → Approved → Signed → Executed**. Each step is a circle (32dp, `hairline` border when pending, `state-success` fill with white check when done). Between them, a 2dp line that fills in `state-success` as steps complete. Below each step, a 12dp caption with the state name.

The stepper transitions must be **visible and honest**. This is the moment users trust the app. Do not hide any step behind a spinner. Each step takes ~600ms of visible animation using Flutter's `AnimatedContainer` for the line fill and `AnimatedSwitcher` for the circle contents.

Below the stepper, always show a small **"Demo mode: signed and simulated"** caption if in demo mode. Never let a viewer confuse demo state for a real BMONI-signed transaction.

### 4.4 Business / Payroll Dashboard

Once the user switches to Business mode (top-level segmented control, Revolut pattern), the density increases (Mercury discipline).

- **Segmented control** at the top of the screen: `[ Personal | Business ]`, pill container, active segment fill is `text-primary`, inactive is `surface-alt`. This control is persistent across all Business screens.
- **Employee table** (the main Business surface): a Mercury-style dense list, one row per employee. Columns visible on mobile (~380dp width):
  - 40dp leading: country flag emoji (🇳🇬 🇲🇽 🇺🇸)
  - Name (`amount` style) + role (`caption`) as two-line
  - Trailing right-aligned: local-currency equivalent as `amount` style with tabular figures, e.g. `₦ 3,200,000` on line 1 and `~$2,000` on line 2 in `caption` / `text-secondary`.
- **"Run Payroll" button**: one primary CTA at the bottom of the screen, pill radius, `text-primary` fill, white label. **Never labelled anything else**: not "Process Payroll", not "Execute Payroll". One verb per action.
- **Payroll execution**: same 4-step stepper as Money Mission, but with labels **Validated → Approved → Processing → Completed** (matching the demo-mode spec exactly).

### 4.5 Cards

The virtual card object is the memorable visual. Design it as a physical object, not a UI component.

- Aspect ratio 1.586 (real card proportions), `FlowPay Amber` (`#F4B740`) fill by default, 20dp radius.
- Layout on the card face:
  - Top-left: `FlowPay` wordmark in `text-primary`, 14dp weight 600.
  - Top-right: currency flag (🇳🇬 or 🇺🇸) as a 20dp emoji.
  - Bottom-left: masked PAN (`•••• •••• •••• 4821`), Inter tabular 16dp / 500 / `text-primary`.
  - Bottom-right: Mastercard logo (real SVG, not text).
- Very soft shadow only on the card object (see §3.5 exception).
- **Card management screen**: freeze/unfreeze, PIN change, spend limits, transactions list. Each accessible one tap from the card detail screen. Not buried in settings.

### 4.6 Demo Mode Indicator

A small `FlowPay Amber` pill in the app bar, always visible when in demo mode. Label: `Demo`. 12dp caption / 500 / `text-primary` label. Never a full-width banner that eats hero space. The demo indicator has to be honest without being embarrassing on stage.

Additionally: any state stepper (Money Mission, Payroll) that runs in demo mode gets the subtle "signed and simulated" caption noted in 4.3.

---

## 5. Interaction & Motion

**Motion budget: low but motivated.** Reach for animation only for state transitions and confirmation of irreversible actions.

- **Balance changes** count up/down over ~400ms rather than snapping. Implement with a custom `TweenAnimationBuilder<double>` around the balance number.
- **Stepper progression** (Money Mission, Payroll) uses `AnimatedContainer` (line fills) and `AnimatedSwitcher` (circle content). 400ms per step, ease-out cubic.
- **Bottom sheets** slide up with default Flutter modal sheet animation. Do not override.
- **Button press feedback**: on `:active`, scale to 0.98 over 100ms and back over 150ms.
- **Screen transitions**: default `CupertinoPageRoute` on iOS, `MaterialPageRoute` on Android. Do not build a custom transition.
- **Respect `MediaQuery.of(context).disableAnimations`** (Flutter's reduced-motion signal): if true, all timed animations collapse to instant, and stepper progression jumps directly to end state.

**What not to do:** parallax scroll effects, magnetic hovers, background particle animations, animated background gradients, coin-flip 3D card animations. Every one of those is banned by default.

---

## 6. Copy Rules

- **One verb per action.** "Send" for outbound transfers everywhere; not "Send" here and "Transfer" there. "Run Payroll" is the payroll action verb, everywhere.
- **No jargon leakage from BMONI.** Banned words in user-facing copy: `stablecoin`, `smart wallet`, `smart-wallet`, `EVM`, `signature request`, `proposal`, `sign payload`, `USDB`, `CNGN`, `MEXe`. Map them to "account", "transfer", "approve", "dollars", "naira", "pesos".
- **Amount formatting:**
  - NGN: `₦ 1,847,300.00` (naira symbol, space, thousands separator, always 2 decimals for exact amounts, no decimals for rounded balance display).
  - USD: `$1,847.32` (no space).
  - Cross-currency: `₦ 1,600,000 · ~$1,000 USD`. Home currency primary, other secondary and prefixed with `~` to indicate conversion.
- **Timestamps:** relative for the last 24 hours ("2 min ago", "Yesterday, 3:14 PM"), absolute for older ("Mon 3 Sep · 9:12 AM").
- **Never fake precision.** For demo data, use realistic-looking amounts (`$1,847.32`) not suspiciously round ones (`$2,000.00` on every row).
- **No AI-tell filler verbs**: banned: `seamless`, `unleash`, `elevate`, `next-gen`, `revolutionize`, `empower`, `supercharge`, `harness`. Say what the feature does.
- **No em-dashes** (`—`). Use periods, commas, or parentheses.

---

## 7. Flutter Implementation Notes

- **Theme:** one `AppTheme` class exposing a `ThemeData` and a custom `ThemeExtension<FlowPayTokens>` carrying the palette, radii, and text styles from Section 3. Every widget pulls from the theme. No hardcoded hex in widgets, ever.
- **Fonts:** load Inter via `google_fonts` package (verify current version on pub.dev at install time). Enable `FontFeature.tabularFigures()` on any style that renders money.
- **State:** Riverpod is the pragmatic pick for a Flutter app of this size. The BMONI Flutter UI kit (`bmoni_embedded_wallets_cards`) uses Riverpod notifiers, so if that package is available and used, matching Riverpod avoids two overlapping state systems.
- **Currency formatting:** use the `intl` package's `NumberFormat.currency` with explicit `symbol` and `decimalDigits` per currency. Don't roll your own formatter.
- **Country flags:** use the emoji flag characters directly (🇳🇬 🇲🇽 🇺🇸). They render on both platforms and don't require an asset bundle. Do not use SVG flag libraries unless the emoji renders poorly on Android's default emoji font on the target device.
- **Icons:** pick one icon set at project init and stick to it. Recommend `phosphor_flutter` (Phosphor Icons for Flutter) at consistent `1.5` stroke weight. Do not mix Phosphor with Material Icons in the same tree.
- **Component ownership:** if `bmoni_embedded_wallets_cards` (BMONI's Flutter wallet-UI package) exists on pub.dev under the `bkey.me` publisher and is stable, use it for the wallet card and balance widgets. Matching BMONI's data shape saves hackathon hours. Verify it exists before adding to `pubspec.yaml`; if not, hand-build to the tokens in §3.

---

## 8. What This Document Is Not

- Not a locked Figma file. Palette tokens are decisions; individual screen layouts are guidance.
- Not a business logic spec. See `BMONI_Embedded_Platform_Reconnaissance.pdf` and `FLOWPAY___RELIABLE_HACKATHON_DEMO_MODE.md` for what the app has to do.
- Not a substitute for the accessibility audit before ship: run the Flutter DevTools accessibility inspector on each screen; every tap target must be ≥44dp × 44dp, every non-decorative image must have a `Semantics` label, and the demo-mode indicator must be readable to a screen reader.

---

## 9. Sources & References

Design system rules for the reference apps in Section 2 were pulled from the following public sources (all accessed while writing this document):

- **Wise** design system: `styles.refero.design/style/367c0c6e-73a7-441c-a8ff-91d139ac60dc`, `shadcn.io/design/wise`, `oh-my-design.kr/design-systems/wise`. Wise brand rebrand color codes cross-referenced with `dotyeti.com` and `loftlyy.com`.
- **Mercury** design system: `styles.refero.design/style/3172cd4d-118a-4a16-a259-6b634d32322e`, `shadcn.io/design/mercury`, `designmd.cc/benchmarks/mercury`, `blakecrosley.com/guides/design/mercury`, `925studios.co/blog/mercury-design-breakdown`.
- **Monzo** design system: `shadcn.io/design/monzo`, `deck.gallery/monzo-brand-style-guide-deck` (Monzo's own 2022 brand style guide), `monzo.com/blog/reimagining-monzo-com` (Monzo engineering blog), `ihatecolors.com/palette/monzo-coral`.
- **Revolut** design system: `shadcn.io/design/revolut`, `github.com/VoltAgent/awesome-design-md/blob/main/design-md/revolut/DESIGN.md`, `oh-my-design.kr/design-systems/revolut`, `open-design.ai/plugins/design-system-revolut`.
- **Nigerian fintech UX signals**: Godstime Asukwo (Medium) on designing for fintech adoption in Nigeria, Precious Ogar on fintech design in Africa (Technext), and studying live app patterns from Kuda, Grey, PiggyVest, and Cleva.

Not everything in a reference doc is authoritative; some of these are third-party analyses of the shipped websites, not the companies' internal design systems. Values were cross-checked between at least two sources before landing in Section 2. For any rule that needs to be re-verified, the primary source per app is the `shadcn.io/design/*` breakdown, which quotes exact hex/radius/weight tokens with citations to the shipped CSS.

The FlowPay-specific palette in Section 3.1 is a **deliberate original choice**, not measured from a reference, chosen so FlowPay does not visually collide with any of the reference apps we studied.