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
- `lib/core/missions/`: Money Missions domain models and validation (`mission_intent.dart`, `mission_validator.dart`).
- `lib/modules/personal/`: Personal Dashboard, Wallets, Money Missions (`money_missions_screen.dart`, `components/mission_card.dart`, `components/mission_preview_modal.dart`), Send Money, Activity, Security.
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
- [x] FlowPay Business Employee Management & Onboarding (Model B):
  - `AddEmployeeModal`: Rebuilt using `bkey_uikit` primitives: `BMoniTextFormField.filled`, `SelectorBottomSheet<CountryOption>` via `BMoniBottomSheet.show`, auto-resolving currency and default salary, `BMoniButton(variant: primary)`, and `BMoniToastOverlay`.
  - `EmployeesScreen`: Uses the shared `FlowPayEmptyState` for zero-employee states, plus per-row flag emojis, payroll currency and amounts, 6-stage lifecycle badges (`CREATED`, `WALLET_PENDING`, `KYC_PENDING`, `ONBOARDING`, `READY`, `FAILED`), and wallet/card status indicators.
  - `EmployeeOnboardingScreen`: Interactive multi-stage onboarding wizard (Stage 2 wallet provisioning with on-device PIN signing, Stage 3 Nigeria BVN/no-selfie vs Mexico CURP/RFC/Sumsub liveness selfie, Stage 4 Etherfuse agreements signing sheet modal & rail activation).
  - `EmployeeDetailScreen`: Enhanced with 4-state Onboarding Progress card displaying actual stages (Stage 2, Stage 3, Stage 4), failed stage tracking, retry stage trigger, and refresh status controls.
  - `EmployeeRepository`: Abstracted `OnboardingStageState`, `StageDetailModel`, `EmployeeOnboardingStatusModel`, `getOnboardingStatus`, `retryStage`, and `submitMexicoAgreements`.
- [x] **FlowPay Business — Employee Wallet Control Center (`bmoni_embedded_wallets_cards`)**:
  - `lib/core/wallets_cards/`: Embedded wallets & cards toolkit adhering to official package contract:
    - `EmbeddedWalletReadDataSource`: `fetchWallets()`, `fetchWalletDetail(walletId)`, `fetchBalance(walletId)`, `fetchTransactions(walletId)`.
    - `EmbeddedWalletStorage` & `InMemoryEmbeddedWalletStorage`.
    - `EmbeddedWalletBalanceCache` & `InMemoryEmbeddedWalletBalanceCache`.
    - Functional `Either<EmbeddedFailure, T>` with full typed failure hierarchy (`EmbeddedServerFailure`, `EmbeddedNetworkFailure`, `EmbeddedRateLimitFailure`, `EmbeddedNotFoundFailure`, `EmbeddedAuthenticationFailure`, `EmbeddedAuthorizationFailure`).
    - Riverpod notifiers & providers: `EmbeddedWalletListNotifier` (`walletListProvider`), `EmbeddedWalletBalanceNotifier` (`walletBalancesProvider`), `EmbeddedWalletTransactionsNotifier` (`walletTransactionsProvider`).
    - Model-aware `EmbeddedWalletCard`: wraps `BMoniWalletCard` with 6 built-in currency background art variants (`BMoniWalletType.ngn`, `BMoniWalletType.mxn`, `BMoniWalletType.usd`, `BMoniWalletType.cad`, `BMoniWalletType.eur`, `BMoniWalletType.gbp`) selected by employee payroll currency.
    - Model-aware `EmbeddedWalletTransactionsSection`: composed recent-activity list with host-driven row builder applying `design.md` copy rules (never exposing raw event strings).
  - Both `DemoWalletRepository` and `BmoniWalletRepository` satisfy the identical `EmbeddedWalletReadDataSource`, `EmbeddedWalletStorage`, and `EmbeddedWalletBalanceCache` contracts.
  - `EmployeeDetailScreen` transformed into a dedicated Wallet Control Center with `View Wallet` (specification modal), `Transactions` (full history sheet), and `Issue Card` (virtual Mastercard issuance modal routing into Prompt 12).
- [x] Automated widget and shell tests passing in `test/app_shell_test.dart` and `test/design_system_test.dart`.
- [x] **Personal Financial Dashboard**:
  - `PersonalDashboardScreen` featuring portfolio valuation ($37,671.00 USD primary), available balances, privacy toggle, and sandbox demo indicator.
  - `AiCommandBar` ("What should your money do?") with task-specific workflow routing.
  - `PendingApprovalsCard` surfacing pending actions with B-Key 6-digit PIN dialog.
  - Quick Actions ("Create Mission", "Send Money", "View Wallets").
  - `Money Missions` feature card & active autonomous mission switches.
  - Multi-Currency Smart Wallets (USD, NGN, MXN, CAD) with one-tap clipboard address copy.
  - Recent Financial Activity feed powered by `ActivityRepository`.
- [x] **Flagship Money Missions Screen & Pipeline (`lib/modules/personal/money_missions_screen.dart`)**:
  - Heading *"Tell your money what to do."* with tagline *"Your money. Your rules. AI executes."*.
  - 5 Suggestion chips prefilling financial directives ("Split incoming payment", "Save for a goal", "Convert currency", "Send money", "Reserve for taxes").
  - 3-stage animated progress pipeline: Analyzing intent → Validating rules → Generating BMONI proposal.
  - `MissionPreviewModal` rendering incoming funds and exact allocation splits with "Nothing moves until you approve" reassurance.
  - Hardware B-Key 6-digit PIN signing via `WalletPinAuthSheet`.
  - Confirmed execution dialog with transaction hash and live state update.
  - Active missions list with `MissionCard` components featuring ⚡ Run Now triggers and active status toggle.
