---
name: stellar
description: >-
  Technical documentation and operational runbook for FlowPay's Stellar network layer
  (accounts, assets, path payments, payroll batches, anchors). Reference this skill
  before touching any money-movement code in backend/src/stellar or mobile/lib/core/stellar.
---

# Subsystem: Stellar Network Layer

FlowPay was originally built on BMONI. As of 2026-10-26 it is being migrated to run
entirely on the **Stellar network** (branch `feat/stellar-migration`). BMONI is being
removed completely.

## 📌 1. What This Subsystem is About

* **Purpose**: Every wallet, balance, transfer, FX conversion and payroll payout in FlowPay
  is a real Stellar operation. The backend reads chain state and *builds* unsigned
  transactions; the device *signs* them; the backend (or device) *submits* them to Horizon.
* **Locked decisions (2026-10-26, from the product owner)**:
  | Decision | Choice |
  | :--- | :--- |
  | Network | **Testnet** (`Test SDF Network ; September 2015`, `https://horizon-testnet.stellar.org`). Mainnet is a config switch later. |
  | Custody | **Non-custodial, on-device.** Ed25519 keypair generated on the phone/browser, encrypted with the user's PIN, stored in secure storage. Secret key never reaches the backend, the AI, or logs. |
  | Currencies | **USD, CAD, MXN, GBP, NGN.** Nigeria stays, Paystack NUBAN resolution stays. |
  | Cards | **Removed.** Stellar has no card issuing; cards module is deleted, not mocked. |
* **Asset model (testnet)**: FlowPay runs its own testnet *issuer* account that issues
  `USD`, `CAD`, `MXN`, `GBP`, `NGN` test stablecoins, and a *distributor/market-maker*
  account that seeds constant-product liquidity pools (`USD/<X>`) at reference FX rates, so
  cross-currency payments are native Stellar **path payments** (`pathPaymentStrictReceive`).
  Asset codes + issuers are config-driven (`STELLAR_ASSETS`), so mainnet swaps in real
  anchor assets (e.g. Circle USDC) without code changes.
* **Payroll ("One Employer, Many Countries, One Bill")**: one Stellar transaction holding
  up to 100 path-payment operations — the employer pays in USD, each employee receives
  their local asset, and the whole batch is **atomic** (all succeed or none). Batches > 100
  are split into multiple transactions and reported per-batch.
* **Cash-out / KYC**: Stellar anchors via SEP-10 (auth), SEP-12 (KYC), SEP-24 (interactive
  deposit/withdraw), SEP-38 (quotes). Testnet anchor: `testanchor.stellar.org`.
* **Key dependencies**: `@stellar/stellar-sdk` (backend, Node), `stellar_flutter_sdk`
  (mobile + Flutter web), Horizon REST, Friendbot (testnet XLM funding).

## 🔒 2. Money-Safety Rules (Stellar edition of AGENTS.md)

* A failed Horizon submit / anchor call **must surface as a failure**. Never synthesize a
  transaction hash, account ID, or `SUCCESS` status.
* Only a Horizon response with `successful: true` and a real `hash` may produce a
  `COMPLETED` record. Every completed record stores the real hash and links to
  `https://stellar.expert/explorer/testnet/tx/<hash>`.
* Timeouts on submit are **ambiguous, not failed**: record `PENDING`, then reconcile by
  hash against Horizon before reporting a final status (never resubmit blindly — same
  sequence number protects against double-spend, but the UI must not claim either outcome).
* Testnet funding (Friendbot XLM + FlowPay test-asset faucet) is allowed **only** when
  `STELLAR_NETWORK=testnet`, and is labeled as test funds in the UI.
* Demo mode (`ProviderMode.demo`) remains a separate, clearly-labeled simulation path.

## 🏗️ 3. File Structure (target)

