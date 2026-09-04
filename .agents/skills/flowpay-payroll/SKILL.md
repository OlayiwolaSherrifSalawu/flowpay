---
name: flowpay-payroll
description: >-
  Technical documentation and operational runbook for the FlowPay Business Global Payroll
  orchestration subsystem powered by BMONI transfer proposal primitives.
---

# Subsystem: FlowPay Business — Global Payroll

## 📌 1. What This Subsystem is About

* **Core Mission**: *"One Employer. Many Countries. One Bill."*
  Enables global businesses to disburse multi-country payroll in a single aggregate USD bill, fanning out local currency disbursements in parallel to employees in Nigeria (Bunch Dillon, NGN / CNGN) and Mexico (Samson Jabo, MXN / MEXe) while saving 97% in cross-border wire fees ($10 vs $340 typical SWIFT wire fees).

* **Architectural Invariant (No Fake Endpoints)**:
  There is no single `/payroll` endpoint in BMONI. FlowPay orchestrates payroll by composing BMONI's 4-call transfer proposal primitives:
  1. `POST /v1/users/{employerUserId}/smart-wallets/{smartWalletId}/proposals`
     `{ "proposal": { "type": "TRANSFER", "toUserId": "<employee bmoniUserId>", "amount": "2000.00", "currency": "CNGN", "description": "Payroll — <period>" } }`
  2. `POST /v1/users/{employerUserId}/smart-wallets/proposals/{proposalId}/approve`
     Moves proposal to `PENDING_SIGNATURES` once wallet approval threshold is reached.
  3. `GET /v1/users/{employerUserId}/smart-wallets/proposals/{proposalId}/sign-payload`
     Polled for `hashToSign` (404 means approval threshold not yet met, 409 means preparing).
  4. `POST /v1/users/{employerUserId}/smart-wallets/proposals/{proposalId}/sign`
     Submits raw secp256k1 hex signature `{ "signature": "0x..." }`.

* **Raw-Hash Signing Requirement**:
  You sign `hashToSign` — the raw 32-byte digest — **never** `typedData`, and **never** with an EIP-191 personal message prefix (`\x19Ethereum Signed Message:\n32`).
  - Mobile SDK: `BmoniSdkService.signTransactionHash(hashHex, pin: pin)`.
  - Backend/Test vector: `ethers.SigningKey.sign(hash).serialized`.
  - Verified against BMONI official Anvil test vector (`keccak256("bmoni-embedded:BKE-2041:sign-payload-example")` -> `0x628f...1b`).

* **Recipient Rail Validation**:
  The recipient employee must already hold an active smart wallet in the currency being sent (`CNGN` for Nigeria, `MEXe` for Mexico). Sending to an unactivated currency returns 400. FlowPay validates rail activation *before* allowing "Run Payroll".

* **Independent Proposal Outcomes & Granular Retry**:
  Proposals are independent. If one employee's proposal fails, others still complete (reflected as `Partially Completed`). A failed proposal can be retried individually by calling `approve` (`POST /v1/users/{employerUserId}/smart-wallets/proposals/{proposalId}/approve`) without re-running the entire payroll run.

---

## 🏗️ 2. File Structure & Exports

```text
flowpay/
├── backend/
│   ├── src/
│   │   ├── bmoni/
│   │   │   └── client.ts                   # createTransferProposal, approveProposal, pollProposalSignPayload, submitProposalSignature, retryFailedProposal
│   │   ├── modules/payroll/
│   │   │   ├── service.ts                  # PayrollOrchestrationService (getPreview, executePayroll, retryProposal)
│   │   │   ├── types.ts                    # PayrollRunPreview, PayrollRunItem, PayrollRunSummary
│   │   │   └── payroll.test.ts             # 5 unit tests (BMONI test vector, rail check, failure isolation, retry)
│   │   └── routes/
│   │       └── payroll.routes.ts           # GET /preview, POST /execute, POST /proposals/:id/retry, GET /runs
└── mobile/
    ├── lib/
    │   ├── core/
    │   │   ├── repositories/
    │   │   │   └── payroll_repository.dart # PayrollItemModel, PayrollRunModel, PayrollRepository
    │   │   ├── providers/demo/
    │   │   │   ├── demo_data.dart          # Deterministic demo preview with CNGN & MEXe rails
    │   │   │   └── demo_payroll_repo.dart  # Deterministic 4-stage execution & retry simulation
    │   │   ├── providers/bmoni/
    │   │   │   └── bmoni_payroll_repo.dart # Live backend API proxy integration
    │   │   └── state/
    │   │       └── business_provider.dart  # Business domain coordinator (runPayroll, retryPayrollProposal)
    │   └── modules/business/
    │       └── payroll_screen.dart         # Review screen, confirmation modal, 4-stage timeline, results, retry button
    └── test/
        └── payroll_screen_test.dart        # Widget test suite for payroll flow
```

