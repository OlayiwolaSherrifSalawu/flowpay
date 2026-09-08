---
name: flowpay-operator
description: >-
  Technical documentation and operational runbook for the FlowPay Intelligent Financial Operator subsystem.
  Reference this skill when extending natural language financial processing, entity resolution, clarification, policy validation, and execution gating.
---

# Subsystem: flowpay-operator

## 📌 1. What This Subsystem is About
* **Purpose**: The Intelligent Financial Operator is the cognitive layer of FlowPay. It acts as an autonomous financial operator that understands what the user means, extracts entities, resolves beneficiaries and destinations against application state, asks targeted contextual clarifications, generates structured financial plans with integer minor-unit math (zero float drift), enforces deterministic validation policies, gates execution strictly behind explicit user review and on-device B-Key PIN signing, and dispatches to decoupled execution providers.
* **Architecture & Pipeline**:
  ```text
  USER REQUEST
       ↓
  Financial Intent Engine (18 strongly typed intents, multi-action clause splitting)
       ↓
  Structured Intent
       ↓
  Context Resolver (Beneficiaries, Wallets, Reserves, Remainder/Percentage math)
       ↓
  Clarification Engine (Targeted questions, 1-tap options, entity disambiguation)
       ↓
  Financial Planner (Structured actions, balance impact projections, fee transparency)
       ↓
  Deterministic Policy Validator (Insufficient funds, entity sanity, currency allowlist)
       ↓
  User Review & Approval Boundary (Explicit approval card, B-Key PIN authorization)
       ↓
  Execution Provider (Demo, BMONI, or Smart Contract provider)
  ```
* **Core Safety Invariants**:
  1. AI is strictly advisory — it has zero direct access to execute transactions or move funds.
  2. Critical financial fields never silently transition from `UNKNOWN` to `KNOWN` through AI guesses.
  3. Floating-point arithmetic is forbidden; all calculations use `Money` integer minor units.
  4. Execution requires explicit user approval and authentic hardware enclave PIN verification.

---

## 🏗️ 2. File Structure & Exports
* `mobile/lib/core/financial_operator/models/financial_intent_types.dart`: 18 strongly typed financial intents (`SEND_MONEY`, `RECEIVE_MONEY`, `CONVERT_CURRENCY`, `ALLOCATE_MONEY`, `CREATE_RESERVE`, `UPDATE_RESERVE`, `CREATE_MISSION`, `UPDATE_MISSION`, `PAUSE_MISSION`, `RESUME_MISSION`, `CHECK_BALANCE`, `CHECK_SPENDING`, `CHECK_INCOME`, `VIEW_TRANSACTIONS`, `PAY_BENEFICIARY`, `PAY_BILL`, `ASK_FINANCIAL_QUESTION`, `UNKNOWN`).
* `mobile/lib/core/financial_operator/models/financial_entities.dart`: Entity representations with explicit `EntityKnowledgeState` (`known`, `unknown`, `ambiguous`, `inferred`, `requiresConfirmation`), `PersonEntity`, `DestinationEntity`, `AmountEntity`, and `ActionIntent`.
* `mobile/lib/core/financial_operator/models/financial_plan_models.dart`: Immutable `FinancialPlan`, `PlannedFinancialAction`, `BalanceImpact`, and `PlanValidationResult`.
* `mobile/lib/core/financial_operator/models/operator_session_models.dart`: Multi-turn session state machine (`OperatorSession`, `OperatorMessage`, `ClarificationPrompt`, `ClarificationOptionData`).
* `mobile/lib/core/financial_operator/services/financial_context_service.dart`: Controlled read-only application tool layer and integer minor-unit arithmetic helpers (`calculatePercentage`, `calculateRemainder`).
* `mobile/lib/core/financial_operator/services/financial_intent_engine.dart`: Natural language parser, currency detector, and multi-action clause extractor.
* `mobile/lib/core/financial_operator/services/context_resolver.dart`: Connects extracted entities to application beneficiaries, reserves, and wallet accounts.
* `mobile/lib/core/financial_operator/services/clarification_engine.dart`: Evaluates unresolved entities and formulates natural questions with 1-tap option cards.
* `mobile/lib/core/financial_operator/services/financial_planner.dart`: Compiles resolved intents into structured plans with before/after balance projections.
* `mobile/lib/core/financial_operator/services/financial_policy_validator.dart`: Deterministic safety guard checking sufficiency, amounts, and destination validity.
* `mobile/lib/core/financial_operator/services/execution_provider.dart`: `FinancialExecutionProvider` abstraction and `DemoFinancialExecutionProvider`.
* `mobile/lib/core/financial_operator/financial_operator.dart`: Master coordinator managing conversational state and processing turns.
* `mobile/lib/core/financial_engine/`: Complete Smart Payment Engine subsystem:
  * `models/wallet_balance_model.dart`: Balances breakdown (`available`, `reserved`, `pending`, `isProtected`, `protectedAmount`, `spendableBalance`), `BalanceTarget`, `FinancialPreferences`.
  * `models/quote_model.dart`: Live exchange rates, provider fees, network fees, expiration timestamps (`PaymentQuote`, `FundingRoute`).
  * `models/payment_execution_state.dart`: 10 lifecycle states, 7 failure states (`PaymentExecutionState`).
  * `models/smart_payment_plan.dart`: `FundingAllocation`, `SmartPaymentItem`, `SmartPaymentBatchPlan`.
  * `services/execution_provider.dart`: Decoupled `ExecutionProvider` interface, `ProviderUnavailableException`, `QuoteExpiredException`.
  * `services/demo_execution_provider.dart`: Deterministic rates, atomic fund reservations, multi-wallet debits, offline simulation.
  * `services/bmoni_execution_provider.dart`: Production BMONI smart wallet & rails provider enforcing zero fabricated success responses.
  * `services/funding_planner.dart`: Multi-wallet shortfall funding, zero over-conversion calculations, route explanations ("Why did you use my EUR?"), route overrides ("Use NGN instead").
  * `services/wallet_balancer.dart`: Natural language balance targets ("Make sure I have $2,000 in USD").
