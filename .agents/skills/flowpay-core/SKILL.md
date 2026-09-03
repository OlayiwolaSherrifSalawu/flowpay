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
| **Provider Layer** | `DemoProvider` & `BMONIProvider` conforming to shared interfaces | Active with instant sandbox test personas |

---

## ✅ 3. What Has Been Done

* [x] **Project Scaffolding & Shared Foundation**:
  * Enforced workspace rules and AI agent protocol in [AGENTS.md](file:///AGENTS.md).
  * Provided central environment template in [.env.example](file:///.env.example).
* [x] **Backend Infrastructure (`backend/`)**:
  * Typed configuration in `config/env.ts` with strict origin-only URL parsing (strips `/v1` to prevent 404s).
  * Relational persistence in SQLite (`db/schema.sql`, `db/index.ts`) for employees, payroll runs, money missions, audit logs, and webhooks.
  * Central `Money` abstraction (`core/money.ts`) using integer minor units, zero float drift, and currency safety.
  * Production-grade BMONI client (`bmoni/client.ts`) with safe logging, structured error parsing (400 validation arrays, 401, 403, 409 idempotency recovery, 500 curve errors).
  * Webhook listener (`bmoni/webhooks.ts`, `routes/webhook.routes.ts`) verifying HMAC-SHA256 signatures over raw Buffer bytes in constant time.
  * Multi-country aggregate payroll engine (`modules/payroll/service.ts`, `routes/payroll.routes.ts`).
  * AI Financial Safety Engine (`modules/ai/interpreter.ts`, `modules/ai/validator.ts`) enforcing deterministic validation and previews.
  * Automated unit tests passing for Money arithmetic, HMAC verification, and AI safety guards.
* [x] **Mobile Flutter Foundation (`mobile/`)**:
  * Configured `pubspec.yaml` with BMONI Flutter ecosystem (`bmoni_embedded_sdk`, `bkey_uikit`, `bmoni_embedded_wallets_cards`).
  * Central Money abstraction (`lib/core/money/money.dart`).
  * Financial safety state models & signing coordinator (`lib/core/safety/`).
  * BMONI SDK on-device signing service wrapper (`lib/core/bmoni_sdk/bmoni_sdk_service.dart`).
  * Provider abstraction interfaces: `WalletRepository`, `TransferRepository`, `CardRepository`, `EmployeeRepository`, `PayrollRepository`.
  * Deterministic `DemoProvider` implementations loaded with BMONI sandbox personas (Bunch Dillon BVN 99999999999, Samson Jabo BVN 22222222222).
  * Live `BMONIProvider` implementations communicating via backend proxy.
  * Premium fintech design system (`lib/core/theme/`): dark surface palette, tabular numeric typography, cards, badges, buttons.
  * Application shell (`lib/app.dart`) supporting on-the-fly toggling between Personal & Business roles and Demo & BMONI modes.
* [x] **Scaffolded Module Boundaries**:
  * **Personal**: Dashboard, Wallets, Money Missions ("Your money. Your rules. AI executes."), Send Money with PIN approval, Personal Activity, Personal Security.
  * **Business**: Business Dashboard, Global Team Roster, Employee Detail, Multi-country Payroll Orchestrator ("One Employer, Many Countries, One Bill"), Corporate Audit.

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
