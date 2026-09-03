# FlowPay — Brief for Antigravity

Paste this whole file into Antigravity as your first message in the `feat/business` branch session (or drop it in the repo root and tell Antigravity to read it before doing anything). It's written to sit alongside your existing `AGENTS.md` and `.agents/skills/flowpay-core/SKILL.md` — don't remove those, this document feeds them.

---

## 0. Before you write any code

1. Read `AGENTS.md` and `.agents/skills/flowpay-core/SKILL.md` in full — they define the mandatory context-loading and skill-update protocol for this repo. Follow it for every change you make from here on.
2. Read this file in full before installing anything or scaffolding any project structure.
3. Do not assume package names or versions from training data. For any BMONI package, verify against **pub.dev** (Flutter) or **npm** directly before adding it to a manifest. Versions below were verified today — re-check if more than a few days have passed.

---

## 1. What we're building

**FlowPay**: a Flutter mobile app (iOS + Android) on top of the **BMONI Embedded** platform (multi-currency stablecoin wallets, virtual bank accounts, cards, embedded KYC), plus a **Node.js/TypeScript backend** that proxies BMONI's REST API and receives BMONI webhooks.

Two product surfaces in one app:
- **Personal**: USD/NGN wallets, "Money Mission" automated split rules, activity feed.
- **Business**: employer dashboard, employee wallets (Nigeria + Mexico in the demo), virtual card issuance, payroll runs.

Reliability requirement for the live hackathon demo: see `FLOWPAY___RELIABLE_HACKATHON_DEMO_MODE.md` in the repo root — a `DemoProvider` must implement the **same repository/service interfaces** as the real BMONI-backed provider, so demo mode and live mode are swappable without duplicating feature code. This is a hard architectural constraint, not a nice-to-have — design the repository interfaces first with both implementations in mind.

Full technical reconnaissance (API catalogue, SDK details, rails, webhooks, sandbox test data) is in `BMONI_Embedded_Platform_Reconnaissance.pdf` in the repo — treat it as the primary technical reference. Docs site: https://bkey.mintlify.app/

---

## 2. Confirmed real package versions (verified against pub.dev/npm directly)

Do not upgrade or guess at versions beyond these without re-checking pub.dev/npm — this SDK is very new (single published version as of this brief).

**Flutter (mobile app):**
```yaml
dependencies:
  bmoni_embedded_sdk: ^0.0.1   # verified on pub.dev — publisher: bkey.me (verified publisher)
```
- Install via: `flutter pub add bmoni_embedded_sdk`
- Package requires: `crypto`, `flutter_secure_storage`, `plugin_platform_interface` as transitive deps (handled automatically by pub).
- Min Dart SDK for this package: **3.9** — meaning your Flutter SDK must be recent enough to bundle Dart ≥3.9 (Flutter 3.35+ roughly). Run `flutter --version` after install and confirm the Dart line before proceeding.
- API surface (static facade, no instantiation): `BmoniEmbeddedSdk.initialize(pinLength:, requirePin:)`, `initWallet()`, `walletAddress()`, `hasWallet()`, `deleteWallet(pin:)`, `signMessage(message, pin:)`, `signTransactionHash(hashHex, pin:)`, `setPin/changePin/removePin/matchPin/hasPin`.
- **Do not try to add `bmoni_embedded_wallets_cards` or `bkey_uikit` blind** — verify these exist on pub.dev under the same publisher before depending on them. If they don't resolve, build the wallet/card UI as custom widgets per `design.md`.