* `mobile/lib/modules/personal/components/ai_financial_plan_card.dart`: Interactive plan review card with cross-border deliveries, multi-wallet funding allocations, before/after balance impacts, quote expiration monitoring, expandable route explanation, and route override chips.
* `mobile/lib/modules/personal/ai_operator_modal.dart`: Premium multi-turn financial operator bottom sheet with hero suggestions.

---

## ✅ 3. What Has Been Done
* [x] Defined all 18 strongly typed financial intents and entity knowledge states.
* [x] Built the Financial Intent Engine supporting multi-action sentences, relative amounts ("half", percentages, "remainder"), "pay [recipient] [amount]" clauses, and GHS currency detection.
* [x] Built Context Resolver resolving beneficiaries (exact, alias, partial, ambiguous), wallets, and reserves without hallucinating.
* [x] Built Clarification Engine detecting missing/ambiguous entities and asking natural follow-up questions.
* [x] Built Financial Planner generating structured plans with projected before/after balance changes.
* [x] Built Deterministic Policy Validator enforcing insufficient funds, quote expiration, and currency boundaries.
* [x] Implemented decoupled `FinancialExecutionProvider` and `ExecutionProvider` abstractions.
* [x] Built `AiFinancialPlanCard` and overhauled `AiOperatorModal` into a full conversational operator.
* [x] Built Smart Payment Engine with multi-wallet intelligence, cross-border quotes, and automatic wallet balancing.
* [x] Built `FundingPlanner` and `WalletBalancer` with zero float drift and zero over-conversion.
* [x] Supported route explanations ("Why did you use my EUR?") and dynamic route overrides ("Use NGN instead").
* [x] Enforced protected funds safety ($1,000 Tax Reserve excluded from spendable balance and preserved intact).
* [x] Passed all 12 tests in `mobile/test/financial_operator_test.dart`.
* [x] Passed all 13 tests in `mobile/test/smart_payment_engine_test.dart` (including the full Hero Multi-Payment Batch scenario).
* [x] Passed all 132 tests in the mobile suite and 77 tests in the backend suite.

---

## 🎯 4. What Needs to Be Done
* [ ] Integrate with smart contract execution provider once teammate completes contracts.
* [ ] Add voice input transcription directly into `AiOperatorModal`.
* [ ] Support recurring schedule cadence triggers in Money Missions.

---

## 🛠️ 5. Runbook & Verification
* **Run Smart Payment Engine Tests**:
  ```bash
  cd mobile
  flutter test test/smart_payment_engine_test.dart
  ```
* **Run Financial Operator Tests**:
  ```bash
  cd mobile
  flutter test test/financial_operator_test.dart
  ```
* **Run Static Analysis**:
  ```bash
  cd mobile
  flutter analyze lib test
  ```
* **Run Full Flutter Test Suite**:
  ```bash
  cd mobile
  flutter test
  ```
