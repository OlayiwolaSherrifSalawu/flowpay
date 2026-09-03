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
- **Key dependencies**: `bmoni_embedded_sdk: ^0.0.2`, `bkey_uikit: ^0.0.1`, `bmoni_embedded_wallets_cards: ^0.0.1`, `flutter_riverpod: ^3.2.1`, `flutter_secure_storage: ^10.0.0`.

---

## 2. Key Files & Architecture
- `lib/core/money/money.dart`: Central integer minor-unit Money class and currency mappings (`lib/core/money/currency.dart`).
- `lib/core/safety/`: Financial safety state machine (`financial_intent.dart`, `operation_preview.dart`, `signing_coordinator.dart`).
- `lib/core/bmoni_sdk/bmoni_sdk_service.dart`: On-device hardware enclave wrapper for wallet provisioning (`initWallet`) and signing (`signMessage`, `signTransactionHash`).
- `lib/core/theme/`: Dual theme engine (`theme.dart`, `app_theme.dart`), BMoni Obsidian/Plum palette (`colors.dart`), 8-point grid tokens (`spacing.dart`), tabular monospaced typography (`typography.dart`), aligned with official `bkey_uikit`.
- `lib/core/design_system/`: 13 shared primitives powered by `bkey_uikit` (`buttons.dart`, `cards.dart`, `input_fields.dart`, `status_badges.dart`, `amount_display.dart`, `currency_display.dart`, `bottom_sheets.dart`, `dialogs.dart`, `states.dart`). For styling guidelines, consult `.agents/skills/flowpay-design/SKILL.md`.
- `lib/core/navigation/`: Modular navigation architecture (`app_routes.dart`, `personal_routes.dart`, `business_routes.dart`, `role_switcher.dart`, `app_router.dart`).
- `lib/core/repositories/`: Unified repository contracts (`WalletRepository`, `TransferRepository`, `CardRepository`, `EmployeeRepository`, `PayrollRepository`).
- `lib/core/providers/`: Concrete implementations for `demo/` (deterministic sandbox test data) and `bmoni/` (talking through backend proxy).
- `lib/modules/personal/`: Personal Dashboard, Wallets, Money Missions, Send Money, Activity, Security.
- `lib/core/auth/`: App-lock biometrics & mode routing architecture:
  - `account_capabilities.dart`: Capabilities model (`hasPersonalWallet`, `hasBusinessAccess`) and `AccountMode` enum.
  - `secure_storage_service.dart`: Encrypted storage wrapper with 15-minute TTL caching.
  - `app_lock_service.dart`: `local_auth` wrapper with biometric & passcode fallbacks, handling `LocalAuthException` error cases without custom lockout duplication.
  - `auth_providers.dart`: Riverpod providers (`currentAccountModeProvider`, `accountCapabilitiesProvider`, `appLockStateProvider`).
  - `account_mode_picker_modal.dart`: Segmented mode selection bottom sheet conforming to `design.md` §4.4.
  - `app_auth_gate.dart`: Biometric gate with lifecycle observer re-locking on app resume after 45s.
- `lib/modules/personal/personal_shell.dart`: Independent Personal mode navigation shell (5 destinations) with its own app bar, role switcher, and isolated navigation stack.
- `lib/modules/business/business_shell.dart`: Independent Business mode navigation shell (4 destinations) with its own app bar, role switcher, and isolated navigation stack.
- `lib/app.dart`: Clean root application wrapped in `ProviderScope` routing between `PersonalShell` and `BusinessShell` via `AppAuthGate`.

---

## 3. What Has Been Done
- [x] Full directory architecture and dependency contracts configured.
- [x] BMONI SDK wrapper enforcing on-device key management with non-native test fallback.
- [x] Complete provider abstraction separating Demo and BMONI backends.
- [x] Pre-loaded sandbox personas (Bunch Dillon [NGN], Samson Jabo [MXN], Liam Tremblay [CAD]).
- [x] Dedicated `BusinessProvider` (`lib/core/state/business_provider.dart`) state coordinator managing dashboard metrics and payroll execution.
- [x] FlowPay Business Employer Dashboard with "One Employer. Many Countries. One Bill." hero card, metrics grid, employee preview with 7 attributes, and primary (Run Payroll) & secondary (Add Employee) actions.
- [x] Complete 13 shared design primitives and 9 shared app states (`FlowPayAppStatus`, `FlowPayStateView`).
- [x] Dual Theme engine (`FlowPayTheme.dark()`, `FlowPayTheme.light()`) with accessible contrast and runtime toggling.
- [x] Modular navigation architecture with unconfusing animated role switcher.
- [x] Foundation screens for all 11 required screens across Personal and Business modules.
- [x] FlowPay Business Employee Management:
  - `AddEmployeeModal`: Rebuilt using `bkey_uikit` primitives: `BMoniTextFormField.filled`, `SelectorBottomSheet<CountryOption>` via `BMoniBottomSheet.show`, auto-resolving currency and default salary, `BMoniButton(variant: primary)`, and `BMoniToastOverlay`.
  - `EmployeesScreen`: Built with `bkey_uikit` `EmptyState` for zero-employee states, per-row flag emojis, payroll currency and amounts, 6-stage lifecycle badges (`CREATED`, `WALLET_PENDING`, `KYC_PENDING`, `ONBOARDING`, `READY`, `FAILED`), and wallet/card status indicators.
  - `EmployeeDetailScreen`: Built with Identity section, Financial section, BMONI on-chain linkage (`bmoniUserId`, EVM address), KYC compliance indicators (Pass/Fail/Pending — never exposes raw docs), and card freeze controls.
- [x] Automated widget and shell tests passing in `test/app_shell_test.dart` and `test/design_system_test.dart`.
- [x] **Personal Financial Dashboard**:
  - `PersonalDashboardScreen` featuring portfolio valuation ($37,671.00 USD primary), available balances, privacy toggle, and sandbox demo indicator.
  - `AiCommandBar` ("What should your money do?") with task-specific workflow routing: "Allocate my $2,000" (`AiAllocationModal`), "Send $500 to my designer" (`SendMoneyScreen`), and "Convert $1,000 to Naira" (`AiFxConversionModal`).
  - `PendingApprovalsCard` surfacing pending actions with B-Key 6-digit PIN dialog.
  - Quick Actions ("Create Mission", "Send Money", "View Wallets").
  - `Money Missions` feature card & active autonomous mission switches.
  - Multi-Currency Smart Wallets (USD, NGN, MXN, CAD) with one-tap clipboard address copy.
  - Recent Financial Activity feed powered by `ActivityRepository`.
  - State management via `PersonalProvider` coordinating `walletRepo`, `missionRepo`, `approvalRepo`, and `activityRepo`.
- [x] Automated widget and shell tests passing in `test/app_shell_test.dart`, `test/design_system_test.dart`, `test/signup_kyc_test.dart`, and `test/personal_dashboard_test.dart` (23/23 tests passing).
- [x] 0 static analysis errors/warnings via `flutter analyze`.

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
