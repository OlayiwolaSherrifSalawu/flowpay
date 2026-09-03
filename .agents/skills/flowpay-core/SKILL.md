---
name: flowpay-core
description: >-
  Single source of truth and persistent memory for the FlowPay hackathon project.
  Consult this skill on every turn to understand what FlowPay is about, its system
  architecture, what has already been built, and what needs to be done next.
---

# FlowPay — Project Memory & Master Runbook

FlowPay is an intelligent financial operating layer built on top of BMONI infrastructure for the BMONI hackathon.
**Tagline**: *"Your money. Your rules. AI executes."*

---

## 📌 1. What the App is About

* **Core Problem**: Traditional payment rails across Africa and Latin America are fragmented, slow, and impose abusive FX and wire fees ($300–$400/month for distributed teams). Personal freelancers and global employers struggle with multi-currency conversion, compliance paperwork, and spend governance.
* **FlowPay Solution**: An autonomous financial operating system providing:
  * **Personal**: Multi-currency self-custody smart wallets, AI-powered "Money Missions" (e.g. 20% auto-sweep of international income to local savings, spending caps), and deterministic PIN-signed transfers.
  * **Business**: "One Employer, Many Countries, One Bill" aggregate payroll orchestrator. Employers invite remote team members (Nigeria, Mexico), see one aggregate USD bill, click once, and FlowPay fans out local currency disbursements (NGN, MXN) and virtual cards invisibly via BMONI rails.
* **10x Product Hook**: *"One Employer, Many Countries, One Bill"* — Fans out payment to employees in Nigeria (Bunch Dillon) and Mexico (Samson Jabo) in parallel with instant virtual cards, saving 96% in fees ($12 vs $340 typical wire fees).
* **Financial Safety Directives**:
  * AI is strictly advisory and **NEVER** directly executes money movement.
  * Invariant Pipeline: `Intent → Interpretation → Structured intent → Deterministic validation → Preview → Explicit approval → BMONI proposal → On-device signing → BMONI execution → Result → Activity`.
  * Private keys are created and protected strictly on-device in hardware Secure Enclaves via BMONI SDK. Private keys never leave the phone, are never sent to the backend, never sent to AI, and never logged.

---

## 🏗️ 2. Technical Architecture & Stack

