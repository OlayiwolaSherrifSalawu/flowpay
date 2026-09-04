---
name: flowpay-cards
description: >-
  Technical documentation and operational runbook for the FlowPay Business Virtual
  Employee Cards subsystem powered by BMONI infrastructure.
---

# Subsystem: FlowPay Business — Virtual Employee Cards

## 📌 1. What This Subsystem is About
* **Purpose**: Manages virtual employee corporate expense and payroll spend cards attached directly to BMONI smart wallets on Base Sepolia.
* **Scope**: Virtual cards only (strictly no physical cards).
* **Architecture & Patterns**:
  * **Amber Card-as-Object UI (`design.md §4.5`)**: Handcrafted card face using FlowPay Amber (`#F4B740`), soft physical shadow `Color(0x1A0D2E2A)` blur 24 offset (0, 8), tabular numerals, Mastercard interlocking spheres, and contactless glyphs.
  * **On-Device Cryptographic Signing**: Directly uses `BmoniSdkService.signTransactionHash()` / `WalletSigner.signTransactionHash()` (EIP-712 / ERC-4337 32-byte userOpHash), avoiding `signMessage()` which prepends an EIP-191 prefix causing silent on-chain execution failures.
  * **Auto-Approved Proposal Flow**: The BMONI proxy auto-approves issuance proposals (`proposalStatus: PENDING_APPROVALS`), requiring zero separate `/approve` calls.
  * **Sign Payload Polling**: If `signPayloadPending: true`, client/proxy polls `GET /v1/users/{userId}/smart-wallets/proposals/{proposalId}/sign-payload` (409 indicates payload preparation, retries gracefully).
  * **First-Time Cardholder Enrollment & E101 Handling**: Nigerian cards require an 11-digit NIN. Missing NIN returns `400 E101 — Card owner is not enrolled for cards yet`, which is intercepted and surfaced as a dedicated NIN enrollment requirement in the UI.
  * **Reserved Card Visual State**: Cards with `isReserved: true` or `status: 'RESERVED'` are rendered with an amber-bronze surface, progress spinner, and "Issuing..." status badge rather than being hidden.
  * **Dual Amount Format Separation**:
    1. Card detail ledger balance: Minor-unit string (`"250000"` = ₦2,500.00).
    2. Card transaction amounts: Major-unit number (`25.5` = $25.50).
    * Zero cross-parsing between the two formats.
  * **Card Status Management**: Freeze / unfreeze calls `PUT /v1/users/{userId}/cards/{cardId}/status` with `{"status": "BLOCKED"}` or `"ACTIVE"` (exact uppercase, case-sensitive).

---

## 🏗️ 2. File Structure & Exports

### Backend (`backend/`)
* `src/bmoni/types.ts`: TypeScript interfaces for card requests, proposals, ledger entries, sensitive data, and card transactions.
* `src/bmoni/client.ts`: Safe HTTP methods for BMONI card endpoints:
  * `createVirtualCard(userId, { cardName, cardColor, currency, type: 'virtual', smartWalletId, nin })`
  * `getProposalSignPayload(userId, proposalId)` (handles 409 retry loops)
  * `submitProposalSignature(userId, proposalId, signature)`
  * `listWalletCards(userId, smartWalletId)` (smart-wallet scoped, preserves reserved cards)
  * `getCardDetail(userId, smartWalletId, cardId)`
  * `getCardSensitiveData(userId, cardId)`
  * `updateCardStatus(userId, cardId, 'BLOCKED' | 'ACTIVE')`
  * `getCardTransactions(userId, cardId, { size, status })`
* `src/modules/cards/service.ts`: Domain service coordinating BMONI card actions, sandbox fallbacks, dual amount formatting, and E101 error normalization.
* `src/routes/cards.routes.ts`: Express router exposing `/api/cards` endpoints.
* `src/modules/cards/cards.test.ts`: 12 automated unit and integration tests.

### Mobile (`mobile/lib/`)
* `core/repositories/card_repository.dart`: Abstract repository contract, `VirtualCardModel` with computed states (`isIssuing`, `isFrozen`, `isActive`), and `CreateCardProposalResult`.
* `core/providers/bmoni/bmoni_card_repo.dart`: Live implementation communicating with backend proxy, polling sign payloads, and parsing dual amount formats.
* `core/providers/demo/demo_card_repo.dart`: Offline deterministic mock simulating card proposals, PIN signing, and freeze toggles without faking cryptography.
* `core/theme/components.dart`: `VirtualCardObject` meeting `design.md §4.5` specifications with distinct "Issuing..." and "FROZEN" visual states.
* `modules/business/components/issue_virtual_card_sheet.dart`: Modal bottom sheet for issuing cards, NIN input with helper text, named E101 banner, on-device PIN signing via `BmoniSdkService.signTransactionHash()`.
* `modules/business/components/card_detail_sheet.dart`: Modal bottom sheet for card management, sensitive PAN/CVV unmasking with 30s auto-hide timer, transaction list, and freeze/unfreeze toggle.
* `modules/business/employee_detail_screen.dart`: Integrates `VirtualCardObject`, "Manage Card" header link, and modal triggers.

---

## ✅ 3. What Has Been Done
* [x] Verified BMONI card endpoints against upstream documentation and machine-readable index.
* [x] Auto-approved proposal issuance flow without `/approve` calls.
* [x] On-device B-Key signing via `signTransactionHash()`.
* [x] Dual amount format parsing (minor-unit string for ledger, major-unit float for transactions).
* [x] First-time cardholder enrollment with 11-digit NIN and named E101 error handling.
* [x] Distinct visual state for reserved cards ("Issuing...").
* [x] Handcrafted Amber Card-as-Object UI (`#F4B740` with physical elevation).
* [x] Card detail modal with unmasked credentials (30s timer), transaction ledger, and freeze/unfreeze toggle (`BLOCKED`/`ACTIVE`).
* [x] 12 new backend tests added in `backend/src/modules/cards/cards.test.ts` (all 43 backend tests passing).

---

## 🎯 4. What Needs to Be Done
* [ ] Add virtual card spend limit presets (Junior: $500 / Senior: $2,500 / Contractor: $1,000).
* [ ] Connect live cardholder notification webhooks (`card.transaction.approved`, `card.transaction.declined`).
* [ ] Add transaction category analytics charts for corporate spend oversight.

---

## 🛠️ 5. Runbook & Verification
```bash
# Backend test verification
cd backend
npm test

# Mobile static checks & execution
cd mobile
flutter run
```