**Node/TypeScript backend:**
- There is no official BMONI Node SDK confirmed in the recon doc — treat BMONI as a plain REST API called via `axios` or `fetch`, authenticated with an `x-api-key` header. Do not `npm install` a guessed `@bmoni/*` or `@bkey-inc/*` Node package without first checking npm — the recon doc only confirms a React Native package (`@bkey-inc/bmoni_embedded_sdk`) which is a **mobile SDK**, not a server SDK, and is not what the Node backend needs.
- Backend responsibilities: store `bmoniUserId`/wallet IDs, proxy REST calls to `https://embedded-dev.bmoni.com` (sandbox — confirm exact host in the Mintlify docs, don't hardcode from the recon doc without checking), receive and verify HMAC-signed webhooks at a public endpoint (use `ngrok` or a tunneling service in dev).

**iOS/Android native minimums** (from the recon doc, still verify against the Mintlify SDK page before locking in):
- iOS: 13.0+ (Flutter SDK)
- Android: minSdk 24
- Flutter: ≥3.3 (but see the Dart 3.9 constraint above — the actual minimum Flutter version is higher than this now that the SDK requires Dart 3.9)

---

## 3. Environment constraint: macOS 12 (Monterey)

The dev machine is macOS 12. This caps Xcode at **14.2** (Xcode 14.3+ requires macOS Ventura 13). Practical implications for how Antigravity should sequence work:

- **Build and test on Android first.** Android toolchain has no macOS-version dependency and unblocks 90% of feature work without touching Xcode at all.
- iOS builds are still possible on Xcode 14.2, but confirm current Flutter stable still supports that Xcode version — recent Flutter releases increasingly assume Xcode 15+. Run `flutter doctor -v` after setup and read the Xcode section carefully; if it flags an incompatibility, iOS work blocks until the Mac is upgraded (or a second, newer Mac / CI runner is used for iOS builds only).
- The BMONI recon doc itself notes: **the iOS Simulator cannot exercise Secure Enclave signing** — SDK wallet-signing flows must be tested on a real iOS device or the Android emulator (which does support Keystore-backed testing), regardless of the Xcode/macOS version question.

---

## 4. Repository conventions already in place — follow these

- Branch: `feat/business` (already checked out).
- Every substantial subsystem (frontend wallet module, backend API proxy, payroll module, demo provider) gets its own `.agents/skills/<module-name>/SKILL.md` using `.agents/skills/templates/MODULE_SKILL_TEMPLATE.md`, per `AGENTS.md` §1–2.
- Update `.agents/skills/flowpay-core/SKILL.md`'s "What Has Been Done" / "What Needs To Be Done" sections after every meaningful change — this is mandatory, not optional, per the repo's own rules.
- A frontend design-taste skill (`taste-SKILL.md`) is already in the repo — it's written for web/Next.js/React marketing sites, not Flutter mobile UI. Use `design.md` (this brief's companion doc) as the actual source of truth for FlowPay's visual direction instead; the taste skill's *principles* (one accent color, motivated motion, no AI-tell copy, contrast checks) still apply conceptually, just not its React-specific code patterns.

---

## 5. Explicit instructions for dependency installation

When you (Antigravity) scaffold this project, do the following in order and **show your work at each step** rather than silently installing a batch of guessed packages:

1. Run `flutter --version` and `flutter doctor -v` first. Report the output before proceeding — if Dart < 3.9 or Xcode is flagged, stop and surface that to the developer instead of working around it silently.
2. Scaffold the Flutter app (`flutter create`) if it doesn't exist yet — check first, don't overwrite.
3. Add `bmoni_embedded_sdk` via `flutter pub add bmoni_embedded_sdk` (not by hand-editing `pubspec.yaml` with a guessed version).
4. For any other package (state management, routing, HTTP client, `google_fonts`, etc.), check `pub.dev` for the current stable version before adding — do not carry over version numbers from training data.
5. Scaffold the Node/TypeScript backend separately (e.g. `backend/` directory) with a standard `package.json` + `tsconfig.json`. Use `npm install` for each dependency individually and confirm resolution, rather than writing a `package.json` full of guessed version numbers by hand.
6. After any dependency change, run the platform's normal verification command (`flutter pub get && flutter analyze` / `npm install && npx tsc --noEmit`) and report the result before moving on.
7. Never install a package "because the docs probably need it" — only install what the current task actually calls a method from.

---

## 6. Immediate next steps (suggested order)

1. `flutter doctor -v` + `node -v` / `npm -v` sanity check — report versions.
2. Scaffold Flutter app + Node backend directory structure.
3. Add `bmoni_embedded_sdk`, call `BmoniEmbeddedSdk.initialize(...)` in `main()`.
4. Stand up the backend's BMONI proxy layer for one flow end-to-end: `POST /users` → `initWallet()` → owner-proof challenge → `create-managed` → sandbox NGN or USD onboarding. This is the smallest slice that proves the whole chain works.
5. Build the `DemoProvider` alongside the real provider from day one, sharing interfaces, per the demo-mode doc.
6. Update `flowpay-core/SKILL.md` after each of the above.
