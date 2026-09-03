---
name: bmoni-backend
description: >-
  Provides operational instructions, architecture, and technical documentation for the
  FlowPay backend service, BMONI API client, webhook handler, and payroll engine.
---

# Subsystem: FlowPay Backend & BMONI Integration

## 1. Overview & Purpose
- **What it does**: Acts as the secure financial relay between the FlowPay Flutter client and the BMONI financial infrastructure.
- **Why it exists**: The Flutter client must **NEVER** hold partner API keys. The backend holds partner credentials, executes BMONI API calls, verifies incoming webhooks with HMAC-SHA256, stores FlowPay business metadata in SQLite, and orchestrates multi-country payroll.
- **Key dependencies**: `express`, `better-sqlite3`, `zod`, `dotenv`.

---

## 2. Key Files & Architecture
- `src/config/env.ts`: Typed environment validation. Enforces origin-only BMONI base URL (`https://embedded-dev.bmoni.com`) by stripping any trailing `/v1`.
- `src/db/`: SQLite connection (`index.ts`) and relational schema (`schema.sql`). Automatically seeds default sandbox personas (Bunch Dillon & Samson Jabo).
- `src/core/money.ts`: Central `Money` abstraction. Guarantees integer minor-unit calculations with zero floating-point arithmetic.
- `src/bmoni/client.ts`: Safe BMONI REST client handling timeouts, safe logging, and structured error responses.
- `src/bmoni/webhooks.ts`: Constant-time HMAC-SHA256 verification using raw Buffer request bodies.
- `src/modules/payroll/service.ts`: "One Employer, Many Countries, One Bill" aggregate payroll orchestrator.
- `src/modules/ai/`: Natural language intent interpreter and deterministic validation preview generator.

---

## 3. What Has Been Done
- [x] Node.js + Express + TypeScript scaffolding with strict ESM mode.
- [x] Complete BMONI API client with endpoints for users, smart wallets, cards, transfers, and partner employees.
- [x] Raw Buffer HMAC webhook receiver mounted before JSON body parser.
- [x] Multi-country payroll fanout service and SQLite persistence.
- [x] 11 unit tests passing across Money math, HMAC verification, and AI safety checks.

---

## 4. What Needs to Be Done
- [ ] Connect live BMONI partner key when issued.
- [ ] Subscribe live webhook URL via `POST /v1/webhooks/config`.
- [ ] Add PDF payslip generation endpoint for completed payroll runs.

---

## 5. Usage & Verification
```bash
cd backend
npm run build
npm test
npm start
```
Health check:
```bash
curl http://localhost:4000/api/health
```