---

## ✅ 3. What Has Been Done

* [x] **BMONI Transfer Primitives Client (`backend/src/bmoni/client.ts`)**:
  * Implemented `createTransferProposal` with body shape `{ proposal: { type: "TRANSFER", toUserId, amount, currency, description } }`.
  * Implemented `approveProposal` (`POST .../proposals/{proposalId}/approve`).
  * Implemented `getProposalSignPayload` and `pollProposalSignPayload` with 404/409 retry loops.
  * Implemented `submitProposalSignature` (`POST .../proposals/{proposalId}/sign`).
  * Implemented `retryFailedProposal` calling `approve` per BMONI documentation.
* [x] **Multi-Rail Payroll Orchestration Service (`backend/src/modules/payroll/service.ts`)**:
  * Implemented `getPreview` with destination rail readiness validation (`CNGN` for Nigeria, `MEXe` for Mexico).
  * Implemented employer USDB balance sufficiency check ($24,500 USDB).
  * Implemented aggregate fee savings computation ($10 BMONI fee vs $340 wire fee -> $330 / 97% savings).
  * Implemented `executePayroll` running parallel 4-call sequence per employee with independent error isolation.
  * Implemented `retryProposal` to restart workflow for single failed proposal.
* [x] **Automated Test Suite (`backend/src/modules/payroll/payroll.test.ts`)**:
  * Verified official BMONI known-good offline signing test vector (`hashToSign` + Anvil key -> `0x628f...1b` recovering to `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`).
  * Verified message-signing discrepancy (EIP-191 recovers wrong address).
  * Verified destination stablecoin mappings (`CNGN`, `MEXe`).
  * Verified preview and rail validation.
  * Verified independent failure isolation.
  * Verified single-proposal retry via `approve`.
* [x] **Mobile Payroll Repository & Domain State (`mobile/lib/core/`)**:
  * Updated `PayrollItemModel` and `PayrollRunModel` with destination stablecoins, rail verification, savings, and retry methods.
  * Updated `DemoPayrollRepository` with deterministic 4-stage execution and instant proposal retry.
  * Updated `BmoniPayrollRepository` connecting to backend routes.
  * Updated `BusinessProvider` with `retryPayrollProposal`.
* [x] **Mobile UI (`mobile/lib/modules/business/payroll_screen.dart`)**:
  * Built Review Screen with "One Employer. Many Countries. One Bill." hero and 97% savings banner.
  * Added destination rail verification badges (`🟢 CNGN Rail Active` / `⚠️ Rail Inactive`).
  * Implemented Confirmation Modal with employee count, country count, and total bill before approval.
  * Built 4-Stage Execution Timeline Stepper (`Validated → Approved → Processing → Completed`).
  * Built Results View with `Completed` vs `Partially Completed` banner, proposal IDs, on-chain tx hashes, and dedicated `Retry Payout via Approve` button on failed items.

---

## 🎯 4. What Needs to Be Done Next

* [ ] Add PDF export / receipt sharing for aggregate payroll disbursement runs.
* [ ] Add virtual card spend limit presets (Junior / Senior / Contractor dropdowns).

---

## 🛠️ 5. Runbook & Verification

```bash
# 1. Build and test backend
cd backend
npm run build
npm test

# Run payroll unit tests specifically:
node --test dist/modules/payroll/payroll.test.js

# 2. Test payroll preview endpoint:
curl -s http://localhost:4000/api/payroll/preview | jq .

# 3. Test payroll execution endpoint:
curl -s -X POST http://localhost:4000/api/payroll/execute \
  -H "Content-Type: application/json" \
  -d '{"employerUserId":"usr_flowpay_sandbox_master","sourceSmartWalletId":"sw_usdb_sandbox_01"}' | jq .
```