- [x] **Send Money Screen & Balance-Aware Routing (`lib/modules/personal/send_money_screen.dart`)**:
  - Natural Language Entry with 4 quick suggestion chips ("Send $500 to my designer in Ghana", etc.).
  - 3-stage animated analysis indicator (`Interpreting intent` → `Inspecting wallet balances` → `Generating proposal`).
  - Balance-Aware auto-funding card highlighting routing and required conversion when direct balance is insufficient.
  - Interactive multi-currency funding wallet selector with live balance displays.
  - `TransferReviewModal`: Premium confirmation bottom sheet with recipient, amount, currency, funding source, conversion label/badge, exchange rate, fee breakdown, total debit, and **"Nothing moves until you approve."** security reassurance banner.
  - On-device B-Key PIN hardware signing via `WalletPinAuthSheet` with 6-digit numeric PIN pad.
  - Celebratory receipt dialog `TransferReceiptDialog` with EVM transaction hash and Activity navigation.
  - 8 failure modes with human-readable feedback.
  - 91/91 Flutter tests passing (`test/send_money_flow_test.dart`), 0 analyzer lints.
- [x] **Personal Activity Ledger & Transaction Detail (`lib/modules/personal/personal_activity_screen.dart`, `components/activity_detail_modal.dart`)**:
  - Displays Transfers, Conversions, Mission executions, Wallet operations, Card transactions, Pending approvals, and Failures.
  - 8 Category filter chips and search input for counterparty and references.
  - 6 Statuses: Pending, Processing, Awaiting Approval, Completed, Failed, Cancelled with `FlowPayAppStatus.cancelled` support.
  - `ActivityDetailModal`: Displays Amount, Currency (USDB, CNGN, MEXe, CADC), Source, Destination, Fee, Exchange Rate, Timestamp, FlowPay Reference, and BMONI Reference.
  - Guarantees zero exposure of private keys, unnecessary signing payloads, or API credentials.
  - In-modal and inline 1-tap B-Key hardware PIN authorization for pending transactions.
- [x] **Personal Security & Cryptographic Hardware Keys (`lib/modules/personal/personal_security_screen.dart`)**:
  - 3 Core Sections: Wallet Security, Signing Security, Approval Rules.
  - Prominent banner & enforcement: **"Financial actions require your approval."** (AI is strictly advisory with zero execution rights).
  - Dynamic indicators showing whether:
    - Wallet is initialized (`INITIALIZED` vs `NOT INITIALIZED`) with public EVM address.
    - Device signing is available (`AVAILABLE & ACTIVE`) supporting EIP-191 & EIP-712 hashing.
    - PIN protection is enabled (`PIN CONFIGURED (6 DIGITS)`) with salted PBKDF2-HMAC-SHA256.
  - 4 Invariants of Financial Safety and Active Approval Policy Matrix.
  - No unsupported claims: Strict reliance on on-device BMONI B-Key SDK and local biometrics.
  - 99/99 Flutter tests passing (`test/personal_activity_test.dart`, `test/personal_security_test.dart`), 0 analyzer lints.
- [x] **Complete Personal Feature Integration (Dashboard, Wallets, Missions, Send Money, Activity, Security)**:
  - Unified `AppState` singleton wired into `PersonalShell` and `BusinessShell` in `FlowPayApp` (`lib/app.dart`).
  - Cross-tab coordination via `personalTabIndexProvider` (`lib/core/navigation/personal_tab_provider.dart`), `IndexedStack` view preservation in `PersonalShell`, and responsive navigation from Dashboard Quick Actions ("Send Money", "Create Mission", "View Wallets").
  - Atomic wallet debiting and crediting via `debitWallet`/`creditWallet` in `WalletRepository` and `DemoWalletRepository`.
  - Unified activity ledger auto-refreshing via `appState` listeners in `PersonalActivityScreen` and `WalletsScreen`.
  - Comprehensive end-to-end integration test suite (`test/personal_integration_flow_test.dart`):
    - **Journey 1**: Open FlowPay → Wallet Exists → Balances Visible → Bottom Nav & Quick Actions Switch Tabs.
    - **Journey 2**: Money Mission Full Flow (NLP Prompt → AI Interpretation → Review → PIN Sign → Execution → Activity Verification).
    - **Journey 3**: Send Money Full Flow (Intent → Balance Check & Conversion → Review → PIN Sign → Execution → Wallet Debit & Activity Ledger).
  - 102/102 Flutter tests passing (`test/personal_integration_flow_test.dart`), 0 analyzer warnings or errors.

---

## 4. What Needs to Be Done (Next Steps)
- Personal track owner: Connect live real-time webhook balance push.
- Business track owner: Connect deep-link sharing for employee invites and spend limit controls.
- Personal track owner: Extend Money Missions builder and polish send animations.
- Business track owner: Connect virtual card spend limit presets and PDF payslip exports.

---

## 5. Usage & Verification
```bash
cd mobile
flutter pub get
flutter run
```
