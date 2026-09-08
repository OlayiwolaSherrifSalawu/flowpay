# AI Assistants & Developer Protocol

Welcome to the repository. This project is built collaboratively by developers and AI agents for a hackathon.

To ensure continuous alignment, eliminate context loss across sessions and developers, and maintain a single source of truth, all contributors (human and AI) must follow the directives below.

---

## 🧠 Core Directives for AI Assistants

### 1. Mandatory Context Loading
Before writing any code, planning changes, or executing commands:
- Inspect `.agents/skills/` (starting with [flowpay-core](file:///.agents/skills/flowpay-core/SKILL.md)).
- Read and adhere to the 3 foundational questions:
  1. **What is the app about?** (Vision, core problem, user personas, architecture).
  2. **What has been done?** (Existing modules, components, APIs, schema, tests).
  3. **What needs to be done?** (Prioritized roadmap, pending tasks, immediate next steps).

### 2. Mandatory Skill Updates on Every Build
Whenever you create, refactor, or complete any feature, component, API, or system:
- **Update the Master Skill ([flowpay-core](file:///.agents/skills/flowpay-core/SKILL.md))**:
  - Keep **"What Has Been Done"** strictly up-to-date with completed deliverables.
  - Update **"What Needs To Be Done"** by checking off completed items and refining the backlog.
  - Update any architectural or stack adjustments.
- **Create Subsystem Skills for Substantial Modules**:
  - Whenever a major subsystem is introduced (e.g., frontend, smart contracts, backend/indexer, payment engine), create `.agents/skills/<module-name>/SKILL.md` using the template at [MODULE_SKILL_TEMPLATE.md](file:///.agents/skills/templates/MODULE_SKILL_TEMPLATE.md).

### 3. Official BMONI Documentation & API Key Protocol
- **Single Source of Truth**: Always consult the official BMONI documentation at [bkey.mintlify.app](https://bkey.mintlify.app/) and its machine-readable index at [bkey.mintlify.app/llms.txt](https://bkey.mintlify.app/llms.txt) prior to implementing any BMONI feature, endpoint, or SDK integration.
- **Explicit API Key Requests**: Never invent fake API keys or hardcode placeholder secrets for BMONI production/sandbox environments. Whenever an implementation requires an API key, webhook secret, or partner credential, explicitly ask the user for it.

---

## 👥 Multi-Developer Team Standards

1. **Self-Documenting Code & Architecture**:
   - Write clean, modular, typed code.
   - Provide explicit environment setup and runnable verification commands.
2. **Zero Hidden Assumptions**:
   - Every external dependency, API, or mock must be documented in the corresponding skill file.
3. **Continuous Alignment**:
   - Always check the latest status in `.agents/skills/` before starting work to avoid duplicate effort.


 
## Rule: never fabricate a success response on a failed BMONI call
 
This codebase talks to BMONI (identity, wallets, KYC, transfers, payroll,
cards) through `backend/src/bmoni/client.ts` on the backend and
`BmoniEmbeddedSdk` / `BmoniSdkService` on-device in the Flutter app. This is
real money and real user identity — not a mock.
 
**When a call into BMONI fails (throws, times out, returns a non-success
status), the failure must propagate as a failure.** Concretely:
 
- Never catch a BMONI error and return a synthesized transaction hash, wallet
  address, user ID, or signature in its place.
- Never catch a BMONI error and return `status: 'SUCCESS'` / `'COMPLETED'` /
  `success: true`.
- Never let a caught BMONI error result in creating or updating a database
  record that implies the operation succeeded (e.g. an employee record with a
  made-up `bmoniUserId`, a card marked `ACTIVE` that BMONI never issued).
- It's fine to log a warning and it's fine to have a fallback — but the
  fallback must be an honest one: a `FAILED` status with a real error message,
  a rethrown typed exception, or a documented degraded-read (e.g. serving a
  cached balance on a read failure is OK; inventing a transaction on a write
  failure is not).
**This does not apply to `DemoProvider` / `Demo*Repository` classes.** Demo
mode is an intentional, clearly-labeled, non-BMONI code path selected via
`ProviderMode.demo` in `AppState`, and its job is to simulate realistic data.
The rule above is about the **live BMONI (`ProviderMode.bmoniSandbox`)** code
path silently behaving like demo mode without saying so.
 
### Self-check before finishing any task that touches a BMONI call site
 
Before marking a task complete, check every `try { await bmoniClient.<x>(...) }
catch` or `try { await BmoniEmbeddedSdk.<x>(...) } catch` block you touched or
added, and confirm:
 
1. Does the `catch` block return anything that looks like a successful result
   (a hash, an ID, a `SUCCESS`/`COMPLETED` status, `success: true`)? If yes,
   stop and fix it — that's the exact pattern that caused a prior incident in
   this codebase (payroll, transfers, cards, and employee creation all had
   this bug; see `docs/prompts/fix-silent-bmoni-fallbacks-prompt.md` for the
   full writeup if you want the history).
2. Does the caller (mobile UI, another service) have a way to distinguish
   "this succeeded" from "this failed and here's why"? If the only signal is a
   field that's identical in both cases, that's a red flag.
3. If you're tempted to write a comment like `// offline/sandbox fallback` or
   `// deterministic fallback for offline/test mode` inside a **live-mode**
   code path (not inside a file under `providers/demo/`), stop — that comment
   is usually marking exactly this bug. Either the fallback is truly
   demo-mode-only (move it there / gate it behind `ProviderMode.demo`), or it's
   masking a real failure (make it fail loudly instead).
## Other standing conventions
 
- New provider-facing features should extend the existing
  `DemoProvider`/`BMONIProvider` (`AppState` in
  `mobile/lib/core/state/app_state.dart`) and `*Repository` interface pattern
  in `mobile/lib/core/repositories/` — don't introduce a new
  parallel abstraction for switching providers.
- Signing goes through `mobile/lib/core/wallet/wallet_signer.dart`
  (`walletSignerProvider`) — don't call `BmoniEmbeddedSdk` or `BmoniSdkService`
  directly from UI/provider code for signing operations.
 