* `backend/src/stellar/config.ts` — network, Horizon URL, passphrase, asset registry.
* `backend/src/stellar/horizon.ts` — typed Horizon client wrapper with honest error mapping.
* `backend/src/stellar/accounts.ts` — load account, balances, trustline status, friendbot.
* `backend/src/stellar/payments.ts` — build unsigned payment / path-payment XDR, find paths, submit signed XDR.
* `backend/src/stellar/payroll.ts` — batch builder (≤100 ops/tx), atomic payroll.
* `backend/src/stellar/anchors.ts` — SEP-10/12/24/38 client.
* `backend/scripts/stellar-bootstrap.ts` — creates issuer + distributor, issues assets, seeds pools.
* `mobile/lib/core/stellar/` — keypair vault (PIN-encrypted), transaction signer, Horizon reads.
* `mobile/lib/core/providers/stellar/` — `Stellar*Repository` implementations of the existing repository interfaces.

## ✅ 4. What Has Been Done

* [x] **M0 — Plan & foundation**: branch `feat/stellar-migration`, decisions recorded, AGENTS.md rules rewritten for Stellar, this skill created. Baseline before migration: backend 122/122 tests, Flutter 198/198 tests, analyzer clean.

* [x] **M1 — Stellar backend core**:
  * `backend/src/stellar/config.ts` (network + asset registry, `assetFor`, explorer URLs), `amount.ts` (Money ↔ 7-dp strings; quotes round UP), `horizon.ts` (`StellarHorizon` + injectable `HorizonGateway`; `mapHorizonError` → `STELLAR_TX_FAILED` with human messages from result codes, `StellarSubmitTimeoutError` = PENDING; `reconcile(hash)`), `accounts.ts` (summary, Friendbot, unsigned trustline XDR), `bootstrap.ts`.
  * Routes `backend/src/routes/stellar.routes.ts` mounted at `/api/stellar`: `GET /config`, `GET /accounts/:id`, `POST /accounts/:id/fund`, `POST /accounts/:id/trustlines`, `POST /transactions {signedXdr}` (200 COMPLETED / 202 PENDING / 4xx FAILED), `GET /transactions/:hash`.
  * **Live testnet treasury** created by `npm run stellar:bootstrap` (idempotent): issuer `GD3JY73LVFKPRAKV6QYLBKYBTDHP7WFVJQBQZVAWL5WT2FISH6XWN433`, distributor `GBX5PMNBNNG5SJLK5QZHVLOSCGK6O3RNXJPYNM7JB7XOWQRYAZSMOS56`; USD/CAD, USD/MXN, USD/GBP, USD/NGN pools seeded with $1M per side. Verified path quote: 500,000 NGN ← 446.51 CAD via USD.
  * 17 new unit tests (`src/stellar/stellar.test.ts`); backend total 139/139.

* [x] **M2 — On-device keys & signing**:
  * `mobile/lib/core/stellar/stellar_key_vault.dart` — `StellarKeyVault`: ed25519 keypair generated on device (`stellar_flutter_sdk` 3.8.0); seed encrypted with AES-256-GCM under PBKDF2-HMAC-SHA256(PIN, 24-byte salt, 100k iters) (`cryptography` 2.9.0); blob in `flutter_secure_storage` (iOS `first_unlock_this_device`). Wrong PIN = GCM auth failure (no PIN hash exists). Lockout after 5 failures, 30s doubling. Recovery-key export/import. Storage errors PROPAGATE (`StellarVaultException.storageFailure`).
  * `stellar_network.dart` — testnet/public selection via `--dart-define=STELLAR_NETWORK`.
  * `WalletService` → `StellarWalletService` (`createWallet({pin})`, `importWallet`, `exportRecoveryKey`, PIN-gated `deleteWallet`); `WalletSigner` → `StellarWalletSigner` (`signTransactionXdr`, ed25519 `signMessage`/`signTransactionHash`, PIN always required).
  * `BmoniSdkService` and the `bmoni_embedded_sdk` dependency removed; all 14 call sites rewired. New `CreatePinSheet`.
  * Tests: `test/flutter_test_config.dart` gives every test a fresh in-memory vault; `test/helpers/test_wallet.dart`; `test/wallet_service_test.dart` rewritten around real crypto (signatures verified with the SDK). Opt-in live test `test/live/stellar_live_test.dart` (`LIVE_STELLAR=1`) — verified device-signed trustline tx accepted on testnet (`e1b1277a…`). Flutter 179/179, analyzer clean, `flutter build web` OK.
  * **Security note (honest limits)**: a 6-digit PIN has 10^6 combinations, so the KDF alone cannot stop an offline brute force if the encrypted blob is exfiltrated; protection relies on OS keychain/keystore + lockout. On **web**, secure storage is browser storage — weaker. Planned: optional longer passphrase on web, and recovery-key backup prompt in onboarding (M7/M8).

