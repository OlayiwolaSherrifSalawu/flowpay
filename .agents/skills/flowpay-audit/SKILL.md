---
name: flowpay-audit
description: >-
  Technical documentation and operational runbook for the FlowPay Business Corporate Payroll
  Activity and Audit subsystem. Composes Prompts 10-13 repositories without new BMONI calls.
---

# Subsystem: FlowPay Business — Payroll Activity & Corporate Audit

## 📌 1. What This Subsystem is About

* **Purpose**:
  Provides an aggregated, real-time read and audit layer over data already fetched by Prompts 10–13 repositories (`PayrollRepository`, `CardRepository`, `WalletRepository`, `ActivityRepository`).
  Surfaces 5 core corporate operations:
  1. **Payroll Runs**: Aggregate multi-country fan-out disbursements with savings.
  2. **Employee Payments**: Individual local-currency disbursements (`CNGN`, `MEXe`) and rail settlements.
  3. **Card Transactions**: Virtual employee spend card authorizations and category ledger.
  4. **Wallet Operations**: Treasury auto-sweeps, FX conversions, and on-chain funding.
  5. **Failures**: Audit error log isolating failed proposals, card caps, and rail unactivation with granular retry.

* **Architectural Invariant (Composition Over Duplication)**:
  - Strictly composes existing data paths. Does **NOT** call BMONI directly for any new endpoints.
  - Reuses `bkey_uikit`'s `ActivitySectionCard` and `StatusText` components across all views for unified visual identity.
  - Uses canonical `SharedTransactionModel` eliminating duplicate transaction models across payroll, card, and wallet views.
  - Supports both `DemoProvider` and `BMONIProvider` conforming to `BusinessAuditRepository`.

* **Financial Safety Directive (Zero Signing Secrets Exposed)**:
  - Neither `hashToSign`, `signature`, private key material, nor webhook `secretKey` is ever rendered in the UI or debug views.
  - Only public/audit references (`proposalId`, transaction hash, FlowPay batch ID) are surfaced.

---

## 🏗️ 2. File Structure & Exports

```text
flowpay/
├── backend/
│   └── src/modules/payroll/
│       └── audit.test.ts                       # Automated unit tests for record completeness, status allowlist, and secret sanitization
└── mobile/
    └── lib/
        ├── core/
        │   ├── models/
        │   │   └── shared_transaction.dart      # Canonical SharedTransactionModel, TransactionType, TransactionStatus
        │   ├── repositories/
        │   │   └── business_audit_repository.dart # BusinessAuditRepository interface & AuditFilterCategory
        │   ├── providers/
        │   │   ├── demo/
        │   │   │   ├── demo_business_audit_repo.dart # Composed demo aggregation repository
        │   │   │   └── demo_payroll_repo.dart        # Seeded historical runs (Completed, Partial, Draft)
        │   │   └── bmoni/
        │   │       └── bmoni_business_audit_repo.dart# Composed live BMONI backend proxy repository
        │   ├── state/
        │   │   ├── business_provider.dart       # loadAuditActivities, setAuditFilter, getPayrollRunDetail
        │   │   └── app_state.dart               # Wires audit repositories into demo & live providers
        │   └── theme/
        │       └── components.dart              # ActivitySectionCard, SectionHeader, StatusText, StatusType
        └── modules/business/
            ├── business_activity_screen.dart    # Full Corporate Audit & Activity Screen with 4-metric grid & filter tabs
            └── components/
                ├── payroll_run_detail_sheet.dart# Drill-down sheet: summary, timeline, employee payments, retry
                └── transaction_detail_sheet.dart# Single transaction & failure inspection sheet
```

---

## ✅ 3. What Has Been Done

* [x] **Canonical Shared Transaction & Activity Model (`mobile/lib/core/models/shared_transaction.dart`)**:
  - Implemented `SharedTransactionModel` with `Money` abstraction, secondary currency/FX display, tabular numerals, sanitized references, and failure tracking.
  - Added factory adapters: `fromPayrollRun`, `fromPayrollItem`, `fromCardTransaction`, `fromWalletTransaction`, `fromActivity`. Zero duplicate transaction models across views.
* [x] **UI Kit Components (`bkey_uikit` Integration in `mobile/lib/core/theme/components.dart`)**:
  - Implemented `ActivitySectionCard` with structured `SectionHeader`, content area, and optional footer.
  - Implemented `StatusText` with `StatusType` (`warning`, `success`, `error`, `neutral`, `info`) ensuring consistent status-chip rendering across payroll runs, card transactions, and wallet operations.
* [x] **Composition Layer (`BusinessAuditRepository`)**:
  - Defined `BusinessAuditRepository` interface composing Prompts 10–13 repositories without new BMONI endpoints.
  - Implemented `DemoBusinessAuditRepository` with rich historical seed runs.
  - Implemented `BmoniBusinessAuditRepository` connecting live backend proxy routes.
* [x] **Corporate Activity & Audit Screen (`mobile/lib/modules/business/business_activity_screen.dart`)**:
  - Top 4-metric grid: Total Volume Disbursed, Payroll Runs ratio, System Failures count.
  - 6 Filter tabs: All, Payroll Runs, Employee Payments, Card Transactions, Wallet Operations, Failures.
  - Search filter bar.
  - Payroll Run record card: Payroll ID, Date, Employee count, Countries, USD equivalent, Fees, Status chip.
* [x] **Payroll Run Detail Sheet (`mobile/lib/modules/business/components/payroll_run_detail_sheet.dart`)**:
  - Financial summary card with fee savings comparison ($330 / 97% saved).
  - 4-stage execution timeline.
  - Individual employee payment items with local currency stablecoins (`CNGN`, `MEXe`).
  - Failure details banner and inline **"Retry Payout via Approve"** button invoking on-device B-Key PIN signing.
* [x] **Strict Secret Sanitization**:
  - Explicitly tested and asserted that `hashToSign`, `signature`, and private keys are never exposed in UI or payloads.
* [x] **Automated Tests**:
  - All 54 backend tests passing (100%), including 5 dedicated tests in `backend/src/modules/payroll/audit.test.ts`.

---

## 🎯 4. What Needs to Be Done Next

* [ ] Add PDF export / receipt sharing for aggregate payroll disbursement runs.
* [ ] Add CSV export for tax compliance filings.

---

## 🛠️ 5. Runbook & Verification

```bash
# 1. Build and verify backend
cd backend
npm run build
npm test

# 2. Run audit unit tests specifically:
node --test dist/modules/payroll/audit.test.js

# 3. Test activity endpoint:
curl -s http://localhost:4000/api/activity | jq .

# 4. Test payroll runs endpoint:
curl -s http://localhost:4000/api/payroll/runs | jq .
```
