---
name: flowpay-design
description: >-
  Establishes the FlowPay Design System — an independent, dark-mode first, premium
  fintech visual identity. Consult this skill for all UI development, styling standards,
  color tokens, typography, and component usage rules.
---

# FlowPay Design System Standards

## 1. Overview & Visual Identity

FlowPay is an AI-powered financial operating system designed with an independent, premium fintech visual identity.

> [!IMPORTANT]
> **Zero BMONI UI Kit Dependency**: FlowPay does NOT depend on `bkey_uikit` or BMONI's visual design language. The BMONI SDK (`bmoni_embedded_sdk`) is utilized strictly as an unstyled, on-device cryptographic PIN/hardware enclave driver.

### Core Visual Principles:
- **Obsidian Palette**: Deep Obsidian Slate dark background (`#090A0F`), high-contrast dark surfaces (`#12141C`, `#181B26`), and subtle hairline borders (`#232838`).
- **Signature Accents**: FlowPay Electric Emerald (`#00E599`) for primary actions, autonomous AI executions, and positive cash flow; Vivid Cyan (`#00D2FF`) for multi-currency routing; Warm Amber (`#FFB020`) for security approvals; Rose (`#FF4D4D`) for risk/rejection.
- **Financial Typography**: Google Fonts Inter with explicit hierarchy. All monetary values, balances, and exchange rates use tabular figure formatting (`FontFeature.tabularFigures()`) to prevent numeral jitter during real-time balance shifts.
- **Glassmorphism & Surfaces**: Frosted glass cards (`FlowPayGlassCard`), subtle radial gradients, 16px corner radii for cards, and 24px corner radii for modals and sheets.
- **Tactile Interactivity**: Smooth micro-animations, clear loading indicators, and dedicated reassurance banners ("Nothing moves until you approve.").

---

## 2. Color Tokens (`FlowPayColors`)

| Token | Hex / Value | Usage |
| :--- | :--- | :--- |
| `FlowPayColors.darkBackground` | `#090A0F` | Primary Scaffold dark background |
| `FlowPayColors.darkSurface` | `#12141C` | Default Card / Surface background |
| `FlowPayColors.darkSurfaceElevated` | `#181B26` | Elevated cards, sheets, dialogs, popovers |
| `FlowPayColors.darkBorder` | `#232838` | Structural card borders and dividers |
| `FlowPayColors.primary` | `#00E599` | FlowPay Electric Emerald — Primary CTA & highlights |
| `FlowPayColors.primaryLight` | `#33EAB0` | Hover states, active icons, status accents |
| `FlowPayColors.accent` | `#00D2FF` | Vivid Cyan — Cross-currency FX & AI routing |
| `FlowPayColors.amber` | `#FFB020` | Security approvals, pending signatures |
| `FlowPayColors.error` | `#FF4D4D` | Danger actions, errors, rejections |
| `FlowPayColors.darkTextPrimary` | `#F3F4F6` | High-contrast readable body & headings |
| `FlowPayColors.darkTextSecondary` | `#9CA3AF` | Secondary labels, descriptions, timestamps |
| `FlowPayColors.darkTextMuted` | `#6B7280` | Placeholder text, subtle metadata |

---

## 3. Component Architecture (`lib/core/design_system/`)

### 1. Buttons (`FlowPayButton`)
Primary action button supporting `primary`, `secondary`, `outline`, `ghost`, and `danger` variants, multiple sizes, loading states, and icon decorations.
```dart
FlowPayButton(
  text: 'Approve & Send',
  icon: Icons.lock_outline,
  size: FlowPayButtonSize.large,
  isLoading: isProcessing,
  onPressed: handleApprove,
)
```
*Backward-compatibility aliases are provided: `BMoniButton = FlowPayButton`.*

### 2. Wallet Cards (`FlowPayWalletCard`)
Multi-currency smart wallet presentation cards featuring gradient overlays, privacy hide/reveal toggles, currency badges, and balance displays.
```dart
FlowPayWalletCard(
  currency: 'USD',
  balance: '$12,450.80',
  walletName: 'USD Smart Vault',
  isLocked: false,
  onTap: () => viewWalletDetails(),
)
```
*Backward-compatibility aliases: `BMoniWalletCard`, `BMoniWalletCardBalance`.*

### 3. Financial Typography & Amount Display (`FlowPayAmount`, `FlowPayTypography`)
Splits amounts into large whole parts and smaller superscript/subscript decimal parts with tabular numerals.
```dart
FlowPayAmount(
  amount: '$2,450.00',
  isPositive: true,
  size: FlowPayAmountSize.large,
)
```

### 4. Modals & Sheets (`FlowPayBottomSheet`, `FlowPayDialog`)
Dark-surfaced bottom sheets and dialogs with drag handles, rounded corners (24dp), and clear approval hierarchy.
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: FlowPayColors.darkBackground,
  builder: (_) => TransferReviewModal(...),
);
```

### 5. Reassurance Banners
All AI-suggested or automated money movements must feature the security trust banner:
> **"Nothing moves until you approve."**
> *Requires on-device PIN signature • Zero unauthorized movement*

---

## 4. UI Directives & Safety Rules

1. **No BMONI UI Kit imports** (`import 'package:bkey_uikit/...'` is strictly prohibited).
2. **On-Device Cryptographic Enclave**: The BMONI SDK is accessed solely via `BmoniSdkService` for on-device cryptographic PIN signing and key isolation.
3. **Strict Tabular Figures**: Use `FlowPayTypography.tabularFigures` for all live financial balances and conversion displays.
4. **Adaptive Dual Role Architecture**: Preserve the smooth animated role switcher (`FlowPayRoleSwitcher`) between Personal and Business modes.