| Layer | Technology | Status / Details |
| :--- | :--- | :--- |
| **Frontend (Mobile)** | Flutter (Dart), `bmoni_embedded_sdk: ^0.0.2`, `bkey_uikit: ^0.0.1`, `bmoni_embedded_wallets_cards: ^0.0.1`, Riverpod | Shared Foundation complete in `mobile/` |
| **Backend / API** | Node.js (v20+), Express, TypeScript (ESM) | Complete modular backend in `backend/` |
| **Database** | SQLite (`better-sqlite3`), WAL mode, relational schema | Active in `backend/flowpay.db` |
| **Infrastructure** | BMONI Embedded REST Sandbox (`https://embedded-dev.bmoni.com`), Origin-only base URL | Integrated with client & raw HMAC webhooks |
| **BMONI Docs & Specs** | [bkey.mintlify.app](https://bkey.mintlify.app/) (LLM Index: [/llms.txt](https://bkey.mintlify.app/llms.txt)) | Official docs & API specs; prompt user for any required keys |
| **Provider Layer** | `DemoProvider` & `BMONIProvider` conforming to shared interfaces | Active with instant sandbox test personas |

---

## ✅ 3. What Has Been Done

* [x] **Project Scaffolding & Shared Foundation**:
  * Enforced workspace rules and AI agent protocol in [AGENTS.md](file:///AGENTS.md).
  * Provided central environment template in [.env.example](file:///.env.example).
  * Configured GitHub Actions CI workflow in [.github/workflows/build.yml](file:///.github/workflows/build.yml) targeting `main`, running on `macos-latest`, setting up Java 17 and Flutter, and building Android release APK and unsigned iOS release IPA.
* [x] **Backend Infrastructure (`backend/`)**:
  * Typed configuration in `config/env.ts` with strict origin-only URL parsing (strips `/v1` to prevent 404s).
  * Relational persistence in SQLite (`db/schema.sql`, `db/index.ts`) for employees, payroll runs, money missions, audit logs, and webhooks.
  * Central `Money` abstraction (`core/money.ts`) using integer minor units, zero float drift, and currency safety.
  * Production-grade BMONI client (`bmoni/client.ts`) with safe logging, structured error parsing (400 validation arrays, 401, 403, 409 idempotency recovery, 500 curve errors).
  * Webhook listener (`bmoni/webhooks.ts`, `routes/webhook.routes.ts`) verifying HMAC-SHA256 signatures over raw Buffer bytes in constant time.
  * Multi-country aggregate payroll engine (`modules/payroll/service.ts`, `routes/payroll.routes.ts`).
  * AI Financial Safety Engine (`modules/ai/interpreter.ts`, `modules/ai/validator.ts`) enforcing deterministic validation and previews.
  * Automated unit tests passing for Money arithmetic, HMAC verification, and AI safety guards.
* [x] **Mobile Flutter Foundation & Application Shell (`mobile/`)**:
  * Configured `pubspec.yaml` with BMONI Flutter ecosystem (`bmoni_embedded_sdk`, `bkey_uikit`, `bmoni_embedded_wallets_cards`, `crypto`).
  * Configured native Android (`mobile/android/`) and iOS (`mobile/ios/`) platform project trees with Gradle wrapper and build configurations.
  * Central Money abstraction (`lib/core/money/money.dart`).
  * Financial safety state models & signing coordinator (`lib/core/safety/`).
  * BMONI SDK on-device signing service wrapper (`lib/core/bmoni_sdk/bmoni_sdk_service.dart`).
  * Provider abstraction interfaces: `WalletRepository`, `TransferRepository`, `CardRepository`, `EmployeeRepository`, `PayrollRepository`.
  * Deterministic `DemoProvider` implementations loaded with BMONI sandbox personas (Bunch Dillon BVN 99999999999, Samson Jabo BVN 22222222222).
  * Live `BMONIProvider` implementations communicating via backend proxy.
  * **13 FlowPay Design System Primitives (`lib/core/design_system/`)**:
    * `FlowPayTypography` with tabular monospaced numbers.
    * `FlowPaySpacing` with standard 8-point grid, presets, and border radii.
    * `FlowPayCard`, `FlowPayGlassCard`, `FlowPayStatCard`.
    * `FlowPayButton`, `FlowPayIconButton`.
    * `FlowPayTextField`, `FlowPayAmountField`.
    * `FlowPayBadge`, `FlowPayStatusBadge`.
    * `FlowPayAmountDisplay` (tabular numerals, integer/decimal split, sign, secondary FX label).
    * `FlowPayCurrencyDisplay` (flag/symbol, code, BMONI stablecoin token badge).
    * `FlowPayBottomSheet` & `showFlowPayBottomSheet()`.
    * `FlowPayDialog` & `showFlowPayConfirmDialog()`.
    * `FlowPayLoadingState`, `FlowPayErrorState`, `FlowPayEmptyState`.
  * **9 Shared App States (`FlowPayAppStatus` & `FlowPayStateView`)**: Loading, Success, Error, Empty, Pending, AwaitingApproval, Processing, Completed, Failed with zero duplicated styling.
  * **Dual Theme Engine (`lib/core/theme/`)**: `FlowPayTheme.dark()` and `FlowPayTheme.light()` with accessible WCAG contrast, context color resolvers, and dynamic `ThemeMode` toggling.
  * **Modular Navigation Architecture (`lib/core/navigation/`)**:
    * Prominent, unconfusing animated **Role Switcher** (`FlowPayRoleSwitcher`) in header (`[ 👤 Personal | 💼 Business ]`).
    * Decoupled `PersonalRoutes`, `BusinessRoutes`, `AppRoutes`, and `FlowPayRouter`.
    * Contextual bottom navigation bars reflecting mode-specific tabs and brand accents.
  * **FlowPay Business Employer Dashboard**:
    * Core value message: *"One Employer. Many Countries. One Bill."*
    * Domain state coordinator: `BusinessProvider` (`mobile/lib/core/state/business_provider.dart`) decoupling widgets from direct API calls with deterministic demo data.
    * 6 Employer metrics grid: Total payroll, employee count, countries, pending payroll, employee status, wallet/card status.
    * Employee Preview with rich model: Name, Country, Currency, Payroll amount, Onboarding status, Wallet status, Card status across Nigeria 🇳🇬 (NGN), Mexico 🇲🇽 (MXN), and Canada 🇨🇦 (CAD).
    * Primary action: Run Payroll (triggers on-device B-Key signing and multi-rail fan-out).
    * Secondary action: Add Employee (`AddEmployeeModal` with instant local wallet & card provisioning).
  * **Complete Screen Foundations**:
    * **Personal**: Dashboard, Wallets, Money Missions ("Your money. Your rules. AI executes."), Send Money with PIN approval, Personal Activity, Personal Security.
    * **Business**: Business Dashboard, Global Team Roster, Employee Detail, Multi-country Payroll Orchestrator ("One Employer, Many Countries, One Bill"), Corporate Audit.
  * Automated widget and shell tests passing with 100% success and 0 analyzer lints.
* [x] **Live Environment & Emulator Runtime Verification**:
  * **Backend Daemon**: Actively running on `http://localhost:4000` with BMONI sandbox integration and health checks passing.
  * **Toolchain Alignment**: Synchronized Gradle 8.14, Android Gradle Plugin 8.13.2, and Kotlin 2.2.20 for Flutter 3.47 compilation.
  * **Android Emulator**: Verified on `Pixel_3a_API_33_x86_64` (Android 13 / API 33) with Impeller OpenGLES backend.
  * **Live Flow Verified**: App boots directly into self-custody BMONI mode with interactive Personal/Business role switching and Money missions.
* [x] **App-Lock Authentication, Biometrics, and Personal/Business Mode Routing**:
  * Single-account two-mode foundation: confirmed one `bmoniUserId` holds both personal wallet and business/employer access.
  * System separation: App-level lock (`local_auth`) gates opening the app; BMONI on-device signing PIN (`bmoni_embedded_sdk`) authorizes transactions. Never conflated.
  * Native configuration: Android `FlutterFragmentActivity` and `USE_BIOMETRIC` permission; iOS `NSFaceIDUsageDescription` for Face ID.
  * Secure storage & caching: `AccountCapabilities` (`hasPersonalWallet`, `hasBusinessAccess`) stored in `flutter_secure_storage` with 15-minute TTL caching, in-memory resilient fallback layer, and instant invalidation.
  * Backend capabilities endpoints: `GET /api/auth/capabilities` and `GET /api/auth/users/:bmoniUserId/capabilities` active on port 4000.
  * Mode picker: `AccountModePickerModal` conforming to `design.md` §4.4 and `bkey_uikit` style with custom branded radio selectors.
  * Two independent navigation shells: `PersonalShell` (5 destinations: Overview, Wallets, Missions, Activity, Security) and `BusinessShell` (4 destinations: Dashboard, Team, Payroll, Audit) driven by Riverpod `currentAccountModeProvider`.
  * App lifecycle lock: `AppAuthGate` observing background pause/resume to securely re-lock the app after 45s of inactivity, with instant demo bypass code (`123456`).
  * Full test suite passing: 13/13 mobile tests passed (100%), 11/11 backend tests passed (100%), with 0 analyzer lints.


---

## 🎯 4. What Needs to Be Done (Parallel Roadmap)

### Personal Track Owner
- [ ] Connect `PersonalDashboardScreen` to live real-time wallet balance polling.
- [ ] Implement Money Missions builder UI to allow adding custom percentage rules and triggers.
- [ ] Polish Send Money modal animations and transaction status receipt states.
- [ ] Integrate full BMONI biometric PIN lock prompt with device biometrics.

### Business Track Owner
- [ ] Expand Employee Onboarding: connect deep-link generation and KYC verification status tracker.
- [ ] Add virtual card spend limit presets (Junior / Senior / Contractor dropdowns).
- [ ] Implement self-serve card freeze toggle and card replacement flow.
- [ ] Add PDF export / receipt sharing for aggregate payroll disbursement runs.

---

## 📂 5. Project Directory Structure

```text
flowpay/
├── AGENTS.md                                # Mandatory AI agent & team guidelines
├── .env.example                             # Environment variable configuration
├── .agents/
│   ├── skills/
│   │   ├── flowpay-core/SKILL.md            # Master memory (this file)
│   │   ├── bmoni-backend/SKILL.md           # Backend subsystem documentation
│   │   └── flowpay-mobile/SKILL.md          # Mobile Flutter subsystem documentation
│   └── resources/
│       ├── payroll_spec.txt                 # Global Payroll Cards specification
│       └── recon_spec.txt                   # BMONI Platform Reconnaissance
├── backend/                                 # Node.js + Express + TypeScript Backend
│   ├── package.json
│   ├── tsconfig.json
│   └── src/
│       ├── server.ts                        # Express bootstrap & route registration
│       ├── config/env.ts                    # Typed env validation & origin-only URL guard
│       ├── db/                              # SQLite schema, migrations & test persona seed
│       ├── core/                            # Central Money class, errors & types
│       ├── bmoni/                           # BMONI API client & raw HMAC webhook handler
│       ├── modules/                         # AI safety, payroll engine, employees, cards, wallets
│       └── routes/                          # REST endpoints + /webhooks/bmoni
└── mobile/                                  # Flutter Mobile Application
    ├── pubspec.yaml                         # bmoni_embedded_sdk, bkey_uikit, etc.
    └── lib/
        ├── main.dart                        # App entry & BMONI SDK initialization
        ├── app.dart                         # Shell with role & provider toggling
        ├── core/                            # Money, theme, safety, BMONI SDK wrapper, repos
        └── modules/
            ├── personal/                    # Personal dashboard, wallets, missions, send, security
            └── business/                    # Business dashboard, roster, detail, payroll, audit
```

---

## 👥 6. Developer Runbook

### Backend Commands
```bash
cd backend
npm install
npm run build      # Compile TypeScript & copy schema
npm test           # Run unit test suite (Money, Webhooks, AI Safety)
npm run dev        # Run with live reload via tsx
npm start          # Start compiled production server
```

### Mobile Commands
```bash
cd mobile
flutter pub get
flutter run
```
