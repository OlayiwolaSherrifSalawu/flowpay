# FlowPay — Intelligent Financial Operating Layer

<div align="center">

![FlowPay Brand](mobile/assets/images/flowpay_landing_hero.jpg)

### *"Your Money. Your Rules. AI Executes."*

**The autonomous cross-border financial operating system built on BMONI infrastructure.**  
*Empowering individuals with self-custody smart wallets & automated saving rules, and global businesses with aggregate multi-country payroll.*

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Node.js](https://img.shields.io/badge/Node.js-20+-339933?style=for-the-badge&logo=node.js&logoColor=white)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.4+-3178C6?style=for-the-badge&logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![BMONI](https://img.shields.io/badge/BMONI-Embedded%20SDK-00E599?style=for-the-badge)](https://bkey.mintlify.app)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![Prisma](https://img.shields.io/badge/Prisma-6.x-2D3748?style=for-the-badge&logo=prisma&logoColor=white)](https://www.prisma.io)
[![Tests](https://img.shields.io/badge/Tests-316%20Passing%20(100%25)-success?style=for-the-badge)]()
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)]()

[Live Backend API](https://flowpay-k2wn.onrender.com/api/health) • [BMONI Docs](https://bkey.mintlify.app/) • [Project Memory](.agents/skills/flowpay-core/SKILL.md)

</div>

---

## 📖 Table of Contents

- [Overview & The 10x Hook](#-overview--the-10x-hook)
- [The Problem vs The FlowPay Solution](#-the-problem-vs-the-flowpay-solution)
- [Financial Safety & Responsible AI Directives](#-financial-safety--responsible-ai-directives)
- [System Architecture](#-system-architecture)
- [Feature Breakdown](#-feature-breakdown)
  - [Personal Track](#1-personal-track)
  - [Business Track](#2-business-track)
- [Tech Stack](#-tech-stack)
- [Repository Structure](#-repository-structure)
- [Getting Started & Local Development](#-getting-started--local-development)
  - [Prerequisites](#prerequisites)
  - [Environment Configuration](#environment-configuration)
  - [Backend Setup](#backend-setup)
  - [Mobile Application Setup](#mobile-application-setup)
  - [Web / PWA Hosting](#web--pwa-hosting)
  - [Android Release Build](#android-release-build)
- [Testing & Quality Assurance](#-testing--quality-assurance)
- [Backend REST API Reference](#-backend-rest-api-reference)
- [Security & Compliance Invariants](#-security--compliance-invariants)

---

## ⚡ Overview & The 10x Hook

**FlowPay** is an intelligent financial operating layer built on top of [BMONI Embedded Financial Infrastructure](https://bkey.mintlify.app/). It bridges the gap between complex web3 self-custody rails, local emerging-market payment schemes, and intuitive consumer fintech.

### 🌟 The 10x Hook: *"One Employer, Many Countries, One Bill"*
Global employers face nightmare fragmentation paying distributed contractors and staff across Africa and Latin America. Traditional SWIFT rails charge \$300–\$400/month in cumulative wire fees with 3-to-5-day settlement delays.

With FlowPay:
1. An employer reviews their entire multi-country payroll roster (e.g. Nigeria 🇳🇬 and Mexico 🇲🇽).
2. FlowPay aggregates disbursements into **one consolidated USD settlement**.
3. With a single click and hardware B-Key PIN signing, FlowPay fans out local currency disbursements in parallel:
   - **Nigeria**: Disburses directly in **CNGN** via local clearing.
   - **Mexico**: Disburses directly in **MEXe** via SPEI clearing.
4. **Result**: 97% savings in cross-border fees (**~\$10.00 total** vs **\$340.00+** in SWIFT fees) with near-instant settlement.

---

## 🎯 The Problem vs The FlowPay Solution

| Challenge | Traditional Banking / Payroll Rails | FlowPay Autonomous Financial OS |
| :--- | :--- | :--- |
| **Cross-Border Fees** | \$25–\$50 per outbound wire + 3–5% hidden FX spreads. | Flat network fee (~₦15 / Mex\$1.50 / \$0.05) + 25 bps FX. 97% savings. |
| **Settlement Time** | 3 to 5 business days across international correspondent banks. | Sub-minute settlement via BMONI smart wallets and local rails. |
| **Currency Management** | Multiple disjoint domestic bank accounts required. | Multi-currency self-custody smart wallets (USD, NGN, MXN, CAD). |
| **Financial Automation** | Rigid scheduled transfers or manual banking portal inputs. | **Money Missions**: Autonomous AI-interpreted rules (e.g., auto-sweep 20% income to tax reserve). |
| **Custody & Security** | Centralized platforms holding and controlling user funds. | **Zero Key Custody**: Private keys generated and isolated in hardware Secure Enclaves / Keystores. |
| **Account Resolution** | Prone to mistyped routing numbers and bounced wire transfers. | Real-time **Paystack NUBAN** resolution with live account holder verification. |

---

## 🛡️ Financial Safety & Responsible AI Directives

FlowPay enforces strict financial engineering guardrails to prevent unauthorized fund movements, floating-point drift, and AI hallucinations:

```mermaid
flowchart LR
    A["User Request / Directive"] --> B["NLP Intent Interpreter"]
    B --> C["Structured Financial Plan"]
    C --> D["Deterministic Policy Validator"]
    D --> E["User Preview & Explicit Review"]
    E --> F["On-Device B-Key PIN Signing"]
    F --> G["BMONI Protocol Execution"]
    G --> H["Cryptographic Activity Ledger"]
```

1. **AI is Strictly Advisory**: The AI engine (`@google/genai` Gemini 2.5 Flash) parses natural language, extracts entities, and proposes plans. **The AI has ZERO autonomous transaction execution capabilities.**
2. **Deterministic Invariant Pipeline**:
   - **Entity Knowledge State**: Critical fields (recipients, amounts, currencies) never silently transition from `unknown` to `known` through AI guessing.
   - **Reservation Ledger & Spendable Balance**: Active reserves (taxes, emergency savings, active missions) are strictly locked from spendable balance calculations.
   - **Minor Unit Math**: Floating-point math is strictly forbidden. All monetary operations use the integer minor-unit `Money` abstraction.
3. **Hardware Enclave Key Custody**: Private keys are generated on-device via `bmoni_embedded_sdk`. Private keys **never leave the user's phone**, are never sent to the backend, never transmitted to AI, and never logged.
4. **Ironclad BMONI Rule — Never Fabricate Success**:
   > When a call to BMONI fails, the failure **must propagate as an explicit failure**. The codebase strictly forbids catching errors and returning dummy transaction hashes, fake addresses, or synthetic `COMPLETED` statuses.

---

## 🏗️ System Architecture

FlowPay is structured across three primary tiers:

```mermaid
graph TB
    subgraph Client["Frontend Client (Flutter Mobile & Web PWA)"]
        UI["FlowPay Custom Design System<br/>(Dark Obsidian Canvas / Emerald Accents)"]
        RoleSwitch["Dual Shell Router<br/>[ Personal Shell | Business Shell ]"]
        Operator["Intelligent Financial Operator<br/>(18 Financial Intents + Entity Resolver)"]
        State["Riverpod State Management & Notifiers"]
        LocalAuth["AppLockService (Biometrics / LocalAuth)"]
        SDK["BmoniSdkService<br/>(Hardware Keystore / Secure Enclave)"]
    end

    subgraph Backend["Backend Relay & Financial Engine (Node.js / Express / TypeScript)"]
        API["Express REST API (ESM) + Zod Schemas"]
        BmoniClient["BMONI API Client (Exponential Backoff & Retries)"]
        HMAC["Raw-Buffer HMAC-SHA256 Webhook Verifier"]
        PayrollEngine["Payroll Fanout & Proposal Sequence Orchestrator"]
        SafetyEngine["AI Safety Validator & Completeness Checker"]
        Paystack["Paystack Bank Resolution & NUBAN Resolver"]
        MailRelay["Gmail SMTP Relay (IPv4 DNS Pre-Resolution)"]
    end

    subgraph Data["Persistence & Cloud Infrastructure"]
        DB[("Supabase PostgreSQL<br/>14 Tables + 100% RLS Coverage")]
        Prisma["Prisma ORM Client"]
    end

    subgraph External["External Financial Infrastructure"]
        BMONI["BMONI Embedded Infrastructure<br/>(Smart Wallets, Cards, Transfers, Rails)"]
        PaystackAPI["Paystack Banking API"]
        GoogleGemini["Google Gemini 2.5 Flash"]
    end

    UI --> RoleSwitch
    RoleSwitch --> State
    State --> Operator
    Operator --> SDK
    State --> API
    SDK -.->|EIP-712 Raw Hash Signatures| State

    API --> BmoniClient
    API --> HMAC
    API --> PayrollEngine
    API --> SafetyEngine
    API --> Paystack
    API --> MailRelay
    API --> Prisma
    Prisma --> DB

    BmoniClient --> BMONI
    Paystack --> PaystackAPI
    SafetyEngine --> GoogleGemini
```

---

## 📦 Feature Breakdown

### 1. Personal Track

- **Multi-Currency Smart Wallets**:
  - Native accounts in **USDB** (USD), **CNGN** (NGN), **MEXe** (MXN), and **CADC** (CAD).
  - Interactive **"Receive & Deposit"** bottom sheet with instant quick-deposit chips (`+$100`, `+$250`, `+$500`, `+$1,000`), custom amounts, and copyable public EVM addresses.
- **Conversational AI Financial Operator**:
  - Recognizes **18 strongly typed financial intents** (`SEND_MONEY`, `CONVERT_CURRENCY`, `CREATE_MISSION`, `CREATE_RESERVE`, etc.).
  - Handles complex multi-intent requests (e.g., *"Send $20 to Mom and $30 to Dad"* or *"Send 100,000 NGN from my naira wallet to my USD wallet"*).
  - Contextual clarification engine offering 1-tap resolution cards for ambiguous counterparties.
- **Autonomous Money Missions**:
  - *"Tell your money what to do."* — Set rules like *"Whenever I get paid in USD, keep 20% for taxes and send $200 to my designer"*.
  - Event-driven mission runtime reacting to incoming wallet inflows (`WalletInflowEvent`).
  - Strict priority ordering: tax reservations are locked first before discretionary payouts.
  - Interactive mission cards with live execution counters, progress meters, and `⚡ Run Now` manual triggers.
- **Send Money & Cross-Border Payments**:
  - **Balance-Aware Auto-Funding**: Automatically identifies liquidity shortfalls and calculates exact cross-currency conversion requirements with zero over-conversion.
  - **Paystack NUBAN Integration**: Resolves 10-digit Nigerian bank accounts in real-time across commercial banks (GTBank, Access, Zenith, First Bank) and fintechs (OPay, Kuda, PalmPay, Moniepoint) with live green verification badges (`✓ Verified Account Holder: [NAME]`).
  - **Transparent Fee Breakdown**: Clearly itemizes network clearing fees vs FlowPay platform charges.
  - **On-Device B-Key PIN Signing**: Mandatory 6-digit numeric keypad entry to authorize all outbound proposals.
- **Personal Security & Activity**:
  - Biometric app-lock (`local_auth`) with auto-lock on app resume.
  - Cryptographic Activity Ledger displaying all transfers, conversions, card transactions, and missions with granular status filters and 10-item pagination.

---

### 2. Business Track

- **"One Employer, Many Countries, One Bill" Global Payroll**:
  - Composes BMONI's 4-call transfer proposal sequence (`proposals` → `approve` → `sign-payload` → `sign`).
  - Derives canonical 32-byte SHA-256 proposal hashes per item with duplicate collision safeguards.
  - Generates distinct on-device hardware signatures per proposal item.
  - 4-stage visual execution timeline (`Validated` → `Approved` → `Processing` → `Completed`).
  - **Granular Single-Proposal Retry**: If one employee's disbursement fails (e.g. unactivated recipient rail), other payments settle uninterrupted, and the failed item can be retried individually.
- **Remote Employee Management & Self-Onboarding (v2)**:
  - **Zero Employer Key Custody**: Replaces legacy setups where employers generated employee keys. Employees hold their own keys in their own phone's hardware enclave.
  - **Single-Use Invite Tokens**: Generates 24-byte cryptographically secure tokens with 72-hour expiration.
  - **Automated Email Dispatch**: Sends branded dark-mode onboarding invitations with single-use invite codes via the built-in Gmail SMTP relay.
  - **Session-Gated Wallet Linking**: Verifies that the employee's active mobile session matches the invite before linking the destination wallet address.
- **Virtual Spend Cards**:
  - Corporate virtual cards powered by BMONI issuing rails.
  - Full card controls: View card details, copy PAN/CVV, view dedicated card transaction feeds, and freeze/unfreeze toggling.
  - Honest error propagation handling BMONI `E101` KYC enrollment requirements.
- **Production Camera Facial Liveness Verification**:
  - Real-time front/back camera feed powered by `camera: 0.12.1`.
  - Animated laser scan overlay with oval guidance and 99.8% anti-spoofing confidence checks.
  - Strict 11-digit BVN regex validation and interactive adult age (`18+`) Date of Birth calendar picker.
  - Dual onboarding support: Remote self-invite flow and Employer-assisted portal.
- **Corporate Activity & Audit Log**:
  - Cryptographically anchored audit trail of all disbursements, card issuances, and compliance changes.
  - Sanitize reference hashes with 1-tap clipboard copying and category filters.

---

## 💻 Tech Stack

### Mobile & Web (`mobile/`)
- **Framework**: Flutter 3.24+ / Dart 3.4+
- **Architecture**: Domain-Driven Feature Modules + Repository Pattern
- **State Management**: `flutter_riverpod: ^3.2.1`
- **BMONI Integration**:
  - `bmoni_embedded_sdk: 0.0.2` (Strictly unstyled on-device hardware enclave crypto driver)
  - `bmoni_embedded_wallets_cards` (Shared data models & read data sources)
- **Design System**: FlowPay Custom Design System (Zero `bkey_uikit` frontend dependencies)
  - Dark Obsidian palette (`#090A0F`, `#12141C`, `#181B26`)
  - Electric Emerald accents (`#00E599`, `#128A63`)
  - Tabular monospace numbers with `FontFeature.tabularFigures()`
- **Security & Hardware**:
  - `flutter_secure_storage: ^10.0.0` (Encrypted keychain session storage)
  - `local_auth: ^2.3.0` (Biometrics / Face ID / Fingerprint)
  - `camera: ^0.12.1` (Production live liveness video stream)

### Backend Service (`backend/`)
- **Runtime**: Node.js v20+ (ESM)
- **Framework**: Express 4.x, TypeScript 5.4
- **Database & ORM**: Supabase PostgreSQL, Prisma ORM 6.x
- **Validation**: Zod 3.23
- **AI Engine**: `@google/genai: ^2.21.0` (Gemini 2.5 Flash)
- **Cryptography**: `ethers: ^6.17.0`, Node.js native `crypto` (HMAC-SHA256, PBKDF2)
- **Email Relay**: Nodemailer with IPv4 DNS pre-resolution (`dns.promises.lookup`) to eliminate container `ENETUNREACH` routing failures.
- **Banking Integrations**: Paystack API (NUBAN Bank Account Resolution)

---

## 📁 Repository Structure

```text
flowpay/
├── AGENTS.md                                # AI Assistant & team protocol (Standing Rules)
├── .env.example                             # Environment configuration template
├── README.md                                # Main project documentation
├── build-web.sh                             # Automated Flutter Web SDK & build script
├── vercel.json                              # Vercel SPA routing & WASM MIME headers
├── .github/
│   └── workflows/
│       └── build.yml                        # GitHub Actions CI (Android APK & iOS IPA)
├── .agents/
│   └── skills/                              # Subsystem architecture runbooks & memory
│       ├── flowpay-core/SKILL.md            # Master memory & project backlog
│       ├── bmoni-backend/SKILL.md           # Backend architecture & BMONI client
│       ├── flowpay-mobile/SKILL.md          # Mobile architecture & Riverpod state
│       ├── flowpay-operator/SKILL.md        # AI Financial Operator & safety pipeline
│       ├── flowpay-payroll/SKILL.md         # Payroll orchestrator & proposal sequence
│       ├── flowpay-cards/SKILL.md           # Virtual employee cards
│       ├── flowpay-audit/SKILL.md           # Corporate audit & activity
│       └── flowpay-design/SKILL.md          # FlowPay Design System guidelines
├── backend/                                 # Node.js + Express + TypeScript Backend
│   ├── Dockerfile                           # Production multi-stage Docker build
│   ├── package.json                         # Node dependencies & test scripts
│   ├── tsconfig.json                        # Strict ESM TypeScript compiler config
│   ├── prisma/
│   │   └── schema.prisma                    # Prisma schema (14 tables, relations)
│   └── src/
│       ├── server.ts                        # Server bootstrap & route registration
│       ├── config/env.ts                    # Zod-validated environment config
│       ├── db/                              # Database pool, Prisma client, in-memory store
│       ├── core/                            # Money class, currency mappings, pagination
│       ├── bmoni/                           # BMONI REST client & HMAC webhook handler
│       ├── modules/
│       │   ├── ai/                          # Gemini intent interpreter & safety validator
│       │   ├── banks/                       # Paystack NUBAN bank resolution service
│       │   ├── cards/                       # Virtual card issuance & proposal signing
│       │   ├── employees/                   # Roster, invite tokens, onboarding service
│       │   ├── mail/                        # Gmail SMTP relay & dark fintech email templates
│       │   ├── missions/                    # Money Missions proposal & execution engine
│       │   ├── payroll/                     # Multi-country aggregate payroll orchestrator
│       │   ├── transfers/                   # Transfer proposal creation & execution
│       │   └── wallets/                     # Smart wallet registration & balance tracking
│       └── routes/                          # Express REST endpoints
└── mobile/                                  # Flutter Mobile & Web Application
    ├── pubspec.yaml                         # Flutter dependencies & assets
    ├── android/                             # Android native platform project (Gradle 8.14)
    ├── ios/                                 # iOS native platform project
    ├── web/                                 # Web platform index.html & PWA manifest
    ├── assets/images/                       # Official FlowPay logo & 3D hero assets
    ├── lib/
    │   ├── main.dart                        # Entrypoint & BMONI SDK initialization
    │   ├── app.dart                         # AppAuthGate & shell routing
    │   ├── core/
    │   │   ├── auth/                        # Session management, biometrics, secure storage
    │   │   ├── bmoni_sdk/                   # On-device B-Key hardware enclave service
    │   │   ├── design_system/               # 13 shared FlowPay UI primitives
    │   │   ├── financial_engine/            # Reservation ledger & quote models
    │   │   ├── financial_operator/          # AI operator, intent engine, clarification
    │   │   ├── money/                       # Integer minor-unit Money & Currency models
    │   │   ├── navigation/                  # Modular routers & role switcher
    │   │   ├── repositories/                # Unified repository interfaces
    │   │   └── state/                       # AppState, BusinessProvider, PersonalProvider
    │   └── modules/
    │       ├── auth/                        # Flagship 3D Landing, Login, Signup, KYC, PIN
    │       ├── personal/                    # Dashboard, Wallets, Missions, Send, Security
    │       └── business/                    # Dashboard, Roster, Payroll, Cards, Audit
    └── test/                                # 198 automated unit, widget & integration tests
```

---

## 🚀 Getting Started & Local Development

### Prerequisites
- **Node.js**: `v20.x` or `v22.x`
- **Flutter SDK**: `v3.24.x` or higher
- **Android SDK / Xcode**: For mobile emulator or physical device testing
- **Git**: For version control

---

### Environment Configuration

1. Copy `.env.example` to `backend/.env` (or root `.env`):
   ```bash
   cp .env.example backend/.env
   ```
2. Configure your environment variables:
   ```env
   PORT=4000
   NODE_ENV=development
   FLOWPAY_JWT_SECRET=your_32_char_development_secret_here
   
   # PostgreSQL Connection (Supabase or local PostgreSQL)
   DATABASE_URL=postgresql://postgres:password@localhost:5432/flowpay
   
   # BMONI Infrastructure
   BMONI_BASE_URL=https://embedded-dev.bmoni.com
   BMONI_API_KEY=pk_a025cacbf33a_76fb864113f3540909de5b1da39cc146906e35b1c6d4d1e4
   BMONI_WEBHOOK_SECRET=87f88be98b96faf6d6ece5b26bf4a9fe20739ae9634fb7b530a24aac4f71ed32
   BMONI_PARTNER_ID=b7e6a1d0-4f3c-4c2a-9e8b-1a2b3c4d5e6f
   
   # AI Financial Operator
   GEMINI_API_KEY=your_google_gemini_api_key
   
   # Paystack Nigerian Bank Resolution
   PAYSTACK_SECRET_KEY=sk_test_your_paystack_secret_key
   
   # SMTP Mail Relay (Optional, defaults to console log if unconfigured)
   SMTP_HOST=smtp.gmail.com
   SMTP_PORT=587
   SMTP_USER=your_email@gmail.com
   SMTP_PASS=your_gmail_app_password
   ```

---

### Backend Setup

```bash
cd backend

# 1. Install dependencies
npm install

# 2. Generate Prisma Client & Compile TypeScript
npm run build

# 3. Run automated tests (118 tests across 13 suites)
npm test

# 4. Start local development server with hot reload
npm run dev
```

The backend starts at `http://localhost:4000`. Test the health check endpoint:
```bash
curl http://localhost:4000/api/health
```

---

### Mobile Application Setup

```bash
cd mobile

# 1. Fetch Flutter dependencies
flutter pub get

# 2. Run static analysis (0 lints guaranteed)
flutter analyze

# 3. Run automated test suite (198 tests)
flutter test

# 4. Run on connected emulator or device (defaults to local backend)
flutter run

# To target the live production backend directly:
flutter run --dart-define=FLOWPAY_API_URL=https://flowpay-k2wn.onrender.com
```

---

### Web / PWA Hosting

FlowPay is fully compiled for Web and PWA execution with full PIN signing compatibility:

```bash
cd mobile

# Compile release web bundle pointing to local backend
flutter build web --release --dart-define=FLOWPAY_API_URL=http://localhost:4000

# Serve locally over port 8080 (accessible to desktop and mobile browsers over LAN)
cd build/web
python3 -m http.server 8080
```

Access from any device on your local Wi-Fi: `http://<your-lan-ip>:8080`.

---

### Android Release Build

```bash
cd mobile

# Build standalone Android Release APK targeting production Render backend
flutter build apk --release --dart-define=FLOWPAY_API_URL=https://flowpay-k2wn.onrender.com
```

The resulting signed APK is located at:  
`mobile/build/app/outputs/flutter-apk/app-release.apk` (~55MB).

---

## 🧪 Testing & Quality Assurance

FlowPay maintains a 100% passing test suite across both frontend and backend repositories with zero static analysis warnings:

```text
Backend Test Summary:  118 / 118 Passing (100% Green)
Mobile Test Summary:   198 / 198 Passing (100% Green)
Total Project Tests:   316 / 316 Passing (100% Green)
Dart Analyzer:         0 issues found
TypeScript Compiler:   0 errors (strict mode)
```

### Backend Test Coverage (`backend/`)
Execute via `npm test`:
- `core/money.test.ts`: Integer minor units, zero float drift, currency safety.
- `bmoni/webhooks.test.ts`: Raw-buffer constant-time HMAC-SHA256 signature verification.
- `modules/ai/safety.test.ts`: AI multi-action interpretation, completeness checking, batch limits.
- `modules/employees/employee.test.ts`: Invite token issuance, TTL expiry, foreign session rejection.
- `modules/employees/onboarding.test.ts`: 4-state lifecycle, Nigeria BVN vs Mexico CURP/RFC.
- `modules/missions/mission.test.ts`: Percentage splits, threshold triggers, SHA-256 proposal hashes.
- `modules/transfers/transfer.test.ts`: Balance-aware funding, proposal creation, execution crediting.
- `modules/wallets/wallets.test.ts`: Isolated multi-currency wallets, debit/credit integrity.
- `modules/cards/cards.test.ts`: Virtual card issuance, E101 NIN error propagation.
- `modules/payroll/payroll.test.ts`: 4-call sequence, Anvil test-vector raw hash signing, rail checks.
- `modules/payroll/audit.test.ts`: Corporate audit logging, filtered queries.
- `modules/mail/mail.test.ts`: Responsive email template generation & SMTP transport diagnostics.
- `modules/banks/banks.test.ts`: Paystack NUBAN bank listing, caching, account name resolution.

### Mobile Test Coverage (`mobile/`)
Execute via `flutter test`:
- `test/design_system_foundation_test.dart`: Color tokens, radii, typography, spacing.
- `test/phase2_components_test.dart`: Buttons, scalloped cards, quick actions, analytics.
- `test/app_shell_test.dart`: Personal and Business shell routing, role switcher.
- `test/personal_dashboard_test.dart`: Balances, missions, quick actions.
- `test/send_money_flow_test.dart`: Balance-aware routing, NUBAN resolution, review modal.
- `test/financial_operator_test.dart`: 18 intents, multi-action clause splitting, approval gates.
- `test/financial_operator_conversations_test.dart`: 7 full multi-turn conversational scenarios.
- `test/money_missions_test.dart`: Autonomous saving rules, threshold triggers, live execution.
- `test/wallet_service_test.dart` & `test/wallet_provisioning_ui_test.dart`: Enclave keys, PIN pad.
- `test/payroll_signing_test.dart`: Canonical SHA-256 proposal hashing, collision protection.
- `test/payroll_screen_test.dart`: Aggregate bill card, 4-stage execution stepper.
- `test/employee_invite_flow_test.dart`: Token validation, KYC, session wallet linking.
- `test/pagination_bar_test.dart`: Long-list UX controls, boundaries, page resets.

---

## 📡 Backend REST API Reference

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| **Health** | | |
| `GET` | `/api/health` | Service health, DB connectivity, BMONI sandbox origin |
| `GET` | `/api/health/bmoni` | BMONI partner credentials probe & authentication check |
| **Auth & Sessions** | | |
| `POST` | `/api/auth/login` | Email & PIN authentication, session establishment |
| `GET` | `/api/auth/session` | Validate active session header (`x-user-id`) |
| `GET` | `/api/auth/capabilities` | Retrieve account capabilities (`hasPersonalWallet`, `hasBusinessAccess`) |
| `POST` | `/api/auth/kyc` | Submit user identity details (DOB, BVN, address, liveness) |
| **Smart Wallets** | | |
| `GET` | `/api/wallets` | List multi-currency smart wallets for authenticated user |
| `POST` | `/api/wallets/register` | Register client device-generated keypair address |
| `POST` | `/api/wallets/:id/debit` | Debit funding wallet upon verified transaction |
| `POST` | `/api/wallets/:id/credit` | Credit wallet upon verified deposit or transfer receipt |
| **Transfers** | | |
| `POST` | `/api/transfers/propose` | Create transfer proposal & generate `hashToSign` |
| `POST` | `/api/transfers/execute` | Submit 65-byte on-device signature to execute transfer |
| `GET` | `/api/transfers/rates` | Real-time FX exchange rates & fee quotes |
| **Bank Resolution** | | |
| `GET` | `/api/banks` | List supported commercial banks & fintechs (Paystack) |
| `GET` | `/api/banks/resolve` | Verify 10-digit NUBAN account number & return account name |
| **Money Missions** | | |
| `GET` | `/api/missions` | List active autonomous money directives |
| `POST` | `/api/missions/propose` | Propose mission rule with deterministic validation |
| `POST` | `/api/missions/:id/execute` | Trigger manual execution of mission (`⚡ Run Now`) |
| `DELETE`| `/api/missions/:id` | Delete saved mission directive |
| **Business & Payroll** | | |
| `GET` | `/api/employees` | List team roster with onboarding status & wallet tags (paginated) |
| `POST` | `/api/employees` | Create employee & generate single-use 72-hour invite token |
| `GET` | `/api/employees/invite/:code` | Validate invite token & fetch prefilled details |
| `POST` | `/api/employees/link-wallet` | Bind employee on-device wallet to invited roster record |
| `GET` | `/api/payroll/preview` | Generate aggregate multi-country payroll bill |
| `POST` | `/api/payroll/execute` | Submit signed proposal batch to fan out payroll |
| `POST` | `/api/payroll/proposals/:id/retry` | Retry individual failed proposal item |
| **Corporate Virtual Cards** | | |
| `POST` | `/api/cards/issue` | Issue BMONI-backed corporate virtual employee card |
| `GET` | `/api/cards/:id` | Fetch virtual card details, balances, and spend limits |
| `POST` | `/api/cards/:id/toggle` | Freeze or unfreeze active virtual card |
| **Webhooks** | | |
| `POST` | `/api/webhooks/bmoni` | Ingest BMONI events (verified with raw HMAC-SHA256) |

---

## 🔒 Security & Compliance Invariants

1. **Zero Key Transmission**:
   Private keys are generated strictly on-device in hardware Secure Enclaves / Keystores via `bmoni_embedded_sdk`. No private key is ever transmitted over HTTP, written to disk unencrypted, or shared with AI.
2. **Raw-Hash Proposal Signing**:
   BMONI transfer proposals require signing a raw 32-byte hash (`keccak256` or `sha256`), **never** pre-hashed with `\x19Ethereum Signed Message`. FlowPay's signing coordinator strictly enforces canonical hash signing.
3. **Double-Debit Prevention**:
   All fund movements are handled atomically. Wallet debiting is linked directly to proposal execution on the backend, preventing duplicate deductions.
4. **Strict Isolation & Scoping**:
   All database queries and in-memory caches are scoped strictly by `userId`. Users can never view or access counterparties' activity or wallet balances.
5. **Constant-Time Webhook Verification**:
   Incoming BMONI webhook payloads are validated using constant-time `crypto.timingSafeEqual` against raw Buffer bytes before JSON parsing to eliminate timing attacks.

---

<div align="center">

**Built with ❤️ for the BMONI Hackathon.**  
*FlowPay — The Future of Cross-Border Financial Operations.*

</div>

