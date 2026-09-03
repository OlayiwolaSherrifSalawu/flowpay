---
name: flowpay-mobile
description: >-
  Provides operational instructions, architecture, and technical documentation for the
  FlowPay Flutter mobile application, design system, BMONI SDK wrapper, and provider abstractions.
---

# Subsystem: FlowPay Flutter Mobile Application

## 1. Overview & Purpose
- **What it does**: Provides a mobile-first, consumer-grade fintech product experience for Personal and Business users.
- **Why it exists**: Interfaces with BMONI on-device embedded wallet SDK (`bmoni_embedded_sdk`), guarantees zero private key leakage, and provides linear-grade polish and AI product clarity.
- **Key dependencies**: `bmoni_embedded_sdk: ^0.0.2`, `bkey_uikit: ^0.0.1`, `bmoni_embedded_wallets_cards: ^0.0.1`, `flutter_riverpod: ^2.5.1`, `flutter_secure_storage: ^9.2.2`.

---

## 2. Key Files & Architecture
- `lib/core/money/money.dart`: Central integer minor-unit Money class and currency mappings (`lib/core/money/currency.dart`).
- `lib/core/safety/`: Financial safety state machine (`financial_intent.dart`, `operation_preview.dart`, `signing_coordinator.dart`).
- `lib/core/bmoni_sdk/bmoni_sdk_service.dart`: On-device hardware enclave wrapper for wallet provisioning (`initWallet`) and signing (`signMessage`, `signTransactionHash`).
- `lib/core/repositories/`: Unified repository contracts:
  - `WalletRepository`
  - `TransferRepository`
  - `CardRepository`
  - `EmployeeRepository`
  - `PayrollRepository`
- `lib/core/providers/`: Concrete implementations for `demo/` (deterministic sandbox test data) and `bmoni/` (talking through backend proxy).
- `lib/core/theme/`: Design tokens, colors (`colors.dart`), tabular number typography (`typography.dart`), reusable cards, buttons, badges (`components.dart`).
- `lib/modules/personal/`: Personal Dashboard, Wallets, Money Missions, Send Money, Activity, Security.
- `lib/modules/business/`: Business Dashboard, Global Team, Employee Detail, Multi-country Payroll ("One Employer, Many Countries, One Bill"), Audit.
- `lib/app.dart`: Application shell with instant role switcher (Personal vs Business) and provider mode toggle (Demo vs BMONI).

---

## 3. What Has Been Done
- [x] Full directory architecture and dependency contracts configured.
- [x] BMONI SDK wrapper enforcing on-device key management with non-native test fallback.
- [x] Complete provider abstraction separating Demo and BMONI backends.
- [x] Pre-loaded sandbox personas (Bunch Dillon & Samson Jabo).
- [x] Scaffolding for all 11 required screens across Personal and Business modules.

---

## 4. What Needs to Be Done (Next Steps)
- Personal track owner: Extend Money Missions builder and polish send animations.
- Business track owner: Connect deep-link sharing for employee invites and spend limit controls.

---

## 5. Usage & Verification
```bash
cd mobile
flutter pub get
flutter run
```
