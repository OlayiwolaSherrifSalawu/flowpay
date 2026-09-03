---
name: flowpay-design
description: >-
  Establishes the FlowPay Design System powered by the official BMoni UI Kit (bkey_uikit).
  Consult this skill for all UI development, styling standards, color tokens, typography,
  and component usage rules to maintain strict BMoni visual consistency across the entire app.
---

# FlowPay Design System & BMoni UI Kit Standards

## 1. Overview & Visual Identity
FlowPay is built on the official **BMoni UI Kit (`bkey_uikit`)** ecosystem. All screens and components must adhere to the high-contrast, dark-plum obsidian aesthetic of BMONI.

### Core Visual Principles:
- **Palette**: Deep Obsidian/Plum dark mode (`BMoniColors.offbrand950` `#1C0C1C`), elevated surfaces (`offbrand900` `#240D24`, `offbrand800` `#351835`), and signature magenta brand accents (`BMoniColors.brand500` `#B001B0`, `brand400` `#C94CD7`).
- **Typography**: Clean, readable sans-serif typography via `BMoniTextStyles` with explicit hierarchy (d1–d6 display, h1–h6 headings, p1–p4 body, l1–l4 labels). Numbers representing balances and financial amounts must use tabular alignment.
- **Elevation & Surfaces**: Frosted glass effects, thin borders (`offbrand700` `#4C274C` / `offbrand800`), 16px corner radii for cards, and 24px corner radii for modals and section containers.
- **Interactivity**: Micro-animations on press, tactile feedback on monetary actions, and clear loading/disabled states.

---

## 2. Color Tokens (`BMoniColors`)

| Token | Hex / Value | Usage |
| :--- | :--- | :--- |
| `BMoniColors.offbrand950` | `#1C0C1C` | Primary Scaffold dark background |
| `BMoniColors.offbrand900` | `#240D24` | Default Card / Surface background |
| `BMoniColors.offbrand800` | `#351835` | Elevated surfaces, sheets, popovers |
| `BMoniColors.offbrand700` | `#4C274C` | Borders, dividers, subtle outlines |
| `BMoniColors.brand500` | `#B001B0` | Primary brand CTA, active tabs, buttons |
| `BMoniColors.brand400` | `#C94CD7` | Hover / focus / highlighted brand accents |
| `BMoniColors.brand700` | `#690669` | Pressed state / dark brand accents |
| `BMoniColors.accent400` | `#2B88D1` | Secondary accents, informational badges |
| `BMoniColors.success400` | `#00E676` | Positive balance growth, success states |
| `BMoniColors.warning400` | `#FFB300` | Approvals needed, pending actions |
| `BMoniColors.error400` | `#FF5252` | Error states, dangerous actions, rejection |
| `BMoniColors.grey50` | `#F9F9FA` | Primary high-contrast text |
| `BMoniColors.grey400` | `#9E9EA4` | Secondary / muted text labels |

---

## 3. UI Kit Components (`bkey_uikit`)

### 1. BMoniWalletCard & BMoniWalletCardBalance
Used for all multi-currency smart wallet displays (USD, NGN, MXN, EUR).
```dart
import 'package:bkey_uikit/bkey_uikit.dart';

BMoniWalletCard(
  background: BMoniWalletCardBackground.gradient(
    const LinearGradient(
      colors: [Color(0xFF3D003D), Color(0xFF1C0C1C)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  balanceChild: BMoniWalletCardBalance(
    wholePart: '12,450',
    decimalPart: '.80',
    isHidden: false,
    onToggleHidden: () => setState(() => isHidden = !isHidden),
    balanceColor: BMoniColors.grey50,
  ),
)
```

### 2. BMoniButton
Standard action button with built-in loading and disabled states:
```dart
BMoniButton(
  text: 'Send Payment',
  variant: BMoniButtonVariant.primary,
  size: BMoniButtonSize.large,
  isLoading: isProcessing,
  onPressed: handleSend,
)
```

### 3. SectionHeader
Used to demarcate major screen sections with standard BMoni typography and dividers:
```dart
SectionHeader(
  title: 'Recent Activity',
  backgroundColor: Colors.transparent,
  showBottomDivider: true,
  trailing: TextButton(onPressed: viewAll, child: Text('See All')),
)
```

### 4. Custom Inputs & Amount Display
- Input cards must use `BMoniColors.offbrand900` background with `BMoniColors.offbrand700` border.
- Monetary amount displays must split the integer and fractional parts with tabular numerals.

---

## 4. UI Invariants (Strict Rules)
1. **Never use generic blue/slate colors (`#0B0F17`, `#6366F1`)** — all surfaces must use `BMoniColors` tokens (`offbrand950`, `offbrand900`, `brand500`).
2. **Never create raw, unstyled buttons** — wrap or use `BMoniButton`.
3. **Always use BMoni wallet cards** for balance displays rather than plain flat boxes.
4. **Preserve dual role switching** (`FlowPayRoleSwitcher`) with smooth animated transitions.