## 🐞 Bug inventory (found during migration, fix in M7 unless noted)

* **CRITICAL — no API authentication**: routes take the acting user from `?userId=` / `x-user-id` and default to `usr_flowpay_sandbox_master`. Anyone can read or act as any user. Fix: signed session tokens + middleware (Stellar SEP-10 style challenge for wallet-linked users).
* Hardcoded, inconsistent FX (`1550` NGN, `17` vs `17.5` MXN) in transfers/payroll/missions — replaced by Horizon path quotes in M3/M4.
* ~~Fixed in M2~~: BMONI signer used a hardcoded PIN `'123456'` when none was passed; web/native "wallets" fell back to one shared fake address `0x71C8…` and synthesized signatures; PIN set/change/remove errors swallowed; app-lock PIN stored in plaintext (now salted PBKDF2, or vault-verified); **logout deleted the wallet** (would destroy funds); set-PIN screen fabricated an auth token `flowpay_jwt_<id>` and showed "wallet linked to payroll" even when linking failed; employer-assisted onboarding created the employee's wallet on the employer's device; security/provisioning screens displayed & copied a fake address when no wallet existed; tests approved payments with a 4-digit PIN.
* **HIGH — login sends the wallet PIN to the backend as the account password** (`/api/auth/login`). Replace with SEP-10-style challenge signed by the device key (M7, together with the API-auth fix).
* `personal_provider.approveAction` signs a hardcoded constant hash and discards the signature (signing theatre) — replace with real Stellar tx in M3.
* Employer-assisted onboarding (`EmployeeOnboardingScreen` stage 2) now refuses until the employee has created their own wallet — redesign in M5.
* New-device login: user has no local wallet → needs "restore from recovery key" UX (M7/M8).
* `config/env.ts` ships a real BMONI API key and a personal SMTP address as defaults — removed in M6.

## 🎯 5. Milestone Plan (each milestone = one pushed commit set, tests green)

* [x] **M1 — Stellar backend core** (see §4).
* [x] **M2 — On-device keys & signing** (see §4).
* [ ] **M3 — Wallets & transfers**: balances, receive (account ID + QR), same-currency payments, cross-currency path payments, activity from Horizon operations.
* [ ] **M4 — Atomic multi-country payroll**: batched path payments, preview with live path quotes, real hashes + explorer links.
* [ ] **M5 — Employees, KYC & anchors**: invite → employee creates wallet on device → account linked; SEP-10/12/24 cash-out on testanchor.
* [ ] **M6 — Remove BMONI entirely**: client, webhooks, packages, cards module, copy; DB `bmoniUserId` → `stellarAccountId`.
* [ ] **M7 — End-to-end test & bug sweep**: integration tests for every user journey; fix all defects found.
* [ ] **M8 — Redesign**: new UI system informed by Stellar's design language (mobile + web).
* [ ] **M9 — Web deploy & docs**: Vercel/Render deploy, README, skills.

## 🛠️ 6. Runbook & Verification

```bash
# Testnet health
curl -s https://horizon-testnet.stellar.org/ | head
# Inspect any account / tx
open https://stellar.expert/explorer/testnet/account/<G...>
# Backend tests
cd backend && npm run build && npm test
# Mobile
cd mobile && flutter analyze && flutter test
```